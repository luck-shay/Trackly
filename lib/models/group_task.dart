import 'package:cloud_firestore/cloud_firestore.dart';

class GroupTask {
  final String id;
  final String groupId;
  final String title;
  final String description;
  final DateTime createdAt;
  final String createdBy;
  final List<String> assigneeIds;
  final bool isQuantified;
  final String quantUnit;
  final double quantMax;
  final Map<String, List<DateTime>> completions;
  final Map<String, Map<String, double>> quantifiedValues;

  const GroupTask({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.assigneeIds,
    required this.isQuantified,
    required this.quantUnit,
    required this.quantMax,
    required this.completions,
    required this.quantifiedValues,
  });

  GroupTask copyWith({
    String? id,
    String? groupId,
    String? title,
    String? description,
    DateTime? createdAt,
    String? createdBy,
    List<String>? assigneeIds,
    bool? isQuantified,
    String? quantUnit,
    double? quantMax,
    Map<String, List<DateTime>>? completions,
    Map<String, Map<String, double>>? quantifiedValues,
  }) {
    return GroupTask(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      isQuantified: isQuantified ?? this.isQuantified,
      quantUnit: quantUnit ?? this.quantUnit,
      quantMax: quantMax ?? this.quantMax,
      completions: completions ?? this.completions,
      quantifiedValues: quantifiedValues ?? this.quantifiedValues,
    );
  }

  String dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  bool isCompletedOnDate(String userId, DateTime date) {
    final items = completions[userId] ?? const <DateTime>[];
    return items.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
  }

  double? completionValueFor(String userId, DateTime date) {
    final userValues = quantifiedValues[userId];
    if (userValues == null) {
      return null;
    }
    return userValues[dateKeyFor(date)];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'assigneeIds': assigneeIds,
      'isQuantified': isQuantified,
      'quantUnit': quantUnit,
      'quantMax': quantMax,
      'completions': completions.map(
        (key, value) =>
            MapEntry(key, value.map((date) => date.toIso8601String()).toList()),
      ),
      'quantifiedValues': quantifiedValues,
    };
  }

  factory GroupTask.fromMap(Map<String, dynamic> map, {String? id}) {
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

    final parsedCompletions = <String, List<DateTime>>{};
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

    final parsedQuantifiedValues = <String, Map<String, double>>{};
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

    return GroupTask(
      id: id ?? (map['id'] as String? ?? ''),
      groupId: (map['groupId'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
      description: (map['description'] as String? ?? '').trim(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      createdBy: (map['createdBy'] as String? ?? '').trim(),
      assigneeIds: List<String>.from(map['assigneeIds'] ?? const <String>[]),
      isQuantified: map['isQuantified'] as bool? ?? false,
      quantUnit: (map['quantUnit'] as String? ?? 'units').trim(),
      quantMax: (map['quantMax'] as num?)?.toDouble() ?? 10,
      completions: parsedCompletions,
      quantifiedValues: parsedQuantifiedValues,
    );
  }
}
