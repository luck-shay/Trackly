// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Analytics Data Models
// Structured data models for all analytics computations.
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregated analytics across all of a user's habits.
class OverallAnalytics {
  final int totalHabits;
  final int totalCompletions;
  final double overallCompletionRate;
  final int currentLongestStreak;
  final int allTimeLongestStreak;
  final WeekdayPerformance weekdayPerformance;
  final Map<DateTime, int> heatmapData;
  final List<HabitAnalytics> perHabitAnalytics;
  final TrendData trend;
  final int activeDays;
  final int totalTrackedDays;

  const OverallAnalytics({
    required this.totalHabits,
    required this.totalCompletions,
    required this.overallCompletionRate,
    required this.currentLongestStreak,
    required this.allTimeLongestStreak,
    required this.weekdayPerformance,
    required this.heatmapData,
    required this.perHabitAnalytics,
    required this.trend,
    required this.activeDays,
    required this.totalTrackedDays,
  });

  static const OverallAnalytics empty = OverallAnalytics(
    totalHabits: 0,
    totalCompletions: 0,
    overallCompletionRate: 0,
    currentLongestStreak: 0,
    allTimeLongestStreak: 0,
    weekdayPerformance: WeekdayPerformance.empty,
    heatmapData: {},
    perHabitAnalytics: [],
    trend: TrendData.empty,
    activeDays: 0,
    totalTrackedDays: 0,
  );
}

/// Analytics for a single habit.
class HabitAnalytics {
  final String habitId;
  final String habitTitle;
  final int totalCompletions;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final List<StreakRecord> streakHistory;
  final WeekdayPerformance weekdayPerformance;
  final TrendData trend;
  final int targetDaysPerWeek;

  const HabitAnalytics({
    required this.habitId,
    required this.habitTitle,
    required this.totalCompletions,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.streakHistory,
    required this.weekdayPerformance,
    required this.trend,
    required this.targetDaysPerWeek,
  });
}

/// Completion rates broken down by weekday (Monday = 1, Sunday = 7).
class WeekdayPerformance {
  /// Completion rate for each weekday. Key is weekday (1–7), value is 0.0–1.0.
  final Map<int, double> rates;

  /// The weekday with the highest completion rate.
  final int bestDay;

  /// The weekday with the lowest completion rate.
  final int worstDay;

  const WeekdayPerformance({
    required this.rates,
    required this.bestDay,
    required this.worstDay,
  });

  static const WeekdayPerformance empty = WeekdayPerformance(
    rates: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0},
    bestDay: 1,
    worstDay: 7,
  );

  static const List<String> dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const List<String> dayNamesFull = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Full day name for the given weekday (1 = Monday).
  String dayName(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return dayNamesFull[weekday - 1];
  }
}

/// A record of a continuous streak.
class StreakRecord {
  final DateTime startDate;
  final DateTime endDate;
  final int length;

  const StreakRecord({
    required this.startDate,
    required this.endDate,
    required this.length,
  });
}

/// Trend data showing whether completion rates are improving or declining.
class TrendData {
  /// Recent period average (last 7 days).
  final double recentAverage;

  /// Previous period average (7–14 days ago).
  final double previousAverage;

  /// Change percentage: positive means improving, negative means declining.
  final double changePercent;

  /// Rolling daily completion rates for graphing (last 30 entries).
  final List<DailyCompletion> dailyRates;

  const TrendData({
    required this.recentAverage,
    required this.previousAverage,
    required this.changePercent,
    required this.dailyRates,
  });

  static const TrendData empty = TrendData(
    recentAverage: 0,
    previousAverage: 0,
    changePercent: 0,
    dailyRates: [],
  );

  bool get isImproving => changePercent > 0;
  bool get isDeclining => changePercent < 0;
  bool get isStable => changePercent == 0;
}

/// A single day's completion rate for trend graphing.
class DailyCompletion {
  final DateTime date;
  final double rate;

  const DailyCompletion({required this.date, required this.rate});
}
