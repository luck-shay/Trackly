import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChallenge {
  final String id;
  final String groupId;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> participantIds;
  final String unit;
  final double targetValue;
  final Map<String, Map<String, double>> progressLogs;

  const GroupChallenge({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.startAt,
    required this.endAt,
    required this.participantIds,
    required this.unit,
    required this.targetValue,
    required this.progressLogs,
  });

  GroupChallenge copyWith({
    String? id,
    String? groupId,
    String? title,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? startAt,
    DateTime? endAt,
    List<String>? participantIds,
    String? unit,
    double? targetValue,
    Map<String, Map<String, double>>? progressLogs,
  }) {
    return GroupChallenge(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      participantIds: participantIds ?? this.participantIds,
      unit: unit ?? this.unit,
      targetValue: targetValue ?? this.targetValue,
      progressLogs: progressLogs ?? this.progressLogs,
    );
  }

  bool get hasStarted => !DateTime.now().isBefore(startAt);
  bool get hasEnded => DateTime.now().isAfter(endAt);
  bool get isReadyToStart => participantIds.length >= 2;
  bool get isActive => isReadyToStart && hasStarted && !hasEnded;
  bool get hasTarget => unit.trim().isNotEmpty;

  String dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  double valueForUserOnDate(String userId, DateTime date) {
    final userLogs = progressLogs[userId];
    if (userLogs == null) {
      return 0;
    }
    return userLogs[dateKeyFor(date)] ?? 0;
  }

  double totalForUser(String userId) {
    final userLogs = progressLogs[userId];
    if (userLogs == null) {
      return 0;
    }
    return userLogs.values.fold<double>(0, (sum, value) => sum + value);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'participantIds': participantIds,
      'unit': unit,
      'targetValue': targetValue,
      'progressLogs': progressLogs,
    };
  }

  factory GroupChallenge.fromMap(Map<String, dynamic> map, {String? id}) {
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

    final parsedLogs = <String, Map<String, double>>{};
    final rawLogsAny = map['progressLogs'];
    if (rawLogsAny is Map) {
      final rawLogs = Map<String, dynamic>.from(rawLogsAny);
      rawLogs.forEach((uid, dayMapRaw) {
        if (dayMapRaw is! Map) {
          return;
        }
        final normalized = <String, double>{};
        final dayMap = Map<String, dynamic>.from(dayMapRaw);
        dayMap.forEach((dayKey, value) {
          if (value is num) {
            normalized[dayKey] = value.toDouble();
          }
        });
        parsedLogs[uid] = normalized;
      });
    }

    return GroupChallenge(
      id: id ?? (map['id'] as String? ?? ''),
      groupId: (map['groupId'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
      description: (map['description'] as String? ?? '').trim(),
      createdBy: (map['createdBy'] as String? ?? '').trim(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      startAt: parseDate(map['startAt']) ?? DateTime.now(),
      endAt: parseDate(map['endAt']) ?? DateTime.now(),
      participantIds: List<String>.from(
        map['participantIds'] ?? const <String>[],
      ),
      unit: (map['unit'] as String? ?? '').trim(),
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      progressLogs: parsedLogs,
    );
  }
}
