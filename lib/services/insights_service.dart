// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Insights Service
// Deterministic insight generation from analytics data.
// Designed with an interface so AI can later replace or enhance generation.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../models/analytics_data.dart';
import '../models/insight.dart';

/// Abstract interface for insight generation.
/// Current implementation is deterministic; can be swapped with AI later.
abstract class InsightGenerator {
  List<Insight> generate(OverallAnalytics analytics);
}

/// Deterministic insight generator that creates human-readable insights
/// from computed analytics data.
class InsightsService implements InsightGenerator {
  const InsightsService();

  @override
  List<Insight> generate(OverallAnalytics analytics) {
    final insights = <Insight>[];

    if (analytics.totalHabits == 0) return insights;

    _addStreakInsights(analytics, insights);
    _addWeekdayInsights(analytics, insights);
    _addTrendInsights(analytics, insights);
    _addCompletionInsights(analytics, insights);
    _addHabitComparisonInsights(analytics, insights);
    _addMilestoneInsights(analytics, insights);
    _addConsistencyInsights(analytics, insights);

    // Sort by priority (lower number = higher priority).
    insights.sort((a, b) => a.priority.compareTo(b.priority));

    return insights;
  }

  // ── Streak Insights ─────────────────────────────────────────────────────

  void _addStreakInsights(OverallAnalytics analytics, List<Insight> insights) {
    if (analytics.currentLongestStreak > 0) {
      insights.add(Insight(
        type: InsightType.streak,
        title: 'Current streak',
        message:
            "You're on a ${analytics.currentLongestStreak}-day streak. Keep going!",
        icon: Icons.local_fire_department_rounded,
        priority: 10,
      ));
    }

    if (analytics.allTimeLongestStreak > 7) {
      insights.add(Insight(
        type: InsightType.streak,
        title: 'Personal best',
        message:
            'Your longest streak ever is ${analytics.allTimeLongestStreak} days.',
        icon: Icons.emoji_events_rounded,
        priority: 20,
      ));
    }
  }

  // ── Weekday Insights ────────────────────────────────────────────────────

  void _addWeekdayInsights(OverallAnalytics analytics, List<Insight> insights) {
    final wp = analytics.weekdayPerformance;
    final bestRate = wp.rates[wp.bestDay] ?? 0;
    final worstRate = wp.rates[wp.worstDay] ?? 0;

    if (bestRate > 0) {
      final bestName = wp.dayName(wp.bestDay);
      final pct = (bestRate * 100).round();
      insights.add(Insight(
        type: InsightType.weekdayPattern,
        title: 'Strongest day',
        message: '$bestName is your most productive day at $pct% completion.',
        icon: Icons.star_rounded,
        priority: 30,
      ));
    }

    if (worstRate < bestRate && worstRate < 0.5) {
      final worstName = wp.dayName(wp.worstDay);
      final pct = (worstRate * 100).round();
      insights.add(Insight(
        type: InsightType.weekdayPattern,
        title: 'Room to grow',
        message:
            '${worstName}s are your weakest day at $pct% completion. Try setting a reminder.',
        icon: Icons.trending_down_rounded,
        priority: 40,
      ));
    }
  }

  // ── Trend Insights ──────────────────────────────────────────────────────

  void _addTrendInsights(OverallAnalytics analytics, List<Insight> insights) {
    final trend = analytics.trend;

    if (trend.isImproving && trend.changePercent.abs() >= 5) {
      insights.add(Insight(
        type: InsightType.trendImprovement,
        title: 'Improving',
        message:
            "You've improved consistency by ${trend.changePercent.round()}% this week.",
        icon: Icons.trending_up_rounded,
        priority: 15,
      ));
    }

    if (trend.isDeclining && trend.changePercent.abs() >= 10) {
      insights.add(Insight(
        type: InsightType.trendDecline,
        title: 'Slight dip',
        message:
            'Your completion rate dipped ${trend.changePercent.abs().round()}% this week. That\'s okay — consistency rebounds.',
        icon: Icons.trending_down_rounded,
        priority: 25,
      ));
    }
  }

  // ── Completion Insights ─────────────────────────────────────────────────

  void _addCompletionInsights(
    OverallAnalytics analytics,
    List<Insight> insights,
  ) {
    final rate = analytics.overallCompletionRate;
    final pct = (rate * 100).round();

    if (pct >= 80) {
      insights.add(Insight(
        type: InsightType.completionRate,
        title: 'Outstanding',
        message: 'Your overall completion rate is $pct%. You\'re crushing it.',
        icon: Icons.verified_rounded,
        priority: 12,
      ));
    } else if (pct >= 50) {
      insights.add(Insight(
        type: InsightType.completionRate,
        title: 'Solid progress',
        message:
            'Your overall completion rate is $pct%. Consistency over perfection.',
        icon: Icons.thumb_up_rounded,
        priority: 35,
      ));
    }

    if (analytics.totalCompletions > 0) {
      insights.add(Insight(
        type: InsightType.completionRate,
        title: 'Total completions',
        message:
            "You've completed habits ${analytics.totalCompletions} times across ${analytics.activeDays} active days.",
        icon: Icons.check_circle_outline_rounded,
        priority: 45,
      ));
    }
  }

  // ── Habit Comparison Insights ───────────────────────────────────────────

  void _addHabitComparisonInsights(
    OverallAnalytics analytics,
    List<Insight> insights,
  ) {
    final perHabit = analytics.perHabitAnalytics;
    if (perHabit.length < 2) return;

    // Find best and worst habit by completion rate.
    HabitAnalytics best = perHabit.first;
    HabitAnalytics worst = perHabit.first;
    for (final ha in perHabit) {
      if (ha.completionRate > best.completionRate) best = ha;
      if (ha.completionRate < worst.completionRate) worst = ha;
    }

    if (best.completionRate > 0) {
      final pct = (best.completionRate * 100).round();
      insights.add(Insight(
        type: InsightType.bestHabit,
        title: 'Top habit',
        message:
            '"${best.habitTitle}" has your highest completion rate at $pct%.',
        icon: Icons.workspace_premium_rounded,
        priority: 22,
      ));
    }

    if (worst.habitId != best.habitId && worst.completionRate < 0.3) {
      final pct = (worst.completionRate * 100).round();
      insights.add(Insight(
        type: InsightType.worstHabit,
        title: 'Needs attention',
        message:
            '"${worst.habitTitle}" is at $pct% completion. Consider adjusting your schedule.',
        icon: Icons.info_outline_rounded,
        priority: 42,
      ));
    }
  }

  // ── Milestone Insights ──────────────────────────────────────────────────

  void _addMilestoneInsights(
    OverallAnalytics analytics,
    List<Insight> insights,
  ) {
    final total = analytics.totalCompletions;

    if (total >= 1000) {
      insights.add(Insight(
        type: InsightType.milestone,
        title: '🎉 1,000+ completions',
        message:
            'You\'ve hit over 1,000 habit completions. Remarkable dedication.',
        icon: Icons.celebration_rounded,
        priority: 5,
      ));
    } else if (total >= 500) {
      insights.add(Insight(
        type: InsightType.milestone,
        title: '🎉 500+ completions',
        message:
            'Over 500 completions! You\'re building something lasting.',
        icon: Icons.celebration_rounded,
        priority: 8,
      ));
    } else if (total >= 100) {
      insights.add(Insight(
        type: InsightType.milestone,
        title: '🎉 100 completions',
        message:
            'You\'ve reached 100 completions. The compound effect is real.',
        icon: Icons.celebration_rounded,
        priority: 10,
      ));
    }
  }

  // ── Consistency Insights ────────────────────────────────────────────────

  void _addConsistencyInsights(
    OverallAnalytics analytics,
    List<Insight> insights,
  ) {
    if (analytics.totalTrackedDays == 0) return;

    final consistencyRate = analytics.activeDays / analytics.totalTrackedDays;

    if (consistencyRate >= 0.9) {
      insights.add(Insight(
        type: InsightType.consistency,
        title: 'Incredible consistency',
        message:
            'You\'ve been active ${analytics.activeDays} out of ${analytics.totalTrackedDays} days. That\'s ${(consistencyRate * 100).round()}% consistency.',
        icon: Icons.auto_awesome_rounded,
        priority: 8,
      ));
    } else if (consistencyRate >= 0.7) {
      insights.add(Insight(
        type: InsightType.consistency,
        title: 'Strong consistency',
        message:
            'Active ${analytics.activeDays} out of ${analytics.totalTrackedDays} days — ${(consistencyRate * 100).round()}% consistency.',
        icon: Icons.timeline_rounded,
        priority: 28,
      ));
    }
  }
}
