// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Feature Gate
// Centralized abstraction for all premium feature access checks.
// Every premium guard in the app routes through this class.
// ─────────────────────────────────────────────────────────────────────────────

import 'subscription_constants.dart';

/// Single entry-point for every premium access check in Trackly.
///
/// Usage:
/// ```dart
/// if (FeatureGate.canUse(PremiumFeature.advancedAnalytics, hasProAccess: sub.hasProAccess)) {
///   // show analytics
/// }
/// ```
class FeatureGate {
  const FeatureGate._();

  // ── Core Gate ───────────────────────────────────────────────────────────

  /// Returns `true` when the user may use [feature].
  static bool canUse(PremiumFeature feature, {required bool hasProAccess}) {
    if (hasProAccess) return true;

    // Free-tier allowances (features available to everyone):
    // None of the PremiumFeature enum values are free. If we ever need to
    // make a premium feature free, add a case here that returns true.
    return false;
  }

  // ── Collaboration Gates ─────────────────────────────────────────────────

  /// Whether the user can create a new group.
  ///
  /// Free users can create up to [kFreeGroupCreateLimit] groups.
  /// Pro users can create unlimited groups.
  static bool canCreateGroup({
    required bool hasProAccess,
    required int currentGroupCount,
  }) {
    if (hasProAccess) return true;
    return currentGroupCount < kFreeGroupCreateLimit;
  }

  /// Whether the user can create a challenge.
  ///
  /// Only Pro users can create challenges. Free users can join them.
  static bool canCreateChallenge({required bool hasProAccess}) {
    return hasProAccess;
  }

  /// Whether the user can create a shared habit.
  ///
  /// Free users can participate in up to [kFreeSharedTaskLimit] shared tasks.
  /// Pro users have unlimited shared habits.
  static bool canCreateSharedHabit({
    required bool hasProAccess,
    required int currentSharedHabitCount,
  }) {
    if (hasProAccess) return true;
    return currentSharedHabitCount < kFreeSharedTaskLimit;
  }

  /// Whether the user can create a private group.
  static bool canCreatePrivateGroup({required bool hasProAccess}) {
    return hasProAccess;
  }

  // ── Analytics Gates ─────────────────────────────────────────────────────

  /// Whether the user can access the advanced analytics screen.
  static bool canAccessAnalytics({required bool hasProAccess}) {
    return hasProAccess;
  }

  /// Whether the user can access smart insights.
  static bool canAccessInsights({required bool hasProAccess}) {
    return hasProAccess;
  }

  // ── Widget Gates ────────────────────────────────────────────────────────

  /// Whether the user can use premium home-screen widgets.
  static bool canUsePremiumWidgets({required bool hasProAccess}) {
    return hasProAccess;
  }

  // ── Accountability Gates ────────────────────────────────────────────────

  /// Whether the user can add multiple accountability partners.
  static bool canAddAccountabilityPartners({
    required bool hasProAccess,
    required int currentPartnerCount,
  }) {
    if (hasProAccess) return true;
    return currentPartnerCount < kFreeAccountabilityPartnerLimit;
  }

  // ── Upgrade Message ─────────────────────────────────────────────────────

  /// Returns a context-aware message explaining why the feature requires Pro.
  static String upgradeMessage(PremiumFeature feature) {
    return switch (feature) {
      PremiumFeature.advancedAnalytics =>
        'Unlock heatmaps, trends, and detailed reports with Trackly Pro.',
      PremiumFeature.smartInsights =>
        'Get personalized habit insights with Trackly Pro.',
      PremiumFeature.unlimitedGroups =>
        'Create unlimited groups with Trackly Pro.',
      PremiumFeature.createChallenge =>
        'Create and host challenges with Trackly Pro.',
      PremiumFeature.privateGroups =>
        'Private groups are available with Trackly Pro.',
      PremiumFeature.accountabilityPartners =>
        'Add multiple accountability partners with Trackly Pro.',
      PremiumFeature.premiumWidgets =>
        'Beautiful home screen widgets are available with Trackly Pro.',
      PremiumFeature.weeklyReports =>
        'Weekly performance reports are available with Trackly Pro.',
      PremiumFeature.heatmapView =>
        'Visual completion heatmaps are available with Trackly Pro.',
      PremiumFeature.monthlyReports =>
        'Monthly analytics are available with Trackly Pro.',
      PremiumFeature.yearlyReports =>
        'Annual reviews are available with Trackly Pro.',
      PremiumFeature.trendGraphs =>
        'Trend analysis is available with Trackly Pro.',
      PremiumFeature.streakHistory =>
        'Full streak history is available with Trackly Pro.',
      PremiumFeature.categoryInsights =>
        'Category breakdowns are available with Trackly Pro.',
      PremiumFeature.unlimitedSharedHabits =>
        'Share unlimited habits with Trackly Pro.',
    };
  }
}
