import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for organizing habits.
enum HabitCategory {
  general('General', 'general'),
  fitness('Fitness', 'fitness'),
  health('Health', 'health'),
  learning('Learning', 'learning'),
  productivity('Productivity', 'productivity'),
  mindfulness('Mindfulness', 'mindfulness'),
  social('Social', 'social'),
  finance('Finance', 'finance'),
  creativity('Creativity', 'creativity');

  final String label;
  final String value;

  const HabitCategory(this.label, this.value);

  static HabitCategory fromValue(String? value) {
    for (final cat in HabitCategory.values) {
      if (cat.value == value) return cat;
    }
    return HabitCategory.general;
  }
}

/// Time-of-day blocks for organizing the daily view.
enum HabitTimeOfDay {
  anytime('Anytime', 'anytime'),
  morning('Morning', 'morning'),
  afternoon('Afternoon', 'afternoon'),
  evening('Evening', 'evening');

  final String label;
  final String value;

  const HabitTimeOfDay(this.label, this.value);

  static HabitTimeOfDay fromValue(String? value) {
    for (final tod in HabitTimeOfDay.values) {
      if (tod.value == value) return tod;
    }
    return HabitTimeOfDay.anytime;
  }
}

enum HabitSpaceType { individual, sharedTask, group }

enum GroupTaskMode { shared, memberDefined }

extension HabitSpaceTypeX on HabitSpaceType {
  String get value => switch (this) {
    HabitSpaceType.individual => 'individual',
    HabitSpaceType.sharedTask => 'sharedTask',
    HabitSpaceType.group => 'group',
  };

  String get label => switch (this) {
    HabitSpaceType.individual => 'Individual',
    HabitSpaceType.sharedTask => 'Shared task',
    HabitSpaceType.group => 'Group',
  };

  static HabitSpaceType fromValue(String? value) {
    return switch (value) {
      'individual' => HabitSpaceType.individual,
      'group' => HabitSpaceType.group,
      _ => HabitSpaceType.sharedTask,
    };
  }
}

extension GroupTaskModeX on GroupTaskMode {
  String get value => switch (this) {
    GroupTaskMode.shared => 'shared',
    GroupTaskMode.memberDefined => 'memberDefined',
  };

  String get label => switch (this) {
    GroupTaskMode.shared => 'Single shared task',
    GroupTaskMode.memberDefined => 'Members add own tasks',
  };

  static GroupTaskMode fromValue(String? value) {
    return switch (value) {
      'memberDefined' => GroupTaskMode.memberDefined,
      _ => GroupTaskMode.shared,
    };
  }
}

class HabitChecklistItem {
  final String id;
  final String title;
  final bool isCompleted;

  const HabitChecklistItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  HabitChecklistItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return HabitChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory HabitChecklistItem.fromMap(Map<String, dynamic> map) {
    return HabitChecklistItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}

class Habit {
  static const List<int> weekdaysMondayFirst = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  final String id;
  final String? groupEntityId;
  final String title;
  final String description;
  final DateTime createdAt;
  Map<String, List<DateTime>> completions;
  Map<String, Map<String, double>> quantifiedValues;
  List<String> participants;
  final int targetDaysPerWeek;
  final HabitSpaceType spaceType;
  final String? groupName;
  final bool isQuantified;
  final String quantUnit;
  final double quantMin;
  final double quantMax;
  final GroupTaskMode groupTaskMode;
  Map<String, String> memberTasks;
  Map<String, bool> memberIsQuantified;
  Map<String, String> memberQuantUnits;
  Map<String, double> memberQuantMax;
  final bool requiresPhotoValidation;
  final String? reminderTime; // HH:mm format
  final List<int> reminderWeekdays;
  final HabitCategory category;
  final HabitTimeOfDay timeOfDay;
  final int? colorValue; // Color as int (Color.value)
  final int? iconCodePoint; // IconData.codePoint
  final int sortOrder;
  final List<HabitChecklistItem> checklist;

  Habit({
    required this.id,
    this.groupEntityId,
    required this.title,
    this.description = '',
    required this.createdAt,
    Map<String, List<DateTime>>? completions,
    Map<String, Map<String, double>>? quantifiedValues,
    List<String>? participants,
    this.targetDaysPerWeek = 7,
    this.spaceType = HabitSpaceType.sharedTask,
    this.groupName,
    this.isQuantified = false,
    this.quantUnit = 'units',
    this.quantMin = 0,
    this.quantMax = 10,
    this.groupTaskMode = GroupTaskMode.shared,
    Map<String, String>? memberTasks,
    Map<String, bool>? memberIsQuantified,
    Map<String, String>? memberQuantUnits,
    Map<String, double>? memberQuantMax,
    this.requiresPhotoValidation = false,
    this.reminderTime,
    List<int>? reminderWeekdays,
    this.category = HabitCategory.general,
    this.timeOfDay = HabitTimeOfDay.anytime,
    this.colorValue,
    this.iconCodePoint,
    this.sortOrder = 0,
    this.checklist = const [],
  }) : completions = completions ?? {},
       quantifiedValues = quantifiedValues ?? {},
       participants = participants ?? [],
       memberTasks = memberTasks ?? {},
       memberIsQuantified = memberIsQuantified ?? {},
       memberQuantUnits = memberQuantUnits ?? {},
       memberQuantMax = memberQuantMax ?? {},
       reminderWeekdays = _normalizeReminderWeekdays(
         reminderWeekdays,
         targetDaysPerWeek,
       );

  Habit copyWith({
    String? id,
    String? groupEntityId,
    String? title,
    String? description,
    DateTime? createdAt,
    Map<String, List<DateTime>>? completions,
    Map<String, Map<String, double>>? quantifiedValues,
    List<String>? participants,
    int? targetDaysPerWeek,
    HabitSpaceType? spaceType,
    String? groupName,
    bool? isQuantified,
    String? quantUnit,
    double? quantMin,
    double? quantMax,
    GroupTaskMode? groupTaskMode,
    Map<String, String>? memberTasks,
    Map<String, bool>? memberIsQuantified,
    Map<String, String>? memberQuantUnits,
    Map<String, double>? memberQuantMax,
    bool? requiresPhotoValidation,
    String? reminderTime,
    List<int>? reminderWeekdays,
    HabitCategory? category,
    HabitTimeOfDay? timeOfDay,
    int? colorValue,
    int? iconCodePoint,
    int? sortOrder,
    List<HabitChecklistItem>? checklist,
  }) {
    return Habit(
      id: id ?? this.id,
      groupEntityId: groupEntityId ?? this.groupEntityId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      completions: completions ?? this.completions,
      quantifiedValues: quantifiedValues ?? this.quantifiedValues,
      participants: participants ?? this.participants,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      spaceType: spaceType ?? this.spaceType,
      groupName: groupName ?? this.groupName,
      isQuantified: isQuantified ?? this.isQuantified,
      quantUnit: quantUnit ?? this.quantUnit,
      quantMin: quantMin ?? this.quantMin,
      quantMax: quantMax ?? this.quantMax,
      groupTaskMode: groupTaskMode ?? this.groupTaskMode,
      memberTasks: memberTasks ?? this.memberTasks,
      memberIsQuantified: memberIsQuantified ?? this.memberIsQuantified,
      memberQuantUnits: memberQuantUnits ?? this.memberQuantUnits,
      memberQuantMax: memberQuantMax ?? this.memberQuantMax,
      requiresPhotoValidation:
          requiresPhotoValidation ?? this.requiresPhotoValidation,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderWeekdays: reminderWeekdays ?? this.reminderWeekdays,
      category: category ?? this.category,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      sortOrder: sortOrder ?? this.sortOrder,
      checklist: checklist ?? this.checklist,
    );
  }

  bool get isGroup => spaceType == HabitSpaceType.group;

  String get displayTitle {
    if (isGroup && (groupName ?? '').trim().isNotEmpty) {
      return groupName!.trim();
    }
    return title;
  }

  bool get hasMemberDefinedGroupTasks {
    return isGroup && groupTaskMode == GroupTaskMode.memberDefined;
  }

  bool get isDailyTarget => targetDaysPerWeek >= 7;

  List<int> get effectiveReminderWeekdays {
    if ((reminderTime ?? '').trim().isEmpty) {
      return const <int>[];
    }
    return _normalizeReminderWeekdays(reminderWeekdays, targetDaysPerWeek);
  }

  String taskFor(String userId) {
    if (!hasMemberDefinedGroupTasks) {
      return title;
    }

    return memberTasks[userId]?.trim() ?? '';
  }

  bool isQuantifiedFor(String userId) {
    if (!hasMemberDefinedGroupTasks) {
      return isQuantified;
    }
    return memberIsQuantified[userId] ?? isQuantified;
  }

  String quantUnitFor(String userId) {
    if (!hasMemberDefinedGroupTasks) {
      return quantUnit;
    }
    final unit = memberQuantUnits[userId]?.trim();
    if (unit == null || unit.isEmpty) {
      return quantUnit;
    }
    return unit;
  }

  double quantMinFor(String userId) {
    if (!hasMemberDefinedGroupTasks) {
      return quantMin;
    }
    return 0;
  }

  double quantMaxFor(String userId) {
    if (!hasMemberDefinedGroupTasks) {
      return quantMax;
    }
    return memberQuantMax[userId] ?? quantMax;
  }

  String get dateKeyFormat => 'yyyy-mm-dd';

  String dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  double? completionValueFor(String userId, DateTime date) {
    final userValues = quantifiedValues[userId];
    if (userValues == null) {
      return null;
    }
    return userValues[dateKeyFor(date)];
  }

  bool isCompletedOnDate(String userId, DateTime date) {
    final userCompletions = completions[userId] ?? const <DateTime>[];
    return userCompletions.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
  }

  int weeklyCompletionCountFor(String userId, {DateTime? anchor}) {
    final weekStart = _weekStartFor(anchor ?? DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 7));
    final seen = <String>{};

    for (final date in completions[userId] ?? const <DateTime>[]) {
      final normalized = _dateOnly(date);
      if (normalized.isBefore(weekStart) || !normalized.isBefore(weekEnd)) {
        continue;
      }
      seen.add(dateKeyFor(normalized));
    }

    return seen.length;
  }

  double weeklyTargetProgressFor(String userId, {DateTime? anchor}) {
    final count = weeklyCompletionCountFor(userId, anchor: anchor);
    final target = targetDaysPerWeek.clamp(1, 7);
    return (count / target).clamp(0, 1);
  }

  bool hasMetWeeklyTarget(String userId, {DateTime? anchor}) {
    return weeklyCompletionCountFor(userId, anchor: anchor) >=
        targetDaysPerWeek.clamp(1, 7);
  }

  double completionProgressFor(String userId, DateTime date) {
    if (!isQuantifiedFor(userId)) {
      return isCompletedOnDate(userId, date) ? 1 : 0;
    }

    final value = completionValueFor(userId, date) ?? 0;
    final userQuantMax = quantMaxFor(userId);
    if (userQuantMax <= 0) {
      return 0;
    }

    return (value / userQuantMax).clamp(0, 1);
  }

  // Calculate current streak based on completion dates for a specific user
  int currentStreakFor(String userId) {
    if (!isDailyTarget) {
      return _currentWeeklyTargetStreakFor(userId);
    }

    return _currentDailyStreakFor(userId);
  }

  int _currentDailyStreakFor(String userId) {
    if (!completions.containsKey(userId) || completions[userId]!.isEmpty) {
      return 0;
    }

    int streak = 0;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    List<DateTime> userCompletions = completions[userId]!;

    // Sort descending
    List<DateTime> sorted = List.from(userCompletions)
      ..sort((a, b) => b.compareTo(a));

    // Normalize to dates only
    List<DateTime> dateOnly = sorted
        .map((d) => DateTime(d.year, d.month, d.day))
        .toList();

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

  int _currentWeeklyTargetStreakFor(String userId) {
    final dates = completions[userId] ?? const <DateTime>[];
    if (dates.isEmpty) {
      return 0;
    }

    final today = DateTime.now();
    var weekAnchor = _weekStartFor(today);
    var streak = 0;

    if (!hasMetWeeklyTarget(userId, anchor: weekAnchor)) {
      weekAnchor = weekAnchor.subtract(const Duration(days: 7));
    }

    while (hasMetWeeklyTarget(userId, anchor: weekAnchor)) {
      streak++;
      weekAnchor = weekAnchor.subtract(const Duration(days: 7));
    }

    return streak;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _weekStartFor(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static List<int> _normalizeReminderWeekdays(
    List<int>? reminderWeekdays,
    int targetDaysPerWeek,
  ) {
    final target = targetDaysPerWeek.clamp(1, 7);
    if (target >= 7) {
      return List<int>.from(weekdaysMondayFirst);
    }

    final normalized = <int>[];
    for (final day in reminderWeekdays ?? const <int>[]) {
      if (weekdaysMondayFirst.contains(day) && !normalized.contains(day)) {
        normalized.add(day);
      }
    }

    normalized.sort();

    final result = <int>[...normalized];
    for (final day in weekdaysMondayFirst) {
      if (result.length >= target) {
        break;
      }
      if (!result.contains(day)) {
        result.add(day);
      }
    }

    result.sort();
    return result.take(target).toList(growable: false);
  }

  // Serialize to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupEntityId': groupEntityId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'completions': completions.map(
        (key, value) =>
            MapEntry(key, value.map((d) => d.toIso8601String()).toList()),
      ),
      'quantifiedValues': quantifiedValues,
      'participants': participants,
      'targetDaysPerWeek': targetDaysPerWeek,
      'spaceType': spaceType.value,
      'groupName': groupName,
      'isQuantified': isQuantified,
      'quantUnit': quantUnit,
      'quantMin': quantMin,
      'quantMax': quantMax,
      'groupTaskMode': groupTaskMode.value,
      'memberTasks': memberTasks,
      'memberIsQuantified': memberIsQuantified,
      'memberQuantUnits': memberQuantUnits,
      'memberQuantMax': memberQuantMax,
      'requiresPhotoValidation': requiresPhotoValidation,
      'reminderTime': reminderTime,
      'reminderWeekdays': reminderWeekdays,
      'category': category.value,
      'timeOfDay': timeOfDay.value,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'sortOrder': sortOrder,
      'checklist': checklist.map((item) => item.toMap()).toList(),
    };
  }

  // Parse from Firestore Map
  factory Habit.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) {
        return raw;
      }
      if (raw is Timestamp) {
        return raw.toDate();
      }
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    Map<String, List<DateTime>> parsedCompletions = {};
    final rawCompletionsAny = map['completions'];
    if (rawCompletionsAny is Map) {
      final rawCompletions = Map<String, dynamic>.from(rawCompletionsAny);
      rawCompletions.forEach((key, value) {
        if (value is List) {
          parsedCompletions[key] = value
              .map(parseDate)
              .whereType<DateTime>()
              .toList();
        }
      });
    }

    Map<String, Map<String, double>> parsedQuantifiedValues = {};
    final rawValuesAny = map['quantifiedValues'];
    if (rawValuesAny is Map) {
      final rawValues = Map<String, dynamic>.from(rawValuesAny);
      rawValues.forEach((userId, valueByDate) {
        if (valueByDate is! Map) {
          return;
        }
        final normalized = <String, double>{};
        final dateMap = Map<String, dynamic>.from(valueByDate);
        dateMap.forEach((dateKey, value) {
          if (value is num) {
            normalized[dateKey] = value.toDouble();
          }
        });
        parsedQuantifiedValues[userId] = normalized;
      });
    }

    final parsedMemberTasks = <String, String>{};
    final rawTasksAny = map['memberTasks'];
    if (rawTasksAny is Map) {
      final rawTasks = Map<String, dynamic>.from(rawTasksAny);
      rawTasks.forEach((userId, task) {
        parsedMemberTasks[userId] = task.toString();
      });
    }

    final parsedMemberIsQuantified = <String, bool>{};
    final rawMemberIsQuantifiedAny = map['memberIsQuantified'];
    if (rawMemberIsQuantifiedAny is Map) {
      final rawMap = Map<String, dynamic>.from(rawMemberIsQuantifiedAny);
      rawMap.forEach((userId, value) {
        parsedMemberIsQuantified[userId] = value == true;
      });
    }

    final parsedMemberQuantUnits = <String, String>{};
    final rawMemberQuantUnitsAny = map['memberQuantUnits'];
    if (rawMemberQuantUnitsAny is Map) {
      final rawMap = Map<String, dynamic>.from(rawMemberQuantUnitsAny);
      rawMap.forEach((userId, value) {
        parsedMemberQuantUnits[userId] = value.toString();
      });
    }

    final parsedMemberQuantMax = <String, double>{};
    final rawMemberQuantMaxAny = map['memberQuantMax'];
    if (rawMemberQuantMaxAny is Map) {
      final rawMap = Map<String, dynamic>.from(rawMemberQuantMaxAny);
      rawMap.forEach((userId, value) {
        if (value is num) {
          parsedMemberQuantMax[userId] = value.toDouble();
        }
      });
    }

    final parsedReminderWeekdays = <int>[];
    final rawReminderWeekdays = map['reminderWeekdays'];
    if (rawReminderWeekdays is List) {
      for (final value in rawReminderWeekdays) {
        final weekday = (value as num?)?.toInt();
        if (weekday != null &&
            weekdaysMondayFirst.contains(weekday) &&
            !parsedReminderWeekdays.contains(weekday)) {
          parsedReminderWeekdays.add(weekday);
        }
      }
    }

    final parsedChecklist = <HabitChecklistItem>[];
    final rawChecklist = map['checklist'];
    if (rawChecklist is List) {
      for (final item in rawChecklist) {
        if (item is Map) {
          parsedChecklist.add(
            HabitChecklistItem.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return Habit(
      id: id ?? map['id'] ?? '',
      groupEntityId: map['groupEntityId'] as String?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      completions: parsedCompletions,
      quantifiedValues: parsedQuantifiedValues,
      participants: List<String>.from(map['participants'] ?? []),
      targetDaysPerWeek: map['targetDaysPerWeek']?.toInt() ?? 7,
      spaceType: HabitSpaceTypeX.fromValue(map['spaceType'] as String?),
      groupName: map['groupName'] as String?,
      isQuantified: map['isQuantified'] as bool? ?? false,
      quantUnit: map['quantUnit'] as String? ?? 'units',
      quantMin: (map['quantMin'] as num?)?.toDouble() ?? 0,
      quantMax: (map['quantMax'] as num?)?.toDouble() ?? 10,
      groupTaskMode: GroupTaskModeX.fromValue(map['groupTaskMode'] as String?),
      memberTasks: parsedMemberTasks,
      memberIsQuantified: parsedMemberIsQuantified,
      memberQuantUnits: parsedMemberQuantUnits,
      memberQuantMax: parsedMemberQuantMax,
      requiresPhotoValidation: map['requiresPhotoValidation'] ?? false,
      reminderTime: map['reminderTime'] as String?,
      reminderWeekdays: parsedReminderWeekdays,
      category: HabitCategory.fromValue(map['category'] as String?),
      timeOfDay: HabitTimeOfDay.fromValue(map['timeOfDay'] as String?),
      colorValue: (map['colorValue'] as num?)?.toInt(),
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt(),
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      checklist: parsedChecklist,
    );
  }
}
