class Habit {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  List<DateTime> completionDates;
  final int targetDaysPerWeek;

  Habit({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    List<DateTime>? completionDates,
    this.targetDaysPerWeek = 7,
  }) : completionDates = completionDates ?? [];

  // Calculate current streak based on completion dates
  int get currentStreak {
    if (completionDates.isEmpty) return 0;
    
    int streak = 0;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    // Sort descending
    List<DateTime> sorted = List.from(completionDates)
      ..sort((a, b) => b.compareTo(a));
    
    // Normalize to dates only
    List<DateTime> dateOnly = sorted.map((d) => DateTime(d.year, d.month, d.day)).toList();
    
    // If last completion isn't today or yesterday, streak is broken
    if (dateOnly.first.isBefore(today.subtract(const Duration(days: 1)))) {
      return 0;
    }
    
    DateTime expectedDate = dateOnly.first;
    for (var date in dateOnly) {
      if (date.isAtSameMomentAs(expectedDate)) {
        streak++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else {
        break; // Streak broken
      }
    }
    
    return streak;
  }

  // Serialize to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'completionDates': completionDates.map((d) => d.toIso8601String()).toList(),
      'targetDaysPerWeek': targetDaysPerWeek,
    };
  }

  // Parse from Firestore Map
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      completionDates: (map['completionDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d as String))
          .toList() ?? [],
      targetDaysPerWeek: map['targetDaysPerWeek']?.toInt() ?? 7,
    );
  }
}
