import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_constants.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _isConfigured = false;
  static Future<void>? _configureFuture;

  Future<void> configure() async {
    if (_isConfigured) {
      return;
    }
    if (_configureFuture != null) {
      await _configureFuture;
      return;
    }
    _configureFuture = _configureInternal();
    await _configureFuture;
  }

  Future<void> _configureInternal() async {
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      final configuration = PurchasesConfiguration(kRevenueCatApiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;
    } catch (_) {
      _configureFuture = null;
      rethrow;
    }
  }

  Future<void> logIn(String userId) async {
    await configure();
    await Purchases.logIn(userId);
  }

  Future<void> logOut() async {
    await configure();
    await Purchases.logOut();
  }

  Future<CustomerInfo> getCustomerInfo() async {
    await configure();
    return Purchases.getCustomerInfo();
  }

  Future<Offerings> getOfferings() async {
    await configure();
    return Purchases.getOfferings();
  }

  Future<CustomerInfo> restorePurchases() async {
    await configure();
    return Purchases.restorePurchases();
  }

  Future<PurchaseResult> purchasePackage(Package package) async {
    await configure();
    return Purchases.purchase(PurchaseParams.package(package));
  }

  Future<PaywallResult> presentPaywall() async {
    await configure();
    return RevenueCatUI.presentPaywallIfNeeded(kTracklyProEntitlementId);
  }

  Future<void> presentCustomerCenter() async {
    await configure();
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (_) {
      // Fallback: keep app stable when Customer Center isn't available.
      await RevenueCatUI.presentPaywall();
    }
  }

  Future<int> sharedTaskParticipationCount(String userId) async {
    final snapshot = await _db
        .collection('habits')
        .where('participants', arrayContains: userId)
        .where('spaceType', isEqualTo: 'sharedTask')
        .get();
    return snapshot.docs.length;
  }

  Future<bool> canAccessPremiumFeatures({
    required String userId,
    required CustomerInfo? customerInfo,
  }) async {
    final hasEntitlement =
        customerInfo?.entitlements.active.containsKey(kTracklyProEntitlementId) ??
        false;
    if (hasEntitlement) {
      return true;
    }
    return isTrialActive(userId);
  }

  Future<void> ensureTrialIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final consumedKey = '$kTrialConsumedPrefPrefix$userId';
    final startKey = '$kTrialStartPrefPrefix$userId';
    final consumed = prefs.getBool(consumedKey) ?? false;
    if (consumed) {
      return;
    }

    final hasStart = prefs.getString(startKey);
    if (hasStart != null && hasStart.isNotEmpty) {
      return;
    }

    final startAt = DateTime.now();
    await prefs.setString(startKey, startAt.toIso8601String());
    await prefs.setBool(consumedKey, false);
    await _db.collection('users').doc(userId).set({
      'trialStartAt': startAt.toIso8601String(),
      'trialConsumed': false,
    }, SetOptions(merge: true));
  }

  Future<DateTime?> getTrialStart(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$kTrialStartPrefPrefix$userId');
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<bool> isTrialConsumed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$kTrialConsumedPrefPrefix$userId') ?? false;
  }

  Future<bool> isTrialActive(String userId) async {
    final consumed = await isTrialConsumed(userId);
    if (consumed) return false;
    final startAt = await getTrialStart(userId);
    if (startAt == null) return false;
    final expiresAt = startAt.add(const Duration(days: 7));
    return DateTime.now().isBefore(expiresAt);
  }

  Future<void> syncTrialConsumption(String userId) async {
    final startAt = await getTrialStart(userId);
    if (startAt == null) return;
    final expiresAt = startAt.add(const Duration(days: 7));
    if (DateTime.now().isAfter(expiresAt)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$kTrialConsumedPrefPrefix$userId', true);
      await _db.collection('users').doc(userId).set({
        'trialConsumed': true,
      }, SetOptions(merge: true));
    }
  }

  String toUserMessage(Object error) {
    if (error is PurchasesError) {
      return error.message;
    }
    return error.toString().split('\n').first;
  }
}
