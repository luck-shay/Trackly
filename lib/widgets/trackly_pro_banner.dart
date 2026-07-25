import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../screens/insights_screen.dart';
import '../screens/paywall_screen.dart';
import '../theme/color_scheme.dart';

class TracklyProBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const TracklyProBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final hasPro = sub.hasProAccess;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else if (hasPro) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InsightsScreen()),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.proBannerGradientDark
                : AppTheme.proBannerGradientLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasPro
                  ? AppTheme.proGold.withValues(alpha: 0.5)
                  : AppTheme.proAmber.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasPro ? AppTheme.proGold : AppTheme.proAmber)
                    .withValues(alpha: isDark ? 0.12 : 0.08),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.proBadgeGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPro ? 'PRO MEMBER ACTIVE ✦' : 'TRACKLY PRO',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.proAmber.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                hasPro
                    ? 'Trackly Pro Membership Active'
                    : 'Supercharge your consistency',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasPro
                    ? 'Tap to open your personalized AI Habit Coach & daily recommendations.'
                    : 'Get AI habit coaching, completion heatmaps, and unlimited group collaboration.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FeaturePill(
                      icon: Icons.auto_awesome_rounded,
                      label: hasPro ? 'AI Coach Active' : 'AI Coach',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FeaturePill(
                      icon: Icons.grid_on_rounded,
                      label: hasPro ? 'Heatmaps Unlocked' : 'Heatmaps',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FeaturePill(
                      icon: Icons.groups_rounded,
                      label: 'Unlimited Groups',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).moveY(begin: 10, end: 0, duration: 450.ms);
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.proAmber.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.proAmber.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.proAmber),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
