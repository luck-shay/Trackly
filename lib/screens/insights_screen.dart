// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Insights Screen
// Smart insights feed showing deterministic insights from analytics.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/insight.dart';
import '../providers/habits_provider.dart';
import '../services/analytics_service.dart';
import '../services/insights_service.dart';
import '../theme/app_layout.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final habits = context.watch<HabitsProvider>().habits;

    const analyticsService = AnalyticsService();
    const insightsService = InsightsService();

    final analytics = analyticsService.computeOverall(
      habits: habits,
      userId: userId,
    );
    final insights = insightsService.generate(analytics);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: insights.isEmpty
          ? _buildEmptyState(scheme)
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppLayout.lg, 8, AppLayout.lg, 120,
              ),
              itemCount: insights.length + 1, // +1 for header
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Here\'s what we noticed',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Based on your habit completion patterns.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms);
                }

                final insight = insights[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InsightCard(
                    insight: insight,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(
                        delay: (100 + (index - 1) * 80).ms,
                        duration: 400.ms,
                      )
                      .moveY(
                        begin: 12,
                        end: 0,
                        delay: (100 + (index - 1) * 80).ms,
                        duration: 400.ms,
                      ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No insights yet',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete more habits to unlock personalized insights.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight Card ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final Insight insight;
  final ColorScheme scheme;
  final bool isDark;

  const _InsightCard({
    required this.insight,
    required this.scheme,
    required this.isDark,
  });

  Color get _accentColor {
    return switch (insight.type) {
      InsightType.trendImprovement => scheme.primary,
      InsightType.streak => const Color(0xFFFF9800),
      InsightType.milestone => const Color(0xFFFFD700),
      InsightType.bestHabit => scheme.primary,
      InsightType.consistency => scheme.primary,
      InsightType.trendDecline => Colors.orangeAccent,
      InsightType.worstHabit => Colors.orangeAccent,
      _ => scheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

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
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(insight.icon, size: 22, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.6),
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
