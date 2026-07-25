// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Achievements Screen
// Beautiful grid of locked/unlocked achievements with XP and level display.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../providers/achievement_provider.dart';
import '../theme/app_layout.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AchievementProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Achievements',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppLayout.lg, 8, AppLayout.lg, 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Level & XP Header ──
            _LevelCard(
              provider: provider,
              scheme: scheme,
              isDark: isDark,
            )
                .animate()
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),

            // ── Progress Summary ──
            _ProgressSummary(
              unlocked: provider.unlockedCount,
              total: provider.totalAchievements,
              scheme: scheme,
              isDark: isDark,
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 28),

            // ── Achievement Grid by Category ──
            ...AchievementCategory.values.map((category) {
              final achievements = AchievementDef.all
                  .where((a) => a.category == category)
                  .toList();
              if (achievements.isEmpty) {
                return const SizedBox.shrink();
              }
              return _CategorySection(
                category: category,
                achievements: achievements,
                unlockedIds: provider.unlockedIds,
                scheme: scheme,
                isDark: isDark,
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Level Card ──────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final AchievementProvider provider;
  final ColorScheme scheme;
  final bool isDark;

  const _LevelCard({
    required this.provider,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final level = provider.currentLevel;
    final next = provider.nextLevel;
    final progress = provider.progressToNextLevel;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            level.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            level.name,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Level ${level.level} • ${provider.totalXP} XP',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${next.xpRequired - provider.totalXP} XP to ${next.name} ${next.emoji}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Progress Summary ────────────────────────────────────────────────────────

class _ProgressSummary extends StatelessWidget {
  final int unlocked;
  final int total;
  final ColorScheme scheme;
  final bool isDark;

  const _ProgressSummary({
    required this.unlocked,
    required this.total,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.emoji_events_rounded,
          size: 20,
          color: const Color(0xFFFFD700),
        ),
        const SizedBox(width: 8),
        Text(
          '$unlocked / $total Unlocked',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Category Section ────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final AchievementCategory category;
  final List<AchievementDef> achievements;
  final Set<String> unlockedIds;
  final ColorScheme scheme;
  final bool isDark;

  const _CategorySection({
    required this.category,
    required this.achievements,
    required this.unlockedIds,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        ...achievements.asMap().entries.map((entry) {
          final index = entry.key;
          final achievement = entry.value;
          final isUnlocked = unlockedIds.contains(achievement.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AchievementCard(
              achievement: achievement,
              isUnlocked: isUnlocked,
              scheme: scheme,
              isDark: isDark,
            )
                .animate()
                .fadeIn(
                  delay: (100 + index * 60).ms,
                  duration: 400.ms,
                )
                .moveX(
                  begin: 12,
                  end: 0,
                  delay: (100 + index * 60).ms,
                  duration: 400.ms,
                ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Achievement Card ────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final AchievementDef achievement;
  final bool isUnlocked;
  final ColorScheme scheme;
  final bool isDark;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isUnlocked ? const Color(0xFFFFD700) : scheme.onSurface.withValues(alpha: 0.25);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
              : scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              achievement.icon,
              size: 22,
              color: isUnlocked
                  ? accentColor
                  : scheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: isUnlocked ? 0.6 : 0.3),
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22)
          else
            Icon(Icons.lock_outline_rounded,
                color: scheme.onSurface.withValues(alpha: 0.2), size: 22),
        ],
      ),
    );
  }
}
