// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Insights Screen
// AI-powered habit coaching feed and smart analytics insights.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/insight.dart';
import '../providers/habits_provider.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/insights_service.dart';
import '../services/premium_feature_guard.dart';
import '../services/subscription_constants.dart';
import '../theme/app_layout.dart';
import '../theme/color_scheme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String? _aiCoachingMessage;
  bool _isLoadingAI = false;
  bool _accessChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  Future<void> _checkAccess() async {
    final canOpen = await requirePremiumFeatureAccess(
      context,
      feature: PremiumFeature.aiCoaching,
    );
    if (!mounted) return;
    if (!canOpen) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _accessChecked = true);
    await _loadAICoaching();
  }

  Future<void> _loadAICoaching() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final habits = context.read<HabitsProvider>().habits;
    if (habits.isEmpty) return;

    setState(() => _isLoadingAI = true);

    const analyticsService = AnalyticsService();
    final analytics = analyticsService.computeOverall(
      habits: habits,
      userId: userId,
    );

    final msg = await AIService.generateCoachingInsight(
      currentStreak: analytics.currentLongestStreak,
      completionRate: analytics.overallCompletionRate,
      bestDay: analytics.weekdayPerformance.dayName(analytics.weekdayPerformance.bestDay),
      worstDay: analytics.weekdayPerformance.dayName(analytics.weekdayPerformance.worstDay),
      totalHabits: analytics.totalHabits,
      totalCompletions: analytics.totalCompletions,
    );

    if (mounted) {
      setState(() {
        _aiCoachingMessage = msg;
        _isLoadingAI = false;
      });
    }
  }

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

    if (!_accessChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Coach & Insights',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: habits.isEmpty
          ? _buildEmptyState(scheme)
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppLayout.lg, 8, AppLayout.lg, 120,
              ),
              itemCount: insights.length + 2, // +1 header, +1 AI coach
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildAICoachCard(scheme, isDark),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms);
                }

                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Here\'s what we noticed',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pattern analysis derived from your habit history.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms);
                }

                final insight = insights[index - 2];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InsightCard(
                    insight: insight,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(
                        delay: (150 + (index - 2) * 80).ms,
                        duration: 400.ms,
                      )
                      .moveY(
                        begin: 12,
                        end: 0,
                        delay: (150 + (index - 2) * 80).ms,
                        duration: 400.ms,
                      ),
                );
              },
            ),
    );
  }

  Widget _buildAICoachCard(ColorScheme scheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.proBannerGradientDark : AppTheme.proBannerGradientLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.proAmber.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.proAmber.withValues(alpha: isDark ? 0.12 : 0.08),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.proBadgeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trackly AI Coach',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'Personalized Daily Habit Guidance',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.proAmber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_isLoadingAI)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.proAmber,
                  ),
                )
              else
                IconButton(
                  onPressed: _loadAICoaching,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppTheme.proAmber,
                  ),
                  tooltip: 'Refresh AI Coaching',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _aiCoachingMessage ??
                'Building consistency is a marathon, not a sprint. Focus on completing 1 habit at a time today! 🎯',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.55,
              color: scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ],
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
              'Complete more habits to unlock personalized AI coaching and insights.',
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
