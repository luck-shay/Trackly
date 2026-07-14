// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Analytics Screen
// Premium analytics dashboard with heatmap, streaks, weekday performance,
// trend graph, and per-habit breakdown.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/analytics_data.dart';
import '../providers/habits_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_layout.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final habits = context.watch<HabitsProvider>().habits;

    const analyticsService = AnalyticsService();
    final analytics = analyticsService.computeOverall(
      habits: habits,
      userId: userId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
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
                  // ── Overview Cards ────────────────────────────────
                  _OverviewRow(analytics: analytics, scheme: scheme)
                      .animate()
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 28),

                  // ── Heatmap ────────────────────────────────────────
                  _SectionTitle(title: 'Completion Heatmap'),
                  const SizedBox(height: 12),
                  _HeatmapCard(
                    heatmapData: analytics.heatmapData,
                    scheme: scheme,
                    isDark: isDark,
                    totalHabits: analytics.totalHabits,
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 28),

                  // ── Weekday Performance ────────────────────────────
                  _SectionTitle(title: 'Weekday Performance'),
                  const SizedBox(height: 12),
                  _WeekdayChart(
                    performance: analytics.weekdayPerformance,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 28),

                  // ── Trend ──────────────────────────────────────────
                  _SectionTitle(title: '30-Day Trend'),
                  const SizedBox(height: 12),
                  _TrendCard(
                    trend: analytics.trend,
                    scheme: scheme,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms),
                  const SizedBox(height: 28),

                  // ── Per-Habit Breakdown ────────────────────────────
                  if (analytics.perHabitAnalytics.isNotEmpty) ...[
                    _SectionTitle(title: 'Habit Breakdown'),
                    const SizedBox(height: 12),
                    ...analytics.perHabitAnalytics.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HabitBreakdownCard(
                          analytics: e.value,
                          scheme: scheme,
                          isDark: isDark,
                        )
                            .animate()
                            .fadeIn(
                              delay: (400 + e.key * 60).ms,
                              duration: 350.ms,
                            ),
                      );
                    }),
                  ],
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
            Icon(
              Icons.insights_rounded,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No data yet',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start completing habits to see your analytics here.',
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

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// ── Overview Row ──────────────────────────────────────────────────────────────

class _OverviewRow extends StatelessWidget {
  final OverallAnalytics analytics;
  final ColorScheme scheme;

  const _OverviewRow({required this.analytics, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Completion',
            value: '${(analytics.overallCompletionRate * 100).round()}%',
            scheme: scheme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Current Streak',
            value: '${analytics.currentLongestStreak}d',
            scheme: scheme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Best Streak',
            value: '${analytics.allTimeLongestStreak}d',
            scheme: scheme,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Heatmap Card ──────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  final Map<DateTime, int> heatmapData;
  final ColorScheme scheme;
  final bool isDark;
  final int totalHabits;

  const _HeatmapCard({
    required this.heatmapData,
    required this.scheme,
    required this.isDark,
    required this.totalHabits,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // Show last 91 days (13 weeks).
    const totalDays = 91;
    final startDate = today.subtract(const Duration(days: totalDays - 1));

    // Determine the max count for intensity scaling.
    int maxCount = 1;
    for (final count in heatmapData.values) {
      if (count > maxCount) maxCount = count;
    }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day labels
          Row(
            children: [
              const SizedBox(width: 0),
              ...['M', '', 'W', '', 'F', '', 'S'].map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: scheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = (constraints.maxWidth - 6 * 3) / 7;
              final weeks = (totalDays / 7).ceil();

              return Column(
                children: List.generate(weeks, (weekIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: List.generate(7, (dayIndex) {
                        final dayOffset = weekIndex * 7 + dayIndex;
                        final date = startDate.add(Duration(days: dayOffset));

                        if (date.isAfter(today)) {
                          return Expanded(child: SizedBox(height: cellSize));
                        }

                        final key = DateTime(date.year, date.month, date.day);
                        final count = heatmapData[key] ?? 0;
                        final intensity = count > 0
                            ? (count / maxCount).clamp(0.2, 1.0)
                            : 0.0;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: intensity > 0
                                      ? scheme.primary.withValues(alpha: intensity)
                                      : scheme.onSurface.withValues(
                                          alpha: isDark ? 0.06 : 0.04,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 4),
              ...[0.0, 0.25, 0.5, 0.75, 1.0].map(
                (i) => Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: i > 0
                        ? scheme.primary.withValues(alpha: i)
                        : scheme.onSurface.withValues(
                            alpha: isDark ? 0.06 : 0.04,
                          ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Weekday Chart ─────────────────────────────────────────────────────────────

class _WeekdayChart extends StatelessWidget {
  final WeekdayPerformance performance;
  final ColorScheme scheme;
  final bool isDark;

  const _WeekdayChart({
    required this.performance,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final weekday = i + 1;
          final rate = performance.rates[weekday] ?? 0;
          final isBest = weekday == performance.bestDay;
          final isWorst = weekday == performance.worstDay;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Text(
                    '${(rate * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isBest
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 80 * rate.clamp(0.05, 1.0),
                    decoration: BoxDecoration(
                      color: isBest
                          ? scheme.primary
                          : isWorst
                              ? scheme.primary.withValues(alpha: 0.2)
                              : scheme.primary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    WeekdayPerformance.dayNames[i],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
                      color: isBest
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Trend Card ────────────────────────────────────────────────────────────────

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trend.isImproving
                    ? Icons.trending_up_rounded
                    : trend.isDeclining
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                color: trend.isImproving
                    ? scheme.primary
                    : trend.isDeclining
                        ? Colors.orangeAccent
                        : scheme.onSurface.withValues(alpha: 0.4),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                trend.isImproving
                    ? '+${trend.changePercent.round()}% this week'
                    : trend.isDeclining
                        ? '${trend.changePercent.round()}% this week'
                        : 'Stable',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: trend.isImproving
                      ? scheme.primary
                      : trend.isDeclining
                          ? Colors.orangeAccent
                          : scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (trend.dailyRates.isNotEmpty)
            SizedBox(
              height: 60,
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _TrendLinePainter(
                  rates: trend.dailyRates.map((d) => d.rate).toList(),
                  color: scheme.primary,
                  isDark: isDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> rates;
  final Color color;
  final bool isDark;

  _TrendLinePainter({
    required this.rates,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rates.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final dx = size.width / (rates.length - 1).clamp(1, rates.length);

    for (int i = 0; i < rates.length; i++) {
      final x = i * dx;
      final y = size.height - (rates[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      rates != oldDelegate.rates || color != oldDelegate.color;
}

// ── Habit Breakdown Card ──────────────────────────────────────────────────────

class _HabitBreakdownCard extends StatelessWidget {
  final HabitAnalytics analytics;
  final ColorScheme scheme;
  final bool isDark;

  const _HabitBreakdownCard({
    required this.analytics,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (analytics.completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Row(
        children: [
          // Completion ring
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: _CompletionRingPainter(
                progress: analytics.completionRate.clamp(0.0, 1.0),
                color: scheme.primary,
                backgroundColor:
                    scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analytics.habitTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${analytics.currentStreak}d streak · ${analytics.totalCompletions} completions',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.5),
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

class _CompletionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CompletionRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    const strokeWidth = 4.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CompletionRingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
