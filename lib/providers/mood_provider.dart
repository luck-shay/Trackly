// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Mood Provider
// Reactive state management for mood tracking and journal entries.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mood_entry.dart';
import '../models/habit.dart';
import '../services/mood_service.dart';

class MoodProvider extends ChangeNotifier {
  final MoodService _moodService = MoodService();
  String _userId = '';

  MoodEntry? _todaysMood;
  List<MoodEntry> _recentMoods = [];
  MoodCorrelation? _correlation;
  bool _isLoading = false;
  StreamSubscription<List<MoodEntry>>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  MoodProvider({String? userId}) {
    _userId = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    _init();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid ?? '';
      if (_userId != newUid) {
        _userId = newUid;
        _init();
      }
    });
  }

  String get userId => _userId;

  MoodEntry? get todaysMood => _todaysMood;
  List<MoodEntry> get recentMoods => _recentMoods;
  MoodCorrelation? get correlation => _correlation;
  bool get isLoading => _isLoading;
  bool get hasTodaysMood => _todaysMood != null;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Load today's mood
    final today = DateTime.now();
    _todaysMood = await _moodService.getMoodForDate(_userId, today);

    // Load recent moods (last 30 days)
    _recentMoods = await _moodService.getRecentMoods(_userId, days: 30);

    // Subscribe to real-time updates for current month
    final start = DateTime(today.year, today.month - 1, 1);
    _subscription = _moodService
        .watchMoodsInRange(_userId, start, today)
        .listen((moods) {
      _recentMoods = moods;
      // Update today's mood from stream
      final todayKey = MoodEntry.dateKey(today);
      _todaysMood = moods.where((m) => m.dateKeyValue == todayKey).firstOrNull;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  /// Save a mood entry.
  Future<void> saveMood(MoodEntry entry) async {
    await _moodService.saveMood(entry);
    final today = DateTime.now();
    if (entry.dateKeyValue == MoodEntry.dateKey(today)) {
      _todaysMood = entry;
    }
    notifyListeners();
  }

  /// Delete a mood entry.
  Future<void> deleteMood(DateTime date) async {
    await _moodService.deleteMood(_userId, date);
    final todayKey = MoodEntry.dateKey(DateTime.now());
    if (MoodEntry.dateKey(date) == todayKey) {
      _todaysMood = null;
    }
    notifyListeners();
  }

  /// Compute mood-habit correlation.
  void computeCorrelation(List<Habit> habits) {
    _correlation = _moodService.computeCorrelation(
      moods: _recentMoods,
      habits: habits,
      userId: _userId,
    );
    notifyListeners();
  }

  /// Refresh data from Firestore.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    final today = DateTime.now();
    _todaysMood = await _moodService.getMoodForDate(_userId, today);
    _recentMoods = await _moodService.getRecentMoods(_userId, days: 30);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
