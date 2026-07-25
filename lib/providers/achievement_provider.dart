// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Achievement Provider
// Reactive state management for gamification (achievements + XP).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/achievement.dart';
import '../models/habit.dart';
import '../services/achievement_service.dart';

class AchievementProvider extends ChangeNotifier {
  final AchievementService _service = AchievementService();
  String _userId = '';

  int _totalXP = 0;
  List<UnlockedAchievement> _unlockedAchievements = [];
  List<AchievementDef>? _recentlyUnlocked;
  bool _isLoading = false;
  StreamSubscription<int>? _xpSubscription;
  StreamSubscription<List<UnlockedAchievement>>? _achievementsSubscription;
  StreamSubscription<User?>? _authSubscription;

  AchievementProvider({String? userId}) {
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

  int get totalXP => _totalXP;
  XPLevel get currentLevel => XPLevel.forXP(_totalXP);
  XPLevel? get nextLevel => XPLevel.nextLevel(_totalXP);
  double get progressToNextLevel => XPLevel.progressToNext(_totalXP);
  List<UnlockedAchievement> get unlockedAchievements => _unlockedAchievements;
  Set<String> get unlockedIds =>
      _unlockedAchievements.map((u) => u.achievementId).toSet();
  List<AchievementDef>? get recentlyUnlocked => _recentlyUnlocked;
  bool get isLoading => _isLoading;

  /// How many achievements are unlocked out of total.
  int get totalAchievements => AchievementDef.all.length;
  int get unlockedCount => _unlockedAchievements.length;

  void _init() {
    _isLoading = true;
    notifyListeners();

    // Subscribe to XP updates
    _xpSubscription = _service.watchXP(_userId).listen((xp) {
      _totalXP = xp;
      notifyListeners();
    });

    // Subscribe to achievement updates
    _achievementsSubscription =
        _service.watchAchievements(_userId).listen((achievements) {
      _unlockedAchievements = achievements;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Award XP for an action (e.g., completing a habit).
  Future<void> awardXP(int amount) async {
    _totalXP = await _service.addXP(_userId, amount);
    notifyListeners();
  }

  /// Evaluate achievements based on current state.
  Future<List<AchievementDef>> evaluateAchievements({
    required List<Habit> habits,
    required int friendCount,
    required int sharedHabitCount,
    required int groupCount,
    required int challengeCount,
    required bool hasWonChallenge,
    required bool hasLoggedMood,
    required bool hasWrittenJournal,
  }) async {
    final newlyUnlocked = await _service.evaluateAndUnlock(
      userId: _userId,
      habits: habits,
      friendCount: friendCount,
      sharedHabitCount: sharedHabitCount,
      groupCount: groupCount,
      challengeCount: challengeCount,
      hasWonChallenge: hasWonChallenge,
      hasLoggedMood: hasLoggedMood,
      hasWrittenJournal: hasWrittenJournal,
    );

    if (newlyUnlocked.isNotEmpty) {
      _recentlyUnlocked = newlyUnlocked;
      notifyListeners();
    }

    return newlyUnlocked;
  }

  /// Clear the recently unlocked list (after showing notification).
  void clearRecentlyUnlocked() {
    _recentlyUnlocked = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _xpSubscription?.cancel();
    _achievementsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
