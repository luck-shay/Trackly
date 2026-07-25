// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Analytics Service
// Deterministic analytics engine that processes habit completion data.
// Pure computation layer — no Firestore dependency.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/analytics_data.dart';
import '../models/habit.dart';

class AnalyticsService {
  const AnalyticsService();

  // ── Overall Analytics ───────────────────────────────────────────────────

  /// Computes aggregated analytics across all habits for a given user.
  /// Computes aggregated analytics across all habits for a given user.
  OverallAnalytics computeOverall({
    required List<Habit> habits,
    required String userId,
  }) {
    if (habits.isEmpty) return OverallAnalytics.empty;

    final perHabit = habits
        .map((h) => computeForHabit(habit: h, userId: userId))
        .toList();

    final totalCompletions = perHabit.fold<int>(
      0, (sum, a) => sum + a.totalCompletions,
    );

    final heatmap = _computeHeatmap(habits: habits, userId: userId);
    final weekday = _computeWeekdayPerformance(habits: habits, userId: userId);
    final trend = _computeOverallTrend(habits: habits, userId: userId);

    int allTimeLongest = 0;
    int currentLongest = 0;
    for (final ha in perHabit) {
      if (ha.longestStreak > allTimeLongest) {
        allTimeLongest = ha.longestStreak;
      }
      if (ha.currentStreak > currentLongest) {
        currentLongest = ha.currentStreak;
      }
    }

    final now = DateTime.now();
    final activeDays = heatmap.keys.length;

    // Total tracked days: days since earliest habit creation.
    DateTime? earliest;
    for (final h in habits) {
      if (earliest == null || h.createdAt.isBefore(earliest)) {
        earliest = h.createdAt;
      }
    }
    final totalTrackedDays = earliest != null
        ? now.difference(_dateOnly(earliest)).inDays + 1
        : 0;

    double totalExpectedCompletions = 0;
    for (final h in habits) {
      final days = now.difference(_dateOnly(h.createdAt)).inDays + 1;
      totalExpectedCompletions += (days * (h.targetDaysPerWeek / 7.0)).clamp(1.0, 10000.0);
    }

    final overallRate = totalExpectedCompletions > 0 && habits.isNotEmpty
        ? (totalCompletions / totalExpectedCompletions).clamp(0.0, 1.0)
        : 0.0;

    return OverallAnalytics(
      totalHabits: habits.length,
      totalCompletions: totalCompletions,
      overallCompletionRate: overallRate,
      currentLongestStreak: currentLongest,
      allTimeLongestStreak: allTimeLongest,
      weekdayPerformance: weekday,
      heatmapData: heatmap,
      perHabitAnalytics: perHabit,
      trend: trend,
      activeDays: activeDays,
      totalTrackedDays: totalTrackedDays,
    );
  }

  /// Computes weekly analytics specifically for a 7-day week window (Mon-Sun).
  OverallAnalytics computeForWeek({
    required List<Habit> habits,
    required String userId,
    required DateTime weekStart,
  }) {
    if (habits.isEmpty) return OverallAnalytics.empty;

    final weekStartOnly = _dateOnly(weekStart);
    final weekEndOnly = weekStartOnly.add(const Duration(days: 6));
    final nowOnly = _dateOnly(DateTime.now());

    final perHabit = habits
        .map((h) => computeForHabitInDateRange(
              habit: h,
              userId: userId,
              start: weekStartOnly,
              end: weekEndOnly,
            ))
        .toList();

    final totalCompletions = perHabit.fold<int>(
      0, (sum, a) => sum + a.totalCompletions,
    );

    final heatmap = _computeHeatmap(habits: habits, userId: userId);
    final weekday = _computeWeekdayPerformance(habits: habits, userId: userId);
    final trend = _computeOverallTrend(habits: habits, userId: userId);

    int allTimeLongest = 0;
    int currentLongest = 0;
    for (final ha in perHabit) {
      if (ha.longestStreak > allTimeLongest) {
        allTimeLongest = ha.longestStreak;
      }
      if (ha.currentStreak > currentLongest) {
        currentLongest = ha.currentStreak;
      }
    }

    final activeDaysThisWeek = heatmap.keys
        .where((d) => !d.isBefore(weekStartOnly) && !d.isAfter(weekEndOnly))
        .length;

    double totalExpectedCompletions = 0;
    for (final h in habits) {
      final habitStart = _dateOnly(h.createdAt);
      int daysElapsedThisWeek = 0;
      for (int i = 0; i < 7; i++) {
        final d = weekStartOnly.add(Duration(days: i));
        if (!d.isAfter(nowOnly) && !d.isBefore(habitStart)) {
          daysElapsedThisWeek++;
        }
      }
      if (daysElapsedThisWeek <= 0 && !nowOnly.isBefore(habitStart)) {
        daysElapsedThisWeek = 1;
      }
      final expectedForHabit = (h.targetDaysPerWeek * (daysElapsedThisWeek / 7.0)).clamp(1.0, 7.0);
      totalExpectedCompletions += expectedForHabit;
    }

    final overallRate = totalExpectedCompletions > 0
        ? (totalCompletions / totalExpectedCompletions).clamp(0.0, 1.0)
        : 0.0;

    return OverallAnalytics(
      totalHabits: habits.length,
      totalCompletions: totalCompletions,
      overallCompletionRate: overallRate,
      currentLongestStreak: currentLongest,
      allTimeLongestStreak: allTimeLongest,
      weekdayPerformance: weekday,
      heatmapData: heatmap,
      perHabitAnalytics: perHabit,
      trend: trend,
      activeDays: activeDaysThisWeek,
      totalTrackedDays: 7,
    );
  }

  // ── Per-Habit Analytics ─────────────────────────────────────────────────

  /// Computes analytics for a single habit.
  HabitAnalytics computeForHabit({
    required Habit habit,
    required String userId,
  }) {
    final completions = _userCompletions(habit, userId);
    final sorted = completions.toList()
      ..sort((a, b) => a.compareTo(b));

    final totalCompletions = sorted.length;
    final streaks = _computeStreaks(sorted);
    final currentStreak = _currentStreak(sorted);
    final longestStreak = streaks.isEmpty
        ? 0
        : streaks.map((s) => s.length).reduce((a, b) => a > b ? a : b);
    final weekday = _computeWeekdayForDates(sorted, habit.createdAt);
    final trend = _computeTrendForDates(sorted, habit.createdAt);

    final now = DateTime.now();
    final daysSinceCreation = now
        .difference(_dateOnly(habit.createdAt))
        .inDays + 1;
    final expectedCompletions = (daysSinceCreation * (habit.targetDaysPerWeek / 7.0)).clamp(1.0, 10000.0);
    final completionRate = (totalCompletions / expectedCompletions).clamp(0.0, 1.0);

    return HabitAnalytics(
      habitId: habit.id,
      habitTitle: habit.title,
      totalCompletions: totalCompletions,
      completionRate: completionRate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      streakHistory: streaks,
      weekdayPerformance: weekday,
      trend: trend,
      targetDaysPerWeek: habit.targetDaysPerWeek,
    );
  }

  /// Computes analytics for a single habit within a specific date range.
  HabitAnalytics computeForHabitInDateRange({
    required Habit habit,
    required String userId,
    required DateTime start,
    required DateTime end,
  }) {
    final allCompletions = _userCompletions(habit, userId);
    final rangeCompletions = allCompletions
        .where((d) => !_dateOnly(d).isBefore(_dateOnly(start)) && !_dateOnly(d).isAfter(_dateOnly(end)))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    final totalCompletions = rangeCompletions.length;
    final streaks = _computeStreaks(allCompletions);
    final currentStreak = _currentStreak(allCompletions);
    final longestStreak = streaks.isEmpty
        ? 0
        : streaks.map((s) => s.length).reduce((a, b) => a > b ? a : b);
    final weekday = _computeWeekdayForDates(allCompletions, habit.createdAt);
    final trend = _computeTrendForDates(allCompletions, habit.createdAt);

    final nowOnly = _dateOnly(DateTime.now());
    final habitStart = _dateOnly(habit.createdAt);

    int daysElapsed = 0;
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      if (!d.isAfter(nowOnly) && !d.isBefore(habitStart)) {
        daysElapsed++;
      }
    }
    if (daysElapsed <= 0) daysElapsed = 1;

    final expected = (habit.targetDaysPerWeek * (daysElapsed / 7.0)).clamp(1.0, 7.0);
    final completionRate = (totalCompletions / expected).clamp(0.0, 1.0);

    return HabitAnalytics(
      habitId: habit.id,
      habitTitle: habit.title,
      totalCompletions: totalCompletions,
      completionRate: completionRate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      streakHistory: streaks,
      weekdayPerformance: weekday,
      trend: trend,
      targetDaysPerWeek: habit.targetDaysPerWeek,
    );
  }

  // ── Heatmap ─────────────────────────────────────────────────────────────

  Map<DateTime, int> _computeHeatmap({
    required List<Habit> habits,
    required String userId,
  }) {
    final map = <DateTime, int>{};
    for (final habit in habits) {
      for (final date in _userCompletions(habit, userId)) {
        final key = _dateOnly(date);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  // ── Weekday Performance ─────────────────────────────────────────────────

  WeekdayPerformance _computeWeekdayPerformance({
    required List<Habit> habits,
    required String userId,
  }) {
    final allDates = <DateTime>[];
    DateTime? earliest;
    for (final habit in habits) {
      final dates = _userCompletions(habit, userId);
      allDates.addAll(dates);
      if (earliest == null || habit.createdAt.isBefore(earliest)) {
        earliest = habit.createdAt;
      }
    }
    return _computeWeekdayForDates(allDates, earliest ?? DateTime.now());
  }

  WeekdayPerformance _computeWeekdayForDates(
    List<DateTime> dates,
    DateTime since,
  ) {
    final counts = <int, int>{
      for (int d = 1; d <= 7; d++) d: 0,
    };
    final totalWeeks = <int, int>{
      for (int d = 1; d <= 7; d++) d: 0,
    };

    for (final date in dates) {
      counts[date.weekday] = (counts[date.weekday] ?? 0) + 1;
    }

    // Count how many of each weekday have occurred since the start date.
    final now = DateTime.now();
    final start = _dateOnly(since);
    for (var d = start;
        !d.isAfter(now);
        d = d.add(const Duration(days: 1))) {
      totalWeeks[d.weekday] = (totalWeeks[d.weekday] ?? 0) + 1;
    }

    final rates = <int, double>{};
    for (int d = 1; d <= 7; d++) {
      final total = totalWeeks[d] ?? 1;
      rates[d] = total > 0
          ? ((counts[d] ?? 0) / total).clamp(0.0, 1.0)
          : 0.0;
    }

    int bestDay = 1;
    int worstDay = 1;
    for (int d = 1; d <= 7; d++) {
      if ((rates[d] ?? 0) > (rates[bestDay] ?? 0)) bestDay = d;
      if ((rates[d] ?? 0) < (rates[worstDay] ?? 0)) worstDay = d;
    }

    return WeekdayPerformance(
      rates: rates,
      bestDay: bestDay,
      worstDay: worstDay,
    );
  }

  // ── Streaks ─────────────────────────────────────────────────────────────

  List<StreakRecord> _computeStreaks(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return [];

    final streaks = <StreakRecord>[];
    final uniqueDates = sortedDates.map(_dateOnly).toSet().toList()..sort();

    if (uniqueDates.isEmpty) return [];

    var streakStart = uniqueDates.first;
    var streakEnd = uniqueDates.first;

    for (int i = 1; i < uniqueDates.length; i++) {
      final diff = uniqueDates[i].difference(uniqueDates[i - 1]).inDays;
      if (diff == 1) {
        streakEnd = uniqueDates[i];
      } else {
        final length = streakEnd.difference(streakStart).inDays + 1;
        streaks.add(StreakRecord(
          startDate: streakStart,
          endDate: streakEnd,
          length: length,
        ));
        streakStart = uniqueDates[i];
        streakEnd = uniqueDates[i];
      }
    }

    // Add the last streak.
    final length = streakEnd.difference(streakStart).inDays + 1;
    streaks.add(StreakRecord(
      startDate: streakStart,
      endDate: streakEnd,
      length: length,
    ));

    return streaks;
  }

  int _currentStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;

    final uniqueDates = sortedDates.map(_dateOnly).toSet().toList()..sort();
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    // Streak must include today or yesterday to be "current".
    if (uniqueDates.last != today && uniqueDates.last != yesterday) {
      return 0;
    }

    int streak = 1;
    for (int i = uniqueDates.length - 2; i >= 0; i--) {
      final diff = uniqueDates[i + 1].difference(uniqueDates[i]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ── Trend ───────────────────────────────────────────────────────────────

  TrendData _computeOverallTrend({
    required List<Habit> habits,
    required String userId,
  }) {
    final allDates = <DateTime>[];
    DateTime? earliest;
    for (final habit in habits) {
      allDates.addAll(_userCompletions(habit, userId));
      if (earliest == null || habit.createdAt.isBefore(earliest)) {
        earliest = habit.createdAt;
      }
    }
    return _computeTrendForDates(allDates, earliest ?? DateTime.now());
  }

  TrendData _computeTrendForDates(List<DateTime> dates, DateTime since) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final completionSet = dates.map(_dateOnly).toSet();

    // Build daily rates for last 30 days.
    final dailyRates = <DailyCompletion>[];
    for (int i = 29; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final completed = completionSet.contains(day) ? 1.0 : 0.0;
      dailyRates.add(DailyCompletion(date: day, rate: completed));
    }

    // Recent average (last 7 days).
    final recentDays = dailyRates.length >= 7
        ? dailyRates.sublist(dailyRates.length - 7)
        : dailyRates;
    final recentAvg = recentDays.isEmpty
        ? 0.0
        : recentDays.map((d) => d.rate).reduce((a, b) => a + b) /
            recentDays.length;

    // Previous average (7–14 days ago).
    final prevDays = dailyRates.length >= 14
        ? dailyRates.sublist(dailyRates.length - 14, dailyRates.length - 7)
        : <DailyCompletion>[];
    final prevAvg = prevDays.isEmpty
        ? 0.0
        : prevDays.map((d) => d.rate).reduce((a, b) => a + b) /
            prevDays.length;

    final change = prevAvg > 0
        ? ((recentAvg - prevAvg) / prevAvg * 100)
        : (recentAvg > 0 ? 100.0 : 0.0);

    return TrendData(
      recentAverage: recentAvg,
      previousAverage: prevAvg,
      changePercent: change,
      dailyRates: dailyRates,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Extracts the user's completion dates from a habit.
  List<DateTime> _userCompletions(Habit habit, String userId) {
    return habit.completions[userId] ?? const [];
  }

  /// Strips time component from a DateTime.
  static DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }
}
