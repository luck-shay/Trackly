// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Weekly Report Screen
// Beautiful weekly performance summary with shareable card.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/analytics_data.dart';
import '../providers/habits_provider.dart';
import '../providers/mood_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_layout.dart';

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final habits = context.watch<HabitsProvider>().habits;
    final moodProvider = context.watch<MoodProvider>();

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    const analyticsService = AnalyticsService();
    final analytics = analyticsService.computeForWeek(
      habits: habits,
      userId: userId,
      weekStart: weekStart,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Weekly Report',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: analytics.totalHabits == 0
          ? _buildEmptyState(scheme)
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppLayout.lg, 8, AppLayout.lg, 120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Week Label ──
                  _WeekHeader(weekStart: weekStart, scheme: scheme)
                      .animate()
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),

                  // ── Overall Score ──
                  _OverallScoreCard(
                    analytics: analytics,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 500.ms)
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1, 1),
                        delay: 100.ms,
                        duration: 500.ms,
                      ),
                  const SizedBox(height: 20),

                  // ── Stats Grid ──
                  _StatsGrid(
                    analytics: analytics,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 24),

                  // ── Mood Summary ──
                  if (moodProvider.recentMoods.isNotEmpty)
                    _MoodSummaryCard(
                      moods: moodProvider.recentMoods,
                      scheme: scheme,
                      isDark: isDark,
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms),
                  if (moodProvider.recentMoods.isNotEmpty)
                    const SizedBox(height: 24),

                  // ── Top Habits ──
                  _TopHabitsSection(
                    analytics: analytics,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms),
                  const SizedBox(height: 24),

                  // ── Trend ──
                  _TrendCard(
                    trend: analytics.trend,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 400.ms),
                ],
              ),
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
            Icon(Icons.bar_chart_rounded, size: 64,
                color: scheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No data yet',
              style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete some habits to generate your weekly report.',
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

// ── Week Header ─────────────────────────────────────────────────────────────

class _WeekHeader extends StatelessWidget {
  final DateTime weekStart;
  final ColorScheme scheme;

  const _WeekHeader({required this.weekStart, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your week in review',
          style: GoogleFonts.outfit(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${months[weekStart.month - 1]} ${weekStart.day} – ${months[weekEnd.month - 1]} ${weekEnd.day}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ── Overall Score Card ──────────────────────────────────────────────────────

class _OverallScoreCard extends StatelessWidget {
  final OverallAnalytics analytics;
  final ColorScheme scheme;
  final bool isDark;

  const _OverallScoreCard({
    required this.analytics,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (analytics.overallCompletionRate * 100).round();
    final grade = _grade(analytics.overallCompletionRate);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: analytics.overallCompletionRate,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        scheme.onSurface.withValues(alpha: 0.08),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
                Text(
                  '$pct%',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Overall completion rate this week',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _grade(double rate) {
    if (rate >= 0.9) return 'Outstanding! 🔥';
    if (rate >= 0.75) return 'Great week! 💪';
    if (rate >= 0.5) return 'Solid effort! 👍';
    if (rate >= 0.25) return 'Keep pushing! 🌱';
    return 'Fresh start! 🚀';
  }
}

// ── Stats Grid ──────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final OverallAnalytics analytics;
  final ColorScheme scheme;
  final bool isDark;

  const _StatsGrid({
    required this.analytics,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF9800),
            label: 'Best Streak',
            value: '${analytics.currentLongestStreak}d',
            scheme: scheme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            iconColor: scheme.primary,
            label: 'Completions',
            value: '${analytics.totalCompletions}',
            scheme: scheme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF7C4DFF),
            label: 'Active Days',
            value: '${analytics.activeDays}',
            scheme: scheme,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final ColorScheme scheme;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mood Summary Card ───────────────────────────────────────────────────────

class _MoodSummaryCard extends StatelessWidget {
  final List moods;
  final ColorScheme scheme;
  final bool isDark;

  const _MoodSummaryCard({
    required this.moods,
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
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mood_rounded, size: 22,
                color: Color(0xFFFF9800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Tracking',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${moods.length} mood entries logged this period',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
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

// ── Top Habits Section ──────────────────────────────────────────────────────

class _TopHabitsSection extends StatelessWidget {
  final OverallAnalytics analytics;
  final ColorScheme scheme;
  final bool isDark;

  const _TopHabitsSection({
    required this.analytics,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<HabitAnalytics>.from(analytics.perHabitAnalytics)
      ..sort((a, b) => b.completionRate.compareTo(a.completionRate));
    final top3 = sorted.take(3).toList();

    if (top3.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Habits',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...top3.asMap().entries.map((entry) {
          final index = entry.key;
          final habit = entry.value;
          final medals = ['🥇', '🥈', '🥉'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121816) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.onSurface
                      .withValues(alpha: isDark ? 0.06 : 0.04),
                ),
              ),
              child: Row(
                children: [
                  Text(medals[index], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.habitTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${(habit.completionRate * 100).round()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Trend Card ──────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final TrendData trend;
  final ColorScheme scheme;
  final bool isDark;

  const _TrendCard({
    required this.trend,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = trend.isImproving;
    final changeAbs = trend.changePercent.abs().round();

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
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isUp ? scheme.primary : Colors.orangeAccent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUp
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 22,
              color: isUp ? scheme.primary : Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUp ? 'Trending Up' : 'Room to Improve',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUp
                      ? 'Your completion rate improved by $changeAbs% vs last week'
                      : 'Your completion rate dipped $changeAbs% — you got this!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
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
