// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Premium Upgrade Sheet
// Elegant contextual bottom sheet shown when free users attempt premium features.
// Respects cooldown. Never intrusive.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/subscription_constants.dart';
import '../screens/paywall_screen.dart';
import '../theme/color_scheme.dart';

/// Shows a premium upgrade bottom sheet for a specific feature.
///
/// Respects cooldown — won't show again within [kUpgradeSheetCooldown].
/// Returns `true` if the paywall was opened, `false` otherwise.
Future<bool> showPremiumUpgradeSheet(
  BuildContext context, {
  required PremiumFeature feature,
  bool respectCooldown = true,
}) async {
  if (respectCooldown) {
    final canShow = await _canShowUpgradeSheet();
    if (!canShow) return false;
  }

  await _recordUpgradeSheetShown();

  if (!context.mounted) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _PremiumUpgradeSheetContent(feature: feature),
  );

  return result ?? false;
}

Future<bool> _canShowUpgradeSheet() async {
  final prefs = await SharedPreferences.getInstance();
  final lastShown = prefs.getString(kLastUpgradePromptKey);
  if (lastShown == null) return true;
  final lastTime = DateTime.tryParse(lastShown);
  if (lastTime == null) return true;
  return DateTime.now().difference(lastTime) >= kUpgradeSheetCooldown;
}

Future<void> _recordUpgradeSheetShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kLastUpgradePromptKey,
    DateTime.now().toIso8601String(),
  );
}

class _PremiumUpgradeSheetContent extends StatelessWidget {
  final PremiumFeature feature;

  const _PremiumUpgradeSheetContent({required this.feature});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppTheme.proAmber.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon with Gold Gradient Border
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: AppTheme.proBadgeGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.proAmber.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121816) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 34,
                    color: AppTheme.proAmber,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 20),

              // Pro Feature Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.proAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.proAmber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'TRACKLY PRO FEATURE',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.proAmber,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                feature.label,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .moveY(begin: 8, end: 0, duration: 400.ms),
              const SizedBox(height: 8),

              // Description
              Text(
                feature.description,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 28),

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.proBadgeGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.proAmber.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PaywallScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Unlock with Trackly Pro',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms)
                  .moveY(begin: 12, end: 0, duration: 400.ms),
              const SizedBox(height: 12),

              // Secondary dismiss
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: GoogleFonts.inter(
                    color: scheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 14,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
