import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';
import 'package:purchases_ui_flutter/paywall_result.dart';

import '../models/subscription_state.dart';
import '../services/subscription_service.dart';
 
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service;
  SubscriptionState _state = const SubscriptionState();
  StreamSubscription<User?>? _authSub;

  SubscriptionProvider({SubscriptionService? service})
    : _service = service ?? SubscriptionService() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        _state = const SubscriptionState();
        notifyListeners();
        return;
      }
      await bootstrapForUser(user.uid);
    });
  }

  SubscriptionState get state => _state;
  bool get hasProAccess => _state.hasAccess;
  bool get isPremium => _state.hasTracklyProEntitlement;

  Future<void> configure() async {
    if (!_service.isEnabled) {
      _state = _state.copyWith(initialized: true, clearError: true);
      notifyListeners();
      return;
    }
    try {
      await _service.configure();
      _state = _state.copyWith(initialized: true, clearError: true);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        initialized: false,
        errorMessage: _service.toUserMessage(error),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> bootstrapForUser(String userId) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    DateTime? trialStartAt;
    bool trialConsumed = false;

    try {
      await _service.ensureTrialIfNeeded(userId);
      await _service.syncTrialConsumption(userId);
      trialStartAt = await _service.getTrialStart(userId);
      trialConsumed = await _service.isTrialConsumed(userId);

      if (!_service.isEnabled) {
        _state = _state.copyWith(
          initialized: true,
          isLoading: false,
          trialStartAt: trialStartAt,
          trialConsumed: trialConsumed,
          clearError: true,
        );
        notifyListeners();
        return;
      }

      await _service.logIn(userId);
      final offerings = await _service.getOfferings();
      final info = await _service.getCustomerInfo();
      _state = _state.copyWith(
        initialized: true,
        isLoading: false,
        customerInfo: info,
        offerings: offerings,
        trialStartAt: trialStartAt,
        trialConsumed: trialConsumed,
        clearError: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        initialized: trialStartAt != null,
        isLoading: false,
        trialStartAt: trialStartAt,
        trialConsumed: trialConsumed,
        errorMessage: _service.toUserMessage(error),
      );
      notifyListeners();
    }
  }

  Future<void> refreshCustomerInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    _state = _state.copyWith(isRefreshingCustomerInfo: true, clearError: true);
    notifyListeners();
    await _service.syncTrialConsumption(uid);
    final trialConsumed = await _service.isTrialConsumed(uid);

    if (!_service.isEnabled) {
      _state = _state.copyWith(
        isRefreshingCustomerInfo: false,
        trialConsumed: trialConsumed,
        clearError: true,
      );
      notifyListeners();
      return;
    }

    try {
      final info = await _service.getCustomerInfo();
      _state = _state.copyWith(
        customerInfo: info,
        isRefreshingCustomerInfo: false,
        trialConsumed: trialConsumed,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isRefreshingCustomerInfo: false,
        trialConsumed: trialConsumed,
        errorMessage: _service.toUserMessage(error),
      );
      notifyListeners();
    }
  }

  Future<void> refreshOfferings() async {
    if (!_service.isEnabled) {
      _state = _state.copyWith(clearError: true);
      notifyListeners();
      return;
    }
    try {
      final offerings = await _service.getOfferings();
      _state = _state.copyWith(offerings: offerings, clearError: true);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(errorMessage: _service.toUserMessage(error));
      notifyListeners();
    }
  }

  Future<void> purchase(Package package) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final result = await _service.purchasePackage(package);
      _state = _state.copyWith(
        isLoading: false,
        customerInfo: result.customerInfo,
        clearError: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _service.toUserMessage(error),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restore() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final info = await _service.restorePurchases();
      _state = _state.copyWith(
        isLoading: false,
        customerInfo: info,
        clearError: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _service.toUserMessage(error),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<PaywallResult> presentPaywall() async {
    final result = await _service.presentPaywall();
    await refreshCustomerInfo();
    return result;
  }

  Future<void> openCustomerCenter() async {
    await _service.presentCustomerCenter();
    await refreshCustomerInfo();
  }

  Future<bool> canUsePremiumFeatures() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    if (!_service.isEnabled) {
      return true;
    }
    return _service.canAccessPremiumFeatures(
      userId: uid,
      customerInfo: _state.customerInfo,
    );
  }

  Future<int> sharedTaskParticipationCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return 0;
    return _service.sharedTaskParticipationCount(uid);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
