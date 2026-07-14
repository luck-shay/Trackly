// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Subscription Constants
// Single source of truth for all pricing, limits, and feature definitions.
// ─────────────────────────────────────────────────────────────────────────────

// ── RevenueCat Configuration ────────────────────────────────────────────────

const bool kRevenueCatEnabled = bool.fromEnvironment(
  'ENABLE_REVENUECAT',
  defaultValue: false,
);
const String kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: '',
);
const String kRevenueCatAndroidApiKey = String.fromEnvironment(
  'REVENUECAT_ANDROID_API_KEY',
  defaultValue: '',
);
const String kRevenueCatAppleApiKey = String.fromEnvironment(
  'REVENUECAT_APPLE_API_KEY',
  defaultValue: '',
);

const String kTracklyProEntitlementId = 'Trackly Pro';
const String kTrialStartPrefPrefix = 'trackly_trial_start_';
const String kTrialConsumedPrefPrefix = 'trackly_trial_consumed_';

// ── Pricing ─────────────────────────────────────────────────────────────────

const String kPriceCurrency = '₹';
const int kMonthlyPriceAmount = 199;
const int kYearlyPriceAmount = 1499;
const String kMonthlyPriceDisplay = '₹199';
const String kYearlyPriceDisplay = '₹1,499';
const String kYearlyPerMonthDisplay = '₹125';
const int kYearlySavingsPercent = 37;

// ── Free Tier Limits ────────────────────────────────────────────────────────

/// Maximum number of shared-task habits a free user can participate in.
const int kFreeSharedTaskLimit = 3;

/// Maximum number of members in any shared task.
const int kSharedTaskMaxMembers = 3;

/// Maximum number of groups a free user can create.
const int kFreeGroupCreateLimit = 1;

/// Maximum number of accountability partners for free users.
const int kFreeAccountabilityPartnerLimit = 1;

// ── Paywall Cooldown ────────────────────────────────────────────────────────

/// Minimum time between showing upgrade prompts to avoid being intrusive.
const Duration kUpgradeSheetCooldown = Duration(minutes: 30);

/// SharedPreferences key for last upgrade prompt timestamp.
const String kLastUpgradePromptKey = 'trackly_last_upgrade_prompt';

// ── Premium Feature Enum ────────────────────────────────────────────────────

/// Every premium-gated capability in Trackly.
///
/// Adding a new premium feature is a two-step process:
/// 1. Add it to this enum.
/// 2. Handle it in `FeatureGate.canUse`.
enum PremiumFeature {
  advancedAnalytics,
  smartInsights,
  unlimitedGroups,
  createChallenge,
  privateGroups,
  accountabilityPartners,
  premiumWidgets,
  weeklyReports,
  heatmapView,
  monthlyReports,
  yearlyReports,
  trendGraphs,
  streakHistory,
  categoryInsights,
  unlimitedSharedHabits,
}

/// Human-readable label for each premium feature.
extension PremiumFeatureLabel on PremiumFeature {
  String get label => switch (this) {
    PremiumFeature.advancedAnalytics => 'Advanced Analytics',
    PremiumFeature.smartInsights => 'Smart Insights',
    PremiumFeature.unlimitedGroups => 'Unlimited Groups',
    PremiumFeature.createChallenge => 'Create Challenges',
    PremiumFeature.privateGroups => 'Private Groups',
    PremiumFeature.accountabilityPartners => 'Accountability Partners',
    PremiumFeature.premiumWidgets => 'Premium Widgets',
    PremiumFeature.weeklyReports => 'Weekly Reports',
    PremiumFeature.heatmapView => 'Completion Heatmap',
    PremiumFeature.monthlyReports => 'Monthly Reports',
    PremiumFeature.yearlyReports => 'Yearly Reports',
    PremiumFeature.trendGraphs => 'Trend Graphs',
    PremiumFeature.streakHistory => 'Streak History',
    PremiumFeature.categoryInsights => 'Category Insights',
    PremiumFeature.unlimitedSharedHabits => 'Unlimited Shared Habits',
  };

  String get description => switch (this) {
    PremiumFeature.advancedAnalytics =>
      'Heatmaps, trends, and completion insights',
    PremiumFeature.smartInsights =>
      'Personalized insights about your habit patterns',
    PremiumFeature.unlimitedGroups =>
      'Create unlimited groups for your communities',
    PremiumFeature.createChallenge =>
      'Host public, private, or invite-only challenges',
    PremiumFeature.privateGroups =>
      'Private groups visible only to invited members',
    PremiumFeature.accountabilityPartners =>
      'Multiple accountability partners with weekly summaries',
    PremiumFeature.premiumWidgets =>
      'Beautiful home screen widgets for tracking',
    PremiumFeature.weeklyReports =>
      'Detailed weekly habit performance reports',
    PremiumFeature.heatmapView =>
      'Visual completion heatmap across your calendar',
    PremiumFeature.monthlyReports =>
      'Comprehensive monthly habit analytics',
    PremiumFeature.yearlyReports =>
      'Annual habit review and year-in-review',
    PremiumFeature.trendGraphs =>
      'Track your consistency trends over time',
    PremiumFeature.streakHistory =>
      'Complete history of all your streaks',
    PremiumFeature.categoryInsights =>
      'Performance breakdown by habit category',
    PremiumFeature.unlimitedSharedHabits =>
      'Share unlimited habits with friends',
  };
}
