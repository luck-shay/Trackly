class Habit {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  Map<String, List<DateTime>> completions;
  List<String> participants;
  final int targetDaysPerWeek;

  Habit({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    Map<String, List<DateTime>>? completions,
    List<String>? participants,
    this.targetDaysPerWeek = 7,
  })  : completions = completions ?? {},
        participants = participants ?? [];

  // Calculate current streak based on completion dates for a specific user
  int currentStreakFor(String userId) {
    if (!completions.containsKey(userId) || completions[userId]!.isEmpty) return 0;
    
    int streak = 0;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    List<DateTime> userCompletions = completions[userId]!;
    
    // Sort descending
    List<DateTime> sorted = List.from(userCompletions)
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
      'completions': completions.map((key, value) => MapEntry(key, value.map((d) => d.toIso8601String()).toList())),
      'participants': participants,
      'targetDaysPerWeek': targetDaysPerWeek,
    };
  }

  // Parse from Firestore Map
  factory Habit.fromMap(Map<String, dynamic> map, {String? id}) {
     Map<String, List<DateTime>> parsedCompletions = {};
     if (map['completions'] != null) {
       final rawCompletions = Map<String, dynamic>.from(map['completions']);
       rawCompletions.forEach((key, value) {
         parsedCompletions[key] = (value as List<dynamic>).map((d) => DateTime.parse(d as String)).toList();
       });
     }

    return Habit(
      id: id ?? map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      completions: parsedCompletions,
      participants: List<String>.from(map['participants'] ?? []),
      targetDaysPerWeek: map['targetDaysPerWeek']?.toInt() ?? 7,
    );
  }
}
