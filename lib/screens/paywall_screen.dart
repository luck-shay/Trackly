// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Custom Paywall Screen
// Apple-quality full-screen paywall experience.
// Large typography. Beautiful spacing. Outcome-driven copy.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../services/subscription_constants.dart';

import '../theme/color_scheme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _yearlySelected = true;
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = context.watch<SubscriptionProvider>();
    final subState = sub.state;

    // Try to get real prices from RevenueCat offerings; fall back to constants.
    final packages = subState.offerings?.current?.availablePackages ?? const [];
    String monthlyPrice = kMonthlyPriceDisplay;
    String yearlyPrice = kYearlyPriceDisplay;
    String? yearlyMonthlyEquiv;

    for (final pkg in packages) {
      final id = pkg.storeProduct.identifier;
      if (id == 'monthly') {
        monthlyPrice = pkg.storeProduct.priceString;
      } else if (id == 'yearly') {
        yearlyPrice = pkg.storeProduct.priceString;
      }
    }
    yearlyMonthlyEquiv = kYearlyPerMonthDisplay;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090D0A)
          : const Color(0xFFF8FAF9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isPurchasing
                        ? null
                        : () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            final navigator = Navigator.of(context);
                            setState(() => _isPurchasing = true);
                            try {
                              await sub.restore();
                              if (!context.mounted) return;
                              final hasAccess = sub.hasProAccess;
                              if (hasAccess) {
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Purchases restored successfully.',
                                    ),
                                  ),
                                );
                              } else {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No previous purchases found.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not restore. ${e.toString().split('\n').first}',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isPurchasing = false);
                              }
                            }
                          },
                    child: Text(
                      'Restore',
                      style: GoogleFonts.inter(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Pro badge header ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.proBadgeGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.proAmber.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            size: 15,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TRACKLY PRO',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .moveY(begin: -8, end: 0, duration: 500.ms),
                    const SizedBox(height: 20),

                    // ── Headline ───────────────────────────────────────
                    Text(
                          'Elevate your habits.\nUnlock your potential.',
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            color: scheme.onSurface,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 600.ms)
                        .moveY(begin: 16, end: 0, duration: 600.ms),
                    const SizedBox(height: 12),

                    // ── Subtitle ──────────────────────────────────────
                    Text(
                      'Trackly Pro gives you full access to AI habit coaching, heatmaps, unlimited group challenges, and custom widgets.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                    const SizedBox(height: 28),

                    // ── Feature cards ─────────────────────────────────
                    ..._buildFeatureCards(scheme, isDark),
                    const SizedBox(height: 28),

                    // ── Free vs Pro Comparison ────────────────────────
                    _buildComparisonSection(scheme, isDark),
                    const SizedBox(height: 32),

                    // ── Pricing toggle ────────────────────────────────
                    _buildPricingSection(
                      scheme,
                      isDark,
                      monthlyPrice: monthlyPrice,
                      yearlyPrice: yearlyPrice,
                      yearlyMonthlyEquiv: yearlyMonthlyEquiv,
                    ),
                    const SizedBox(height: 28),

                    // ── CTA Button ────────────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: AppTheme.proBadgeGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.proAmber.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isPurchasing
                            ? null
                            : () => _handlePurchase(sub, packages),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                        ),
                        child: _isPurchasing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Start 7-Day Free Trial',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 800.ms, duration: 500.ms)
                        .moveY(begin: 12, end: 0, duration: 500.ms),
                    const SizedBox(height: 14),

                    // ── Fine print ─────────────────────────────────────
                    Center(
                      child: Text(
                        '7 days free, then $_yearlySelected ? "$yearlyPrice/yr" : "$monthlyPrice/mo". Cancel anytime in App Store settings.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Feature Cards ─────────────────────────────────────────────────────────

  List<Widget> _buildFeatureCards(ColorScheme scheme, bool isDark) {
    const features = <_FeatureCardData>[
      _FeatureCardData(
        icon: Icons.insights_rounded,
        title: 'Advanced Analytics',
        subtitle:
            'Understand your patterns with heatmaps, trends, and weekly reports.',
      ),
      _FeatureCardData(
        icon: Icons.auto_awesome_rounded,
        title: 'Smart Insights',
        subtitle:
            'Personalized observations about your habits — what\'s working, what isn\'t.',
      ),
      _FeatureCardData(
        icon: Icons.groups_rounded,
        title: 'Unlimited Collaboration',
        subtitle:
            'Unlimited groups, shared habits, and private spaces for your communities.',
      ),
      _FeatureCardData(
        icon: Icons.emoji_events_rounded,
        title: 'Premium Challenges',
        subtitle: 'Create and host public, private, or invite-only challenges.',
      ),
      _FeatureCardData(
        icon: Icons.handshake_rounded,
        title: 'Accountability',
        subtitle: 'Multiple accountability partners with weekly summaries.',
      ),
      _FeatureCardData(
        icon: Icons.widgets_rounded,
        title: 'Premium Widgets',
        subtitle:
            'Beautiful home screen widgets for progress, heatmaps, and streaks.',
      ),
    ];

    return features.asMap().entries.map((entry) {
      final i = entry.key;
      final f = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child:
            _FeatureCard(
                  icon: f.icon,
                  title: f.title,
                  subtitle: f.subtitle,
                  scheme: scheme,
                  isDark: isDark,
                )
                .animate()
                .fadeIn(delay: (400 + i * 80).ms, duration: 400.ms)
                .moveX(
                  begin: 20,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
      );
    }).toList();
  }

  Widget _buildComparisonSection(ColorScheme scheme, bool isDark) {
    final rows = [
      ('Track Habits', 'Basic', 'Unlimited'),
      ('Group Creation', '1 Group', 'Unlimited'),
      ('AI Habit Coach', '❌', 'Included'),
      ('Completion Heatmap', '❌', 'Included'),
      ('Custom Home Widgets', 'Basic', 'Full Suite'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Free vs Trackly Pro',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Feature',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Free',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PRO',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.proAmber,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.$1,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      r.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      r.$3,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.proAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  // ── Pricing Section ───────────────────────────────────────────────────────

  Widget _buildPricingSection(
    ColorScheme scheme,
    bool isDark, {
    required String monthlyPrice,
    required String yearlyPrice,
    String? yearlyMonthlyEquiv,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your plan',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
        const SizedBox(height: 16),

        // Yearly option (recommended)
        GestureDetector(
          onTap: () => setState(() => _yearlySelected = true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _yearlySelected
                  ? scheme.primary.withValues(alpha: isDark ? 0.1 : 0.06)
                  : (isDark ? const Color(0xFF121816) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _yearlySelected
                    ? scheme.primary.withValues(alpha: 0.5)
                    : scheme.onSurface.withValues(alpha: 0.08),
                width: _yearlySelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Yearly',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Save $kYearlySavingsPercent%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        yearlyMonthlyEquiv != null
                            ? '$yearlyMonthlyEquiv/month'
                            : yearlyPrice,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$yearlyPrice/yr',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _yearlySelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 750.ms, duration: 400.ms),
        const SizedBox(height: 10),

        // Monthly option
        GestureDetector(
          onTap: () => setState(() => _yearlySelected = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: !_yearlySelected
                  ? scheme.primary.withValues(alpha: isDark ? 0.1 : 0.06)
                  : (isDark ? const Color(0xFF121816) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: !_yearlySelected
                    ? scheme.primary.withValues(alpha: 0.5)
                    : scheme.onSurface.withValues(alpha: 0.08),
                width: !_yearlySelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Monthly',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '$monthlyPrice/mo',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: !_yearlySelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
      ],
    );
  }

  // ── Purchase Handler ──────────────────────────────────────────────────────

  Future<void> _handlePurchase(SubscriptionProvider sub, List packages) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isPurchasing = true);

    try {
      if (!sub.isEnabled) {
        await sub.purchase(null);
        if (!context.mounted) return;
        navigator.pop();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Mock Purchase successful! Welcome to Trackly Pro! 🎉',
            ),
          ),
        );
        return;
      }

      final targetId = _yearlySelected ? 'yearly' : 'monthly';
      final package = packages.cast().firstWhere(
        (p) => p.storeProduct.identifier == targetId,
        orElse: () => null,
      );

      if (package != null) {
        await sub.purchase(package);
        if (!context.mounted) return;
        if (sub.hasProAccess) {
          navigator.pop();
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Welcome to Trackly Pro! 🎉')),
          );
        }
      } else {
        // Fallback: present RevenueCat native paywall if packages aren't loaded.
        await sub.presentPaywall();
        if (!context.mounted) return;
        if (sub.hasProAccess) {
          navigator.pop();
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      final err = e.toString();
      final isCancelled = err.contains('PURCHASE_CANCELLED') ||
          err.contains('userCancelled') ||
          err.contains('Purchase was cancelled') ||
          err.contains('userCancelled: true');
      if (!isCancelled) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Purchase could not be completed. ${err.split('\n').first}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }
}

// ── Feature Card ──────────────────────────────────────────────────────────────

class _FeatureCardData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme scheme;
  final bool isDark;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
