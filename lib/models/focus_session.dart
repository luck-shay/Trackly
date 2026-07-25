// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Focus Session Model
// Data model for focus timer sessions linked to habits.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of focus session.
enum FocusSessionType {
  pomodoro('Pomodoro'),
  freeform('Freeform'),
  timed('Timed');

  final String label;

  const FocusSessionType(this.label);

  static FocusSessionType fromValue(String? value) {
    return switch (value) {
      'pomodoro' => FocusSessionType.pomodoro,
      'freeform' => FocusSessionType.freeform,
      'timed' => FocusSessionType.timed,
      _ => FocusSessionType.freeform,
    };
  }
}

/// A completed focus session record.
class FocusSession {
  final String id;
  final String userId;
  final String? habitId;
  final String? habitTitle;
  final FocusSessionType type;
  final int durationSeconds;
  final DateTime completedAt;

  const FocusSession({
    required this.id,
    required this.userId,
    this.habitId,
    this.habitTitle,
    required this.type,
    required this.durationSeconds,
    required this.completedAt,
  });

  /// Duration formatted as "Xh Ym" or "Ym Zs".
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'habitId': habitId,
      'habitTitle': habitTitle,
      'type': type.name,
      'durationSeconds': durationSeconds,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return FocusSession(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      habitId: map['habitId'] as String?,
      habitTitle: map['habitTitle'] as String?,
      type: FocusSessionType.fromValue(map['type'] as String?),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      completedAt: parseDate(map['completedAt']) ?? DateTime.now(),
    );
  }
}
