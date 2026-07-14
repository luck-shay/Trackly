import 'package:purchases_flutter/models/customer_info_wrapper.dart';
import 'package:purchases_flutter/models/offerings_wrapper.dart';

class SubscriptionState {
  final bool initialized;
  final bool isLoading;
  final bool isRefreshingCustomerInfo;
  final String? errorMessage;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final DateTime? trialStartAt;
  final bool trialConsumed;
  final bool isLocalMockPro;

  const SubscriptionState({
    this.initialized = false,
    this.isLoading = false,
    this.isRefreshingCustomerInfo = false,
    this.errorMessage,
    this.customerInfo,
    this.offerings,
    this.trialStartAt,
    this.trialConsumed = false,
    this.isLocalMockPro = false,
  });

  bool get hasTracklyProEntitlement {
    if (isLocalMockPro) return true;
    final info = customerInfo;
    if (info == null) return false;
    return info.entitlements.active.containsKey('Trackly Pro');
  }

  bool get isTrialActive {
    final start = trialStartAt;
    if (start == null) return false;
    if (trialConsumed) return false;
    return DateTime.now().isBefore(start.add(const Duration(days: 7)));
  }

  bool get hasAccess => hasTracklyProEntitlement || isTrialActive;

  SubscriptionState copyWith({
    bool? initialized,
    bool? isLoading,
    bool? isRefreshingCustomerInfo,
    String? errorMessage,
    bool clearError = false,
    CustomerInfo? customerInfo,
    bool clearCustomerInfo = false,
    Offerings? offerings,
    bool clearOfferings = false,
    DateTime? trialStartAt,
    bool clearTrialStartAt = false,
    bool? trialConsumed,
    bool? isLocalMockPro,
  }) {
    return SubscriptionState(
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      isRefreshingCustomerInfo:
          isRefreshingCustomerInfo ?? this.isRefreshingCustomerInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      customerInfo: clearCustomerInfo ? null : (customerInfo ?? this.customerInfo),
      offerings: clearOfferings ? null : (offerings ?? this.offerings),
      trialStartAt: clearTrialStartAt ? null : (trialStartAt ?? this.trialStartAt),
      trialConsumed: trialConsumed ?? this.trialConsumed,
      isLocalMockPro: isLocalMockPro ?? this.isLocalMockPro,
    );
  }
}
