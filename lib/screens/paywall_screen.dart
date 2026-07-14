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
          ? const Color(0xFF0B0F0C)
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
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── Pro badge ──────────────────────────────────────
                    Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'TRACKLY PRO',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .moveY(begin: -8, end: 0, duration: 500.ms),
                    const SizedBox(height: 24),

                    // ── Headline ───────────────────────────────────────
                    Text(
                          'Become the\nperson who\nstays consistent.',
                          style: GoogleFonts.outfit(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: scheme.onSurface,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 600.ms)
                        .moveY(begin: 16, end: 0, duration: 600.ms),
                    const SizedBox(height: 16),

                    // ── Subtitle ──────────────────────────────────────
                    Text(
                      'Trackly Pro helps you build habits that actually last '
                      'through deeper insights, accountability, and premium collaboration.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        height: 1.55,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                    const SizedBox(height: 40),

                    // ── Feature cards ─────────────────────────────────
                    ..._buildFeatureCards(scheme, isDark),
                    const SizedBox(height: 44),

                    // ── Pricing toggle ────────────────────────────────
                    _buildPricingSection(
                      scheme,
                      isDark,
                      monthlyPrice: monthlyPrice,
                      yearlyPrice: yearlyPrice,
                      yearlyMonthlyEquiv: yearlyMonthlyEquiv,
                    ),
                    const SizedBox(height: 32),

                    // ── CTA ────────────────────────────────────────────
                    SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isPurchasing
                                ? null
                                : () => _handlePurchase(sub, packages),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              disabledBackgroundColor: scheme.primary
                                  .withValues(alpha: 0.5),
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
                                    'Continue',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 800.ms, duration: 500.ms)
                        .moveY(begin: 12, end: 0, duration: 500.ms),
                    const SizedBox(height: 16),

                    // ── Fine print ─────────────────────────────────────
                    Center(
                      child: Text(
                        'Cancel anytime. Payment is charged through your App Store account.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.3),
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
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Purchase could not be completed. ${e.toString().split('\n').first}',
          ),
        ),
      );
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
