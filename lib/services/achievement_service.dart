// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Achievement Service
// Evaluates and awards achievements based on user activity.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/achievement.dart';
import '../models/habit.dart';

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firestore path: users/{uid}/achievements/{achievementId}
  CollectionReference<Map<String, dynamic>> _achievementsCollection(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('achievements');
  }

  /// Firestore path: users/{uid}/xp (single document)
  DocumentReference<Map<String, dynamic>> _xpDoc(String userId) {
    return _firestore.collection('users').doc(userId).collection('meta').doc('xp');
  }

  /// Get all unlocked achievements for a user.
  Future<List<UnlockedAchievement>> getUnlockedAchievements(
    String userId,
  ) async {
    final snapshot = await _achievementsCollection(userId).get();
    return snapshot.docs.map((doc) {
      return UnlockedAchievement.fromMap(doc.data());
    }).toList();
  }

  /// Get the user's total XP.
  Future<int> getTotalXP(String userId) async {
    final doc = await _xpDoc(userId).get();
    if (!doc.exists) return 0;
    return (doc.data()?['totalXP'] as num?)?.toInt() ?? 0;
  }

  /// Add XP to the user's total.
  Future<int> addXP(String userId, int amount) async {
    final doc = _xpDoc(userId);
    final snapshot = await doc.get();
    final currentXP = snapshot.exists
        ? (snapshot.data()?['totalXP'] as num?)?.toInt() ?? 0
        : 0;
    final newXP = currentXP + amount;
    await doc.set({'totalXP': newXP}, SetOptions(merge: true));
    return newXP;
  }

  /// Unlock an achievement and award XP.
  Future<void> unlockAchievement(
    String userId,
    AchievementDef achievement,
  ) async {
    final unlock = UnlockedAchievement(
      achievementId: achievement.id,
      unlockedAt: DateTime.now(),
    );
    await _achievementsCollection(userId)
        .doc(achievement.id)
        .set(unlock.toMap());
    await addXP(userId, achievement.xpReward);
  }

  /// Check if a specific achievement is already unlocked.
  Future<bool> isUnlocked(String userId, String achievementId) async {
    final doc = await _achievementsCollection(userId).doc(achievementId).get();
    return doc.exists;
  }

  /// Evaluate all achievements and unlock any newly earned ones.
  /// Returns a list of newly unlocked achievements.
  Future<List<AchievementDef>> evaluateAndUnlock({
    required String userId,
    required List<Habit> habits,
    required int friendCount,
    required int sharedHabitCount,
    required int groupCount,
    required int challengeCount,
    required bool hasWonChallenge,
    required bool hasLoggedMood,
    required bool hasWrittenJournal,
  }) async {
    final unlocked = await getUnlockedAchievements(userId);
    final unlockedIds = unlocked.map((u) => u.achievementId).toSet();
    final newlyUnlocked = <AchievementDef>[];

    // Compute stats
    int maxStreak = 0;
    int totalCompletions = 0;
    final categories = <HabitCategory>{};
    bool hasPerfectWeek = false;

    for (final habit in habits) {
      final streak = habit.currentStreakFor(userId);
      if (streak > maxStreak) maxStreak = streak;

      final userCompletions = habit.completions[userId] ?? [];
      totalCompletions += userCompletions.length;
      categories.add(habit.category);

      // Check perfect week (all habits completed every day for 7 days)
      if (habit.weeklyCompletionCountFor(userId) >= 7 && habit.isDailyTarget) {
        hasPerfectWeek = true;
      }
    }

    for (final def in AchievementDef.all) {
      if (unlockedIds.contains(def.id)) continue;

      final earned = _isEarned(
        def,
        maxStreak: maxStreak,
        totalCompletions: totalCompletions,
        friendCount: friendCount,
        sharedHabitCount: sharedHabitCount,
        groupCount: groupCount,
        challengeCount: challengeCount,
        hasWonChallenge: hasWonChallenge,
        hasLoggedMood: hasLoggedMood,
        hasWrittenJournal: hasWrittenJournal,
        categoryCount: categories.length,
        habitCount: habits.length,
        hasPerfectWeek: hasPerfectWeek,
      );

      if (earned) {
        await unlockAchievement(userId, def);
        newlyUnlocked.add(def);
      }
    }

    return newlyUnlocked;
  }

  bool _isEarned(
    AchievementDef def, {
    required int maxStreak,
    required int totalCompletions,
    required int friendCount,
    required int sharedHabitCount,
    required int groupCount,
    required int challengeCount,
    required bool hasWonChallenge,
    required bool hasLoggedMood,
    required bool hasWrittenJournal,
    required int categoryCount,
    required int habitCount,
    required bool hasPerfectWeek,
  }) {
    return switch (def.id) {
      // Streak
      'streak_3' => maxStreak >= 3,
      'streak_7' => maxStreak >= 7,
      'streak_14' => maxStreak >= 14,
      'streak_30' => maxStreak >= 30,
      'streak_66' => maxStreak >= 66,
      'streak_100' => maxStreak >= 100,
      'streak_365' => maxStreak >= 365,

      // Consistency
      'total_50' => totalCompletions >= 50,
      'total_100' => totalCompletions >= 100,
      'total_500' => totalCompletions >= 500,
      'total_1000' => totalCompletions >= 1000,
      'perfect_week' => hasPerfectWeek,

      // Social
      'first_friend' => friendCount >= 1,
      'shared_5' => sharedHabitCount >= 5,
      'group_create' => groupCount >= 1,

      // Challenge
      'challenge_join' => challengeCount >= 1,
      'challenge_win' => hasWonChallenge,

      // Explorer
      'first_mood' => hasLoggedMood,
      'first_journal' => hasWrittenJournal,
      'five_categories' => categoryCount >= 5,
      'habit_10' => habitCount >= 10,

      _ => false,
    };
  }

  /// Listen to the user's XP in real time.
  Stream<int> watchXP(String userId) {
    return _xpDoc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return 0;
      return (snapshot.data()?['totalXP'] as num?)?.toInt() ?? 0;
    });
  }

  /// Listen to unlocked achievements in real time.
  Stream<List<UnlockedAchievement>> watchAchievements(String userId) {
    return _achievementsCollection(userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UnlockedAchievement.fromMap(doc.data());
      }).toList();
    });
  }
}
