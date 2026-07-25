// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Mood Service
// Firestore + Local SharedPreferences persistence for mood entries and correlation analysis.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_entry.dart';
import '../models/habit.dart';

class MoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _localKey(String userId, String dateKey) => 'mood_entry_${userId}_$dateKey';

  /// Firestore path for mood entries: users/{uid}/moods/{dateKey}
  CollectionReference<Map<String, dynamic>> _moodsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('moods');
  }

  /// Save or update a mood entry for a specific date (local-first + Firestore sync).
  Future<void> saveMood(MoodEntry entry) async {
    // 1. Save locally to SharedPreferences first (ensures instant & resilient save)
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localKey(entry.userId, entry.dateKeyValue);
      await prefs.setString(key, jsonEncode(entry.toMap()));
    } catch (e) {
      if (kDebugMode) debugPrint('MoodService: SharedPreferences write warning: $e');
    }

    // 2. Sync to Firestore (catch permission/network errors gracefully)
    if (entry.userId.isNotEmpty) {
      try {
        await _moodsCollection(entry.userId)
            .doc(entry.dateKeyValue)
            .set(entry.toMap());
      } catch (e) {
        if (kDebugMode) {
          debugPrint('MoodService: Firestore sync notice (saved locally): $e');
        }
      }
    }
  }

  /// Get the mood entry for a specific date (combines local cache + Firestore).
  Future<MoodEntry?> getMoodForDate(String userId, DateTime date) async {
    final key = MoodEntry.dateKey(date);

    // Try Firestore first
    if (userId.isNotEmpty) {
      try {
        final doc = await _moodsCollection(userId).doc(key).get();
        if (doc.exists && doc.data() != null) {
          return MoodEntry.fromMap(doc.data()!, id: doc.id);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('MoodService: Firestore get notice: $e');
      }
    }

    // Fallback to local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_localKey(userId, key));
      if (rawJson != null && rawJson.isNotEmpty) {
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        return MoodEntry.fromMap(map, id: key);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MoodService: Local read warning: $e');
    }

    return null;
  }

  /// Get all mood entries in a date range (inclusive).
  Future<List<MoodEntry>> getMoodsInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final entries = <String, MoodEntry>{};

    // Load from local storage for each date in range
    try {
      final prefs = await SharedPreferences.getInstance();
      var current = start;
      while (!current.isAfter(end)) {
        final dateKey = MoodEntry.dateKey(current);
        final rawJson = prefs.getString(_localKey(userId, dateKey));
        if (rawJson != null && rawJson.isNotEmpty) {
          final map = jsonDecode(rawJson) as Map<String, dynamic>;
          entries[dateKey] = MoodEntry.fromMap(map, id: dateKey);
        }
        current = current.add(const Duration(days: 1));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MoodService: Range local read warning: $e');
    }

    // Attempt to merge from Firestore if signed in
    if (userId.isNotEmpty) {
      try {
        final startKey = MoodEntry.dateKey(start);
        final endKey = MoodEntry.dateKey(end);
        final snapshot = await _moodsCollection(userId)
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
            .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
            .orderBy(FieldPath.documentId)
            .get();

        for (final doc in snapshot.docs) {
          final entry = MoodEntry.fromMap(doc.data(), id: doc.id);
          entries[entry.dateKeyValue] = entry;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('MoodService: Range Firestore read notice: $e');
      }
    }

    final result = entries.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  /// Get recent mood entries (last N days).
  Future<List<MoodEntry>> getRecentMoods(String userId, {int days = 30}) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    return getMoodsInRange(userId, start, end);
  }

  /// Delete a mood entry for a specific date.
  Future<void> deleteMood(String userId, DateTime date) async {
    final key = MoodEntry.dateKey(date);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey(userId, key));
    } catch (_) {}

    if (userId.isNotEmpty) {
      try {
        await _moodsCollection(userId).doc(key).delete();
      } catch (_) {}
    }
  }

  /// Listen to mood entries in real time for a date range.
  Stream<List<MoodEntry>> watchMoodsInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    if (userId.isEmpty) {
      return Stream.fromFuture(getMoodsInRange(userId, start, end));
    }

    final startKey = MoodEntry.dateKey(start);
    final endKey = MoodEntry.dateKey(end);

    return _moodsCollection(userId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MoodEntry.fromMap(doc.data(), id: doc.id);
      }).toList();
    }).handleError((error) {
      if (kDebugMode) debugPrint('MoodService: Stream notice: $error');
      return <MoodEntry>[];
    });
  }

  // ── Mood-Habit Correlation ──────────────────────────────────────────────

  /// Compute mood-habit correlation data.
  /// Returns a map of mood level → average completion rate.
  MoodCorrelation computeCorrelation({
    required List<MoodEntry> moods,
    required List<Habit> habits,
    required String userId,
  }) {
    if (moods.isEmpty || habits.isEmpty) {
      return const MoodCorrelation(
        moodCompletionRates: {},
        averageMood: 0,
        moodTrend: 0,
        totalEntries: 0,
      );
    }

    // Group mood entries by date
    final moodByDate = <String, MoodEntry>{};
    for (final mood in moods) {
      moodByDate[mood.dateKeyValue] = mood;
    }

    // Calculate completion rate per mood level
    final completionsByMood = <int, List<double>>{};
    final moodValues = <double>[];

    for (final entry in moods) {
      moodValues.add(entry.moodLevel.value.toDouble());

      // Calculate completion rate for this day
      int completed = 0;
      int total = 0;
      for (final habit in habits) {
        if (habit.spaceType == HabitSpaceType.individual ||
            habit.participants.contains(userId)) {
          total++;
          if (habit.isCompletedOnDate(userId, entry.date)) {
            completed++;
          }
        }
      }

      if (total > 0) {
        final rate = completed / total;
        completionsByMood
            .putIfAbsent(entry.moodLevel.value, () => [])
            .add(rate);
      }
    }

    // Average completion rate per mood level
    final moodCompletionRates = <int, double>{};
    for (final entry in completionsByMood.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      moodCompletionRates[entry.key] = avg;
    }

    // Compute average mood
    final avgMood = moodValues.isEmpty
        ? 0.0
        : moodValues.reduce((a, b) => a + b) / moodValues.length;

    // Compute mood trend (simple: compare last 7 vs previous 7)
    double moodTrend = 0;
    if (moodValues.length >= 14) {
      final recent = moodValues.sublist(moodValues.length - 7);
      final previous =
          moodValues.sublist(moodValues.length - 14, moodValues.length - 7);
      final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
      final prevAvg = previous.reduce((a, b) => a + b) / previous.length;
      moodTrend = recentAvg - prevAvg;
    }

    return MoodCorrelation(
      moodCompletionRates: moodCompletionRates,
      averageMood: avgMood,
      moodTrend: moodTrend,
      totalEntries: moods.length,
    );
  }
}

/// Aggregated mood-habit correlation data.
class MoodCorrelation {
  /// Average completion rate per mood level (1-5).
  final Map<int, double> moodCompletionRates;

  /// Overall average mood score.
  final double averageMood;

  /// Mood trend: positive = improving, negative = declining.
  final double moodTrend;

  /// Total mood entries analyzed.
  final int totalEntries;

  const MoodCorrelation({
    required this.moodCompletionRates,
    required this.averageMood,
    required this.moodTrend,
    required this.totalEntries,
  });
}
