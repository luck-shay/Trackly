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

const int kFreeSharedTaskLimit = 3;
const int kSharedTaskMaxMembers = 3;
