// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Achievement Model
// Data model for gamification achievements and XP system.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Achievement categories.
enum AchievementCategory {
  streak('Streak', Icons.local_fire_department_rounded),
  consistency('Consistency', Icons.trending_up_rounded),
  social('Social', Icons.people_rounded),
  challenge('Challenge', Icons.emoji_events_rounded),
  milestone('Milestone', Icons.flag_rounded),
  explorer('Explorer', Icons.explore_rounded);

  final String label;
  final IconData icon;

  const AchievementCategory(this.label, this.icon);
}

/// XP level tiers with names and thresholds.
class XPLevel {
  final int level;
  final String name;
  final String emoji;
  final int xpRequired;

  const XPLevel({
    required this.level,
    required this.name,
    required this.emoji,
    required this.xpRequired,
  });

  static const List<XPLevel> tiers = [
    XPLevel(level: 1, name: 'Seedling', emoji: '🌱', xpRequired: 0),
    XPLevel(level: 2, name: 'Sprout', emoji: '🌿', xpRequired: 100),
    XPLevel(level: 3, name: 'Sapling', emoji: '🌳', xpRequired: 300),
    XPLevel(level: 4, name: 'Tree', emoji: '🌲', xpRequired: 700),
    XPLevel(level: 5, name: 'Mighty Oak', emoji: '🏔️', xpRequired: 1500),
    XPLevel(level: 6, name: 'Forest', emoji: '🌄', xpRequired: 3000),
    XPLevel(level: 7, name: 'Legend', emoji: '⭐', xpRequired: 5000),
  ];

  static XPLevel forXP(int totalXP) {
    XPLevel current = tiers.first;
    for (final tier in tiers) {
      if (totalXP >= tier.xpRequired) {
        current = tier;
      } else {
        break;
      }
    }
    return current;
  }

  static XPLevel? nextLevel(int totalXP) {
    for (final tier in tiers) {
      if (totalXP < tier.xpRequired) {
        return tier;
      }
    }
    return null; // Max level reached
  }

  static double progressToNext(int totalXP) {
    final current = forXP(totalXP);
    final next = nextLevel(totalXP);
    if (next == null) return 1.0;
    final range = next.xpRequired - current.xpRequired;
    if (range <= 0) return 1.0;
    return ((totalXP - current.xpRequired) / range).clamp(0.0, 1.0);
  }
}

/// XP rewards for different actions.
class XPReward {
  static const int habitCompletion = 10;
  static const int streakDay = 5;
  static const int weeklyTargetMet = 25;
  static const int challengeParticipation = 20;
  static const int challengeWin = 100;
  static const int moodEntry = 5;
  static const int journalEntry = 10;
  static const int achievementUnlock = 50;
}

/// Definition of an achievement.
class AchievementDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final int xpReward;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    this.xpReward = XPReward.achievementUnlock,
  });

  /// All predefined achievements.
  static const List<AchievementDef> all = [
    // ── Streak Achievements ──
    AchievementDef(
      id: 'streak_3',
      title: 'Getting Started',
      description: 'Maintain a 3-day streak',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.streak,
    ),
    AchievementDef(
      id: 'streak_7',
      title: '7-Day Warrior',
      description: 'Maintain a 7-day streak',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.streak,
    ),
    AchievementDef(
      id: 'streak_14',
      title: 'Two-Week Titan',
      description: 'Maintain a 14-day streak',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.streak,
    ),
    AchievementDef(
      id: 'streak_30',
      title: '30-Day Legend',
      description: 'Maintain a 30-day streak',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.streak,
      xpReward: 100,
    ),
    AchievementDef(
      id: 'streak_66',
      title: 'Habit Scientist',
      description: 'Maintain a 66-day streak (the real habit threshold)',
      icon: Icons.science_rounded,
      category: AchievementCategory.streak,
      xpReward: 200,
    ),
    AchievementDef(
      id: 'streak_100',
      title: 'Century Club',
      description: 'Maintain a 100-day streak',
      icon: Icons.military_tech_rounded,
      category: AchievementCategory.streak,
      xpReward: 300,
    ),
    AchievementDef(
      id: 'streak_365',
      title: 'Year of Discipline',
      description: 'Maintain a 365-day streak',
      icon: Icons.diamond_rounded,
      category: AchievementCategory.streak,
      xpReward: 1000,
    ),

    // ── Consistency Achievements ──
    AchievementDef(
      id: 'total_50',
      title: 'Half Century',
      description: 'Complete 50 total habit check-ins',
      icon: Icons.check_circle_rounded,
      category: AchievementCategory.consistency,
    ),
    AchievementDef(
      id: 'total_100',
      title: 'Triple Digits',
      description: 'Complete 100 total habit check-ins',
      icon: Icons.check_circle_rounded,
      category: AchievementCategory.consistency,
    ),
    AchievementDef(
      id: 'total_500',
      title: 'Dedication Master',
      description: 'Complete 500 total habit check-ins',
      icon: Icons.workspace_premium_rounded,
      category: AchievementCategory.consistency,
      xpReward: 200,
    ),
    AchievementDef(
      id: 'total_1000',
      title: 'Unstoppable',
      description: 'Complete 1,000 total habit check-ins',
      icon: Icons.auto_awesome_rounded,
      category: AchievementCategory.consistency,
      xpReward: 500,
    ),
    AchievementDef(
      id: 'perfect_week',
      title: 'Perfect Week',
      description: 'Complete all habits every day for a full week',
      icon: Icons.stars_rounded,
      category: AchievementCategory.consistency,
      xpReward: 75,
    ),

    // ── Social Achievements ──
    AchievementDef(
      id: 'first_friend',
      title: 'Better Together',
      description: 'Add your first friend',
      icon: Icons.person_add_rounded,
      category: AchievementCategory.social,
    ),
    AchievementDef(
      id: 'shared_5',
      title: 'Social Butterfly',
      description: 'Participate in 5 shared habits',
      icon: Icons.share_rounded,
      category: AchievementCategory.social,
    ),
    AchievementDef(
      id: 'group_create',
      title: 'Community Builder',
      description: 'Create your first group',
      icon: Icons.groups_rounded,
      category: AchievementCategory.social,
    ),

    // ── Challenge Achievements ──
    AchievementDef(
      id: 'challenge_join',
      title: 'Challenger',
      description: 'Join your first challenge',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.challenge,
    ),
    AchievementDef(
      id: 'challenge_win',
      title: 'Champion',
      description: 'Win a group challenge',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.challenge,
      xpReward: 100,
    ),

    // ── Explorer Achievements ──
    AchievementDef(
      id: 'first_mood',
      title: 'Self Aware',
      description: 'Log your first mood entry',
      icon: Icons.mood_rounded,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'first_journal',
      title: 'Reflector',
      description: 'Write your first journal entry',
      icon: Icons.edit_note_rounded,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'five_categories',
      title: 'Well-Rounded',
      description: 'Create habits in 5 different categories',
      icon: Icons.category_rounded,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'habit_10',
      title: 'Habit Builder',
      description: 'Create 10 habits',
      icon: Icons.construction_rounded,
      category: AchievementCategory.milestone,
    ),
  ];
}

/// An unlocked achievement record stored in Firestore.
class UnlockedAchievement {
  final String achievementId;
  final DateTime unlockedAt;

  const UnlockedAchievement({
    required this.achievementId,
    required this.unlockedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'achievementId': achievementId,
      'unlockedAt': unlockedAt.toIso8601String(),
    };
  }

  factory UnlockedAchievement.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return UnlockedAchievement(
      achievementId: map['achievementId'] as String? ?? '',
      unlockedAt: parseDate(map['unlockedAt']) ?? DateTime.now(),
    );
  }
}
