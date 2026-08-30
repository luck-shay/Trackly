import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../widgets/premium_upgrade_sheet.dart';
import 'feature_gate.dart';
import 'subscription_constants.dart';

/// Checks access before entering a premium feature and owns the upgrade prompt.
/// A `false` result always means the caller must stop its navigation/action.
Future<bool> requirePremiumFeatureAccess(
  BuildContext context, {
  required PremiumFeature feature,
}) async {
  final subscription = context.read<SubscriptionProvider>();
  if (FeatureGate.canUse(feature, hasProAccess: subscription.hasProAccess)) {
    return true;
  }

  if (!context.mounted) return false;
  await showPremiumUpgradeSheet(
    context,
    feature: feature,
    respectCooldown: false,
  );
  return false;
}