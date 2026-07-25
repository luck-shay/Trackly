// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Habit Stack Model
// Data model for habit stacking / chaining habits sequentially.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

/// A habit stack is an ordered list of habits to complete in sequence.
class HabitStack {
  final String id;
  final String userId;
  final String name;
  final List<String> habitIds;
  final DateTime createdAt;

  const HabitStack({
    required this.id,
    required this.userId,
    required this.name,
    required this.habitIds,
    required this.createdAt,
  });

  HabitStack copyWith({
    String? id,
    String? userId,
    String? name,
    List<String>? habitIds,
    DateTime? createdAt,
  }) {
    return HabitStack(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      habitIds: habitIds ?? this.habitIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'habitIds': habitIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HabitStack.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return HabitStack(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      habitIds: List<String>.from(map['habitIds'] ?? const <String>[]),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}
