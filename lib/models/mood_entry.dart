// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Mood Entry Model
// Data model for daily mood check-ins and journal entries.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

/// Mood level on a 1–5 scale.
enum MoodLevel {
  terrible(1, '😫', 'Terrible'),
  bad(2, '😟', 'Bad'),
  okay(3, '😐', 'Okay'),
  good(4, '😊', 'Good'),
  great(5, '😄', 'Great');

  final int value;
  final String emoji;
  final String label;

  const MoodLevel(this.value, this.emoji, this.label);

  static MoodLevel fromValue(int? value) {
    return switch (value) {
      1 => MoodLevel.terrible,
      2 => MoodLevel.bad,
      3 => MoodLevel.okay,
      4 => MoodLevel.good,
      5 => MoodLevel.great,
      _ => MoodLevel.okay,
    };
  }
}

/// Predefined mood tags for quick selection.
class MoodTag {
  static const String stressed = 'Stressed';
  static const String energized = 'Energized';
  static const String tired = 'Tired';
  static const String focused = 'Focused';
  static const String anxious = 'Anxious';
  static const String calm = 'Calm';
  static const String motivated = 'Motivated';
  static const String grateful = 'Grateful';
  static const String social = 'Social';
  static const String lonely = 'Lonely';

  static const List<String> all = [
    stressed,
    energized,
    tired,
    focused,
    anxious,
    calm,
    motivated,
    grateful,
    social,
    lonely,
  ];
}

/// A single mood/journal entry for a specific date.
class MoodEntry {
  final String id;
  final String userId;
  final DateTime date;
  final MoodLevel moodLevel;
  final String journalText;
  final List<String> tags;
  final DateTime createdAt;

  const MoodEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.moodLevel,
    this.journalText = '',
    this.tags = const <String>[],
    required this.createdAt,
  });

  MoodEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    MoodLevel? moodLevel,
    String? journalText,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      moodLevel: moodLevel ?? this.moodLevel,
      journalText: journalText ?? this.journalText,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Date key in yyyy-MM-dd format for Firestore document IDs.
  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get dateKeyValue => dateKey(date);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'moodLevel': moodLevel.value,
      'journalText': journalText,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return MoodEntry(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      date: parseDate(map['date']) ?? DateTime.now(),
      moodLevel: MoodLevel.fromValue(map['moodLevel'] as int?),
      journalText: map['journalText'] as String? ?? '',
      tags: List<String>.from(map['tags'] ?? const <String>[]),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}
