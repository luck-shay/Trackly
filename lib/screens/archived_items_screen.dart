import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../models/habit.dart';
import '../providers/habits_provider.dart';

class ArchivedItemsScreen extends StatefulWidget {
  const ArchivedItemsScreen({super.key});

  @override
  State<ArchivedItemsScreen> createState() => _ArchivedItemsScreenState();
}

class _ArchivedItemsScreenState extends State<ArchivedItemsScreen> {
  int _selectedTabIndex = 0; // 0: Habits, 1: Groups

  IconData _getHabitIcon(int? codePoint) {
    if (codePoint == null) return Icons.archive_rounded;
    // ignore: non_const_argument_for_const_parameter
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }

  Future<void> _confirmPermanentHabitDelete(
    BuildContext context,
    Habit habit,
  ) async {
    final habitsProvider = context.read<HabitsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Permanently?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${habit.displayTitle}" forever? All data and completions will be permanently lost.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete Forever',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await habitsProvider.deleteHabitPermanently(habit);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${habit.displayTitle}" permanently.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete habit: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmPermanentGroupDelete(
    BuildContext context,
    Group group,
  ) async {
    final habitsProvider = context.read<HabitsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Group Permanently?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete group "${group.name}" forever?',
            style: GoogleFonts.inter(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete Forever',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await habitsProvider.deleteGroupPermanently(group);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted group "${group.name}" permanently.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete group: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsProvider = context.watch<HabitsProvider>();
    final archivedHabits = habitsProvider.archivedHabits;
    final archivedGroups = habitsProvider.archivedGroups;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Archived Items',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Summary Card ─────────────────────────────────────────────
            _HeaderSummaryCard(
              archivedHabitsCount: archivedHabits.length,
              archivedGroupsCount: archivedGroups.length,
              scheme: scheme,
            ).animate().fade().slideY(begin: 0.05),

            const SizedBox(height: 20),

            // ── Pill Segmented Control Toggle ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PillSegmentTab(
                      label: 'Habits (${archivedHabits.length})',
                      icon: Icons.inventory_2_rounded,
                      isSelected: _selectedTabIndex == 0,
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      scheme: scheme,
                    ),
                  ),
                  Expanded(
                    child: _PillSegmentTab(
                      label: 'Groups (${archivedGroups.length})',
                      icon: Icons.groups_rounded,
                      isSelected: _selectedTabIndex == 1,
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      scheme: scheme,
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 100.ms),

            const SizedBox(height: 24),

            // ── Content Tab ─────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedTabIndex == 0
                  ? (archivedHabits.isEmpty
                      ? _buildEmptyState(
                          context,
                          icon: Icons.inventory_2_outlined,
                          title: 'No Archived Habits',
                          subtitle:
                              'Habits you delete will appear here so you can restore them anytime with full completion data.',
                        )
                      : Column(
                          key: const ValueKey('archived_habits_list'),
                          children: List.generate(archivedHabits.length, (index) {
                            final habit = archivedHabits[index];
                            return _buildArchivedHabitCard(
                              context,
                              habit,
                              scheme,
                              isDark,
                            ).animate().fade(delay: (60 * index).ms).slideY(begin: 0.05);
                          }),
                        ))
                  : (archivedGroups.isEmpty
                      ? _buildEmptyState(
                          context,
                          icon: Icons.group_off_rounded,
                          title: 'No Archived Groups',
                          subtitle:
                              'Groups you archive will appear here so you can restore them with full member history.',
                        )
                      : Column(
                          key: const ValueKey('archived_groups_list'),
                          children: List.generate(archivedGroups.length, (index) {
                            final group = archivedGroups[index];
                            return _buildArchivedGroupCard(
                              context,
                              group,
                              scheme,
                              isDark,
                            ).animate().fade(delay: (60 * index).ms).slideY(begin: 0.05);
                          }),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.6),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedHabitCard(
    BuildContext context,
    Habit habit,
    ColorScheme scheme,
    bool isDark,
  ) {
    final habitsProvider = context.read<HabitsProvider>();
    final uid = habitsProvider.userId;
    final totalCompletions = habit.completions[uid]?.length ?? 0;
    final habitColor = habit.colorValue != null
        ? Color(habit.colorValue!)
        : scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getHabitIcon(habit.iconCodePoint),
                    color: habitColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.displayTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              habit.category.label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$totalCompletions completions logged',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _confirmPermanentHabitDelete(context, habit),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete Forever'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await habitsProvider.restoreHabit(habit);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Restored "${habit.displayTitle}" with all data!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to restore habit: $e'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.unarchive_rounded, size: 16),
                  label: const Text('Restore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedGroupCard(
    BuildContext context,
    Group group,
    ColorScheme scheme,
    bool isDark,
  ) {
    final habitsProvider = context.read<HabitsProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${group.memberIds.length} members',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          if (group.description.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: scheme.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _confirmPermanentGroupDelete(context, group),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete Forever'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await habitsProvider.restoreGroup(group);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Restored group "${group.name}"!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to restore group: $e'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.unarchive_rounded, size: 16),
                  label: const Text('Restore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header Summary Card ───────────────────────────────────────────────────────

class _HeaderSummaryCard extends StatelessWidget {
  final int archivedHabitsCount;
  final int archivedGroupsCount;
  final ColorScheme scheme;

  const _HeaderSummaryCard({
    required this.archivedHabitsCount,
    required this.archivedGroupsCount,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.archive_rounded,
              color: scheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archive Safe',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deleted items stay preserved here. Restore anytime with full history intact.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill Segment Tab ──────────────────────────────────────────────────────────

class _PillSegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _PillSegmentTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.black
                  : scheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.black
                    : scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
