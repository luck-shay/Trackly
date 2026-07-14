import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/group_challenge.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../widgets/habit_card.dart';
import '../providers/dashboard_provider.dart';
import '../providers/habits_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/quantified_log_provider.dart';
import '../services/group_service.dart';
import '../services/avatar_cache.dart';
import '../utils/app_snackbar.dart';
import '../utils/quantity_format.dart';
import 'group_challenge_detail_screen.dart';
import 'group_detail_screen.dart';
import 'habit_leaderboard_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const double _bottomNavClearance = 124;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterLabel(DashboardFilter filter) {
    return switch (filter) {
      DashboardFilter.all => 'All',
      DashboardFilter.challenges => 'Challenges',
      DashboardFilter.group => 'Group',
      DashboardFilter.individual => 'Individual',
      DashboardFilter.shared => 'Shared',
      DashboardFilter.incomplete => 'Incomplete',
      DashboardFilter.completed => 'Completed',
    };
  }

  Widget _buildFilterPills(
    BuildContext context, {
    required DashboardFilter selectedFilter,
    required ValueChanged<DashboardFilter> onChanged,
    required int allCount,
    required int challengeCount,
    required int groupCount,
    required int individualCount,
    required int sharedCount,
    required int incompleteCount,
    required int completedCount,
  }) {
    final items = <(DashboardFilter, int)>[(DashboardFilter.all, allCount)];
    if (challengeCount > 0) {
      items.add((DashboardFilter.challenges, challengeCount));
    }
    if (groupCount > 0) {
      items.add((DashboardFilter.group, groupCount));
    }
    if (individualCount > 0) {
      items.add((DashboardFilter.individual, individualCount));
    }
    if (sharedCount > 0) {
      items.add((DashboardFilter.shared, sharedCount));
    }
    if (incompleteCount > 0) {
      items.add((DashboardFilter.incomplete, incompleteCount));
    }
    if (completedCount > 0) {
      items.add((DashboardFilter.completed, completedCount));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 12),
            ...items.map((item) {
              final filter = item.$1;
              final count = item.$2;
              final selected = selectedFilter == filter;
              final useSecondary =
                  filter == DashboardFilter.incomplete ||
                  filter == DashboardFilter.completed;
              final accent = useSecondary
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary;
              final bg = selected
                  ? accent.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surface;
              final fg = selected
                  ? accent
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.78);

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () {
                    if (selectedFilter == filter) {
                      return;
                    }
                    onChanged(filter);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: 0.45)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _filterLabel(filter),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? accent.withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Habit> _applySavedOrder(List<Habit> source, List<String> orderedIds) {
    if (source.isEmpty) return const <Habit>[];
    if (orderedIds.isEmpty) return List<Habit>.from(source);

    final rank = <String, int>{};
    for (var i = 0; i < orderedIds.length; i++) {
      rank[orderedIds[i]] = i;
    }

    final indexed = source.indexed.toList();
    indexed.sort((a, b) {
      final aRank = rank[a.$2.id] ?? (100000 + a.$1);
      final bRank = rank[b.$2.id] ?? (100000 + b.$1);
      return aRank.compareTo(bRank);
    });

    return indexed.map((entry) => entry.$2).toList();
  }

  Widget _wrapCompletionMoveAnimation({
    required String habitId,
    required Widget child,
  }) {
    // Keep completion transition minimal to avoid list reflow jank.
    return child;
  }

  Widget _buildHabitReorderableItem({
    required BuildContext context,
    required String habitId,
    required int index,
    required bool opensGroup,
  }) {
    final itemKey = ValueKey(
      opensGroup ? 'group_reorder_$habitId' : 'personal_reorder_$habitId',
    );
    return KeyedSubtree(
      key: itemKey,
      child: Selector<HabitsProvider, Habit?>(
        selector: (_, provider) => provider.habitById(habitId),
        builder: (context, habit, _) {
          if (habit == null) {
            return const SizedBox.shrink();
          }

          final provider = context.read<HabitsProvider>();

          Future<void> handleToggleCompletion() async {
            final now = DateTime.now();
            final uid = provider.userId;
            final isQuantified = habit.isQuantifiedFor(uid);
            final quantMin = habit.quantMinFor(uid);
            final quantMax = habit.quantMaxFor(uid);
            final quantUnit = habit.quantUnitFor(uid);

            if (!isQuantified) {
              final wasCompleted = habit.isCompletedOnDate(
                provider.userId,
                now,
              );
              await provider.toggleHabitCompletion(habit);
              if (!wasCompleted && context.mounted) {
                await _showCompletionCelebration(context, provider, habit);
              }
              return;
            }

            if (habit.isCompletedOnDate(provider.userId, now)) {
              await provider.clearTodayProgress(habit);
              return;
            }

            final existingValue = habit.completionValueFor(
              provider.userId,
              now,
            );
            final value = await _askQuantifiedValue(
              context,
              habit,
              quantUnit,
              quantMin,
              quantMax,
              initialValue: existingValue,
            );

            if (value == null || !context.mounted) {
              return;
            }

            await provider.saveQuantifiedProgress(habit, value);

            if (value >= quantMax && context.mounted) {
              showAppSnackBar(
                context,
                message:
                    'Awesome! You hit today\'s ${habit.quantUnitFor(provider.userId)} goal.',
              );
            }
          }

          return ReorderableDelayedDragStartListener(
            index: index,
            child: _buildHabitSlidable(
              context,
              provider,
              habit,
              onToggleCompletion: handleToggleCompletion,
              child: _wrapCompletionMoveAnimation(
                habitId: habit.id,
                child: HabitCard(
                  habit: habit,
                  currentUserId: provider.userId,
                  margin: EdgeInsets.zero,
                  showShadow: false,
                  onCheck: handleToggleCompletion,
                  onCardTap: () {
                    if (opensGroup) {
                      _openGroupForHabit(context, habit);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            HabitLeaderboardScreen(habit: habit),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context, {
    required String title,
    required int count,
  }) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title ($count)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: muted,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompletionCelebration(
    BuildContext context,
    HabitsProvider provider,
    Habit habit,
  ) async {
    if (!context.mounted) return;
    final completionLabel = _completionLabelForHabit(habit, provider.userId);
    showAppSnackBar(
      context,
      message: 'Nice work! "$completionLabel" completed.',
      actionLabel: 'Undo',
      onAction: () {
        provider.clearTodayProgress(habit);
      },
    );
  }

  String _completionLabelForHabit(Habit habit, String userId) {
    if (!habit.isGroup) {
      return habit.displayTitle;
    }
    final memberTask = habit.taskFor(userId).trim();
    if (memberTask.isNotEmpty) {
      return memberTask;
    }
    return habit.title;
  }

  Future<double?> _askQuantifiedValue(
    BuildContext context,
    Habit habit,
    String quantUnit,
    double quantMin,
    double quantMax, {
    double? initialValue,
  }) async {
    final startValue = (initialValue ?? quantMin).clamp(quantMin, quantMax);
    final valueController = TextEditingController(
      text: formatQuantity(
        startValue,
        maxDecimals: (quantMax - quantMin) <= 20 ? 1 : 0,
      ),
    );

    final selectedValue = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => QuantifiedLogProvider(
            min: quantMin,
            max: quantMax,
            initialValue: startValue,
          ),
          child: Consumer<QuantifiedLogProvider>(
            builder: (context, quantProvider, _) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Log your progress',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      habit.title,
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${quantProvider.formattedValue} $quantUnit',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ).animate().scaleXY(
                      begin: 0.9,
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Type quantity',
                        suffixText: quantUnit,
                        hintText: 'Enter value manually',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                      onSubmitted: (raw) {
                        final ok = quantProvider.trySetFromText(raw);
                        if (!ok) {
                          showAppSnackBar(
                            context,
                            message: 'Please enter a valid number.',
                          );
                          return;
                        }
                        valueController.text = quantProvider.formattedValue;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              quantProvider.decrement();
                              valueController.text =
                                  quantProvider.formattedValue;
                            },
                            icon: const Icon(Icons.remove_rounded, size: 28),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 12,
                              activeTrackColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              thumbColor: Colors.white,
                              overlayColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 14,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24,
                              ),
                            ),
                            child: Slider(
                              value: quantProvider.value,
                              min: quantMin,
                              max: quantMax,
                              divisions: quantProvider.divisions,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                quantProvider.setValue(val);
                                valueController.text =
                                    quantProvider.formattedValue;
                              },
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              quantProvider.increment();
                              valueController.text =
                                  quantProvider.formattedValue;
                            },
                            icon: const Icon(Icons.add_rounded, size: 28),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final ok = quantProvider.trySetFromText(
                            valueController.text,
                          );
                          if (!ok) {
                            showAppSnackBar(
                              context,
                              message: 'Please enter a valid number.',
                            );
                            return;
                          }
                          HapticFeedback.heavyImpact();
                          Navigator.pop(sheetContext, quantProvider.value);
                        },
                        child: Text(
                          'Save Progress',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    valueController.dispose();
    return selectedValue;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  Future<void> _openGroupForHabit(BuildContext context, Habit habit) async {
    final groupId = (habit.groupEntityId ?? '').trim();
    if (groupId.isEmpty) {
      context.read<NavigationProvider>().setIndex(2);
      return;
    }

    try {
      final group = await GroupService().getGroupById(groupId);
      if (!mounted || !context.mounted) {
        return;
      }

      if (group == null) {
        context.read<NavigationProvider>().setIndex(2);
        showAppSnackBar(
          context,
          message: 'Could not find that group. Opened Groups instead.',
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      );
    } catch (error) {
      if (!mounted || !context.mounted) {
        return;
      }
      context.read<NavigationProvider>().setIndex(2);
      showAppSnackBar(
        context,
        message: 'Could not open group. ${error.toString().split('\n').first}',
      );
    }
  }

  Future<void> _openChallengeFromDashboard(
    BuildContext context,
    GroupChallenge challenge,
  ) async {
    try {
      final group = await GroupService().getGroupById(challenge.groupId);
      if (!mounted || !context.mounted) {
        return;
      }
      if (group == null) {
        showAppSnackBar(context, message: 'Could not find that group.');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GroupChallengeDetailScreen(group: group, challenge: challenge),
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message:
            'Could not open challenge. ${error.toString().split('\n').first}',
      );
    }
  }

  Future<bool> _canDeleteHabit({
    required Habit habit,
    required String currentUserId,
  }) async {
    if (!habit.isGroup || (habit.groupEntityId ?? '').trim().isEmpty) {
      return true;
    }

    final group = await GroupService().getGroupById(
      habit.groupEntityId!.trim(),
    );
    if (group == null) {
      return false;
    }
    return group.memberIds.contains(currentUserId);
  }

  Future<bool> _confirmDeleteHabit(BuildContext context, Habit habit) async {
    final isGroupTask = habit.isGroup;
    final isShared = !isGroupTask && habit.participants.length > 1;
    final title = isShared ? 'Leave shared habit?' : 'Delete habit?';
    final message = isShared
        ? 'You will be removed from "${habit.title}". Others will keep it and be notified that you left.'
        : isGroupTask
        ? 'This will delete "${habit.title}" for the whole group. This cannot be undone.'
        : 'Are you sure you want to delete "${habit.title}"? This cannot be undone.';
    final actionLabel = isShared ? 'Leave' : 'Delete';

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteHabitWithPermissions(
    BuildContext context,
    HabitsProvider provider,
    Habit habit,
  ) async {
    final canDelete = await _canDeleteHabit(
      habit: habit,
      currentUserId: provider.userId,
    );

    if (!context.mounted) {
      return;
    }

    if (!canDelete) {
      showAppSnackBar(
        context,
        message: 'Only group members can delete group tasks.',
      );
      return;
    }

    final shouldDelete = await _confirmDeleteHabit(context, habit);
    if (!context.mounted || !shouldDelete) {
      return;
    }

    try {
      await provider.deleteHabit(habit);

      if (!context.mounted) {
        return;
      }

      final canJoinBack = !habit.isGroup && habit.participants.length > 1;
      if (canJoinBack) {
        showAppSnackBar(
          context,
          message: 'You left "${habit.title}".',
          actionLabel: 'Join back',
          onAction: () async {
            try {
              final rejoined = await provider.rejoinSharedHabit(habit);
              if (!context.mounted) {
                return;
              }
              if (!rejoined) {
                showAppSnackBar(
                  context,
                  message:
                      'Could not join back. Ask a participant to invite you.',
                );
                return;
              }

              showAppSnackBar(context, message: 'Rejoined "${habit.title}".');
            } catch (error) {
              if (!context.mounted) {
                return;
              }
              showAppSnackBar(
                context,
                message:
                    'Could not join back. ${error.toString().split('\n').first}',
              );
            }
          },
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: 'Could not delete task. ${error.toString().split('\n').first}',
      );
    }
  }

  SlidableAction _buildHabitSwipeAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    return SlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: color,
      foregroundColor: Colors.white,
      icon: icon,
      label: label,
      borderRadius: borderRadius,
      spacing: 0,
      autoClose: true,
    );
  }

  Future<bool> _runAfterSlidableDismissCancel(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    Timer.run(() {
      if (!mounted || !context.mounted) {
        return;
      }

      unawaited(
        action().catchError((Object error) {
          if (!mounted || !context.mounted) {
            return;
          }
          showAppSnackBar(context, message: error.toString().split('\n').first);
        }),
      );
    });

    return false;
  }

  Widget _buildHabitSlidable(
    BuildContext context,
    HabitsProvider provider,
    Habit habit, {
    required Future<void> Function() onToggleCompletion,
    required Widget child,
  }) {
    final completedToday = habit.isCompletedOnDate(
      provider.userId,
      DateTime.now(),
    );
    final toggleLabel = completedToday ? 'Undo' : 'Done';
    final toggleIcon = completedToday
        ? Icons.undo_rounded
        : Icons.check_circle_rounded;
    final isShared = !habit.isGroup && habit.participants.length > 1;
    final deleteLabel = isShared ? 'Leave' : 'Delete';
    final borderRadius = BorderRadius.circular(24);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Slidable(
          key: ValueKey('habit_slidable_${habit.id}'),
          closeOnScroll: true,
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              closeOnCancel: true,
              confirmDismiss: () =>
                  _runAfterSlidableDismissCancel(context, onToggleCompletion),
              onDismissed: () {},
            ),
            children: [
              _buildHabitSwipeAction(
                label: toggleLabel,
                icon: toggleIcon,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.9),
                onPressed: onToggleCompletion,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              closeOnCancel: true,
              confirmDismiss: () => _runAfterSlidableDismissCancel(
                context,
                () => _deleteHabitWithPermissions(context, provider, habit),
              ),
              onDismissed: () {},
            ),
            children: [
              _buildHabitSwipeAction(
                label: deleteLabel,
                icon: Icons.delete_rounded,
                color: Colors.redAccent.withValues(alpha: 0.9),
                onPressed: () =>
                    _deleteHabitWithPermissions(context, provider, habit),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = _formatDate(today);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ChangeNotifierProvider<DashboardProvider>(
      create: (_) => DashboardProvider(userId: userId)..loadPreferences(),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 20.0,
                  // bottom: 20.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                                dateStr.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              )
                              .animate()
                              .fade(duration: 400.ms)
                              .slideX(begin: -0.1),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                    Icons.track_changes_rounded,
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                  .animate()
                                  .fade(duration: 500.ms, delay: 100.ms)
                                  .scaleXY(begin: 0.8),
                              const SizedBox(width: 8),
                              Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Your Habits',
                                        style: GoogleFonts.outfit(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fade(duration: 500.ms, delay: 100.ms)
                                  .slideX(begin: -0.1),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 100,
                      child:
                          FloatingActionButton(
                            heroTag: 'dashboard_profile_fab',
                            shape: const CircleBorder(),
                            elevation: 0,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProfileScreen(),
                                ),
                              );
                            },
                            child: ValueListenableBuilder<AvatarCacheState>(
                              valueListenable: AvatarCache.notifier,
                              builder: (context, cached, _) {
                                return StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream: userId.isEmpty
                                      ? null
                                      : FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(userId)
                                            .snapshots(),
                                  builder: (context, snapshot) {
                                    final data = snapshot.data?.data();
                                    final profile = data != null
                                        ? UserProfile.fromMap(data)
                                        : null;
                                    final photoUrl =
                                        profile?.photoUrl?.trim() ?? '';
                                    if (photoUrl.isNotEmpty) {
                                      unawaited(
                                        AvatarCache.updateFromNetwork(
                                          userId,
                                          photoUrl,
                                        ),
                                      );
                                    }

                                    if (cached.bytes != null) {
                                      return CircleAvatar(
                                        radius: 22,
                                        backgroundImage: MemoryImage(
                                          cached.bytes!,
                                        ),
                                        backgroundColor: Colors.transparent,
                                      );
                                    }

                                    if (photoUrl.isNotEmpty) {
                                      return CircleAvatar(
                                        radius: 22,
                                        backgroundImage: NetworkImage(photoUrl),
                                        backgroundColor: Colors.transparent,
                                      );
                                    }

                                    return const Icon(
                                      Icons.person_rounded,
                                      size: 34,
                                    );
                                  },
                                );
                              },
                            ),
                          ).animate().scale(
                            delay: 300.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer2<HabitsProvider, DashboardProvider>(
                  builder: (context, provider, dashboard, child) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E676),
                        ),
                      );
                    }

                    if (provider.error != null) {
                      return Center(
                        child: Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final individualHabits = provider.habits
                        .where(
                          (habit) =>
                              !habit.isGroup &&
                              habit.spaceType == HabitSpaceType.individual,
                        )
                        .toList();
                    final sharedHabits = provider.habits
                        .where(
                          (habit) =>
                              !habit.isGroup &&
                              habit.spaceType == HabitSpaceType.sharedTask,
                        )
                        .toList();
                    final groupHabits = provider.habits
                        .where((habit) => habit.isGroup)
                        .toList();
                    final orderedGroupHabits = _applySavedOrder(
                      groupHabits,
                      dashboard.groupOrderIds,
                    );
                    final personalHabits = [
                      ...individualHabits,
                      ...sharedHabits,
                    ];
                    final orderedPersonalHabits = _applySavedOrder(
                      personalHabits,
                      dashboard.personalOrderIds,
                    );
                    final displayGroupHabits = orderedGroupHabits;
                    final displayPersonalHabits = orderedPersonalHabits;
                    final displayIndividualHabits = displayPersonalHabits
                        .where((h) => h.spaceType == HabitSpaceType.individual)
                        .toList();
                    final displaySharedHabits = displayPersonalHabits
                        .where((h) => h.spaceType == HabitSpaceType.sharedTask)
                        .toList();

                    final individualCount = individualHabits.length;
                    final sharedCount = sharedHabits.length;

                    final scopeHabits = <Habit>[
                      ...displayGroupHabits,
                      ...displayPersonalHabits,
                    ];
                    final now = DateTime.now();
                    final completedCount = scopeHabits
                        .where(
                          (habit) =>
                              habit.isCompletedOnDate(provider.userId, now),
                        )
                        .length;
                    final incompleteCount = scopeHabits.length - completedCount;
                    final selectedFilter = dashboard.selectedFilter;
                    final filteredGroupHabits = switch (selectedFilter) {
                      DashboardFilter.all => displayGroupHabits,
                      DashboardFilter.challenges => const <Habit>[],
                      DashboardFilter.group => displayGroupHabits,
                      DashboardFilter.individual => const <Habit>[],
                      DashboardFilter.shared => const <Habit>[],
                      DashboardFilter.incomplete =>
                        displayGroupHabits
                            .where(
                              (habit) => !habit.isCompletedOnDate(
                                provider.userId,
                                now,
                              ),
                            )
                            .toList(),
                      DashboardFilter.completed =>
                        displayGroupHabits
                            .where(
                              (habit) =>
                                  habit.isCompletedOnDate(provider.userId, now),
                            )
                            .toList(),
                    };
                    final filteredIndividualHabits = switch (selectedFilter) {
                      DashboardFilter.all => displayIndividualHabits,
                      DashboardFilter.challenges => const <Habit>[],
                      DashboardFilter.group => const <Habit>[],
                      DashboardFilter.individual => displayIndividualHabits,
                      DashboardFilter.shared => const <Habit>[],
                      DashboardFilter.incomplete =>
                        displayIndividualHabits
                            .where(
                              (habit) => !habit.isCompletedOnDate(
                                provider.userId,
                                now,
                              ),
                            )
                            .toList(),
                      DashboardFilter.completed =>
                        displayIndividualHabits
                            .where(
                              (habit) =>
                                  habit.isCompletedOnDate(provider.userId, now),
                            )
                            .toList(),
                    };
                    final filteredSharedHabits = switch (selectedFilter) {
                      DashboardFilter.all => displaySharedHabits,
                      DashboardFilter.challenges => const <Habit>[],
                      DashboardFilter.group => const <Habit>[],
                      DashboardFilter.individual => const <Habit>[],
                      DashboardFilter.shared => displaySharedHabits,
                      DashboardFilter.incomplete =>
                        displaySharedHabits
                            .where(
                              (habit) => !habit.isCompletedOnDate(
                                provider.userId,
                                now,
                              ),
                            )
                            .toList(),
                      DashboardFilter.completed =>
                        displaySharedHabits
                            .where(
                              (habit) =>
                                  habit.isCompletedOnDate(provider.userId, now),
                            )
                            .toList(),
                    };

                    final showGroups = filteredGroupHabits.isNotEmpty;
                    final showIndividual = filteredIndividualHabits.isNotEmpty;
                    final showShared = filteredSharedHabits.isNotEmpty;

                    final showPersonal = showIndividual || showShared;
                    final filteredPersonalHabits = [
                      ...filteredIndividualHabits,
                      ...filteredSharedHabits,
                    ];
                    final filteredGroupHabitIds = filteredGroupHabits
                        .map((habit) => habit.id)
                        .toList(growable: false);
                    final filteredPersonalHabitIds = filteredPersonalHabits
                        .map((habit) => habit.id)
                        .toList(growable: false);

                    if (dashboard.isLoadingPreferences) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<List<GroupChallenge>>(
                      stream: GroupService().streamMyChallenges(),
                      builder: (context, challengeSnapshot) {
                        final myChallenges =
                            challengeSnapshot.data ?? const <GroupChallenge>[];
                        final challengeCount = myChallenges.length;
                        final allCount =
                            groupHabits.length +
                            personalHabits.length +
                            challengeCount;

                        final filteredChallenges = switch (selectedFilter) {
                          DashboardFilter.all => myChallenges,
                          DashboardFilter.challenges => myChallenges,
                          DashboardFilter.group => const <GroupChallenge>[],
                          DashboardFilter.individual =>
                            const <GroupChallenge>[],
                          DashboardFilter.shared => const <GroupChallenge>[],
                          DashboardFilter.incomplete =>
                            const <GroupChallenge>[],
                          DashboardFilter.completed => const <GroupChallenge>[],
                        };

                        final availableFilters = <DashboardFilter>{
                          DashboardFilter.all,
                          if (challengeCount > 0) DashboardFilter.challenges,
                          if (groupHabits.isNotEmpty) DashboardFilter.group,
                          if (individualCount > 0) DashboardFilter.individual,
                          if (sharedCount > 0) DashboardFilter.shared,
                          if (incompleteCount > 0) DashboardFilter.incomplete,
                          if (completedCount > 0) DashboardFilter.completed,
                        };

                        if (!availableFilters.contains(selectedFilter)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!context.mounted) return;
                            context
                                .read<DashboardProvider>()
                                .ensureSelectedFilter(availableFilters);
                          });
                        }

                        final showChallenges = filteredChallenges.isNotEmpty;

                        if (personalHabits.isEmpty &&
                            groupHabits.isEmpty &&
                            challengeCount == 0) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.05),
                                      ),
                                      child: Icon(
                                        Icons.spa_rounded,
                                        size: 80,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.6),
                                      ),
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(reverse: true),
                                    )
                                    .scaleXY(
                                      end: 1.05,
                                      duration: 2.seconds,
                                      curve: Curves.easeInOut,
                                    ),
                                const SizedBox(height: 32),
                                Text(
                                      'It\'s mighty quiet here.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                    .animate()
                                    .fade(delay: 300.ms)
                                    .slideY(begin: 0.1),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap the + icon to build better routines.',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ).animate().fade(delay: 400.ms),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            try {
                              await context
                                  .read<HabitsProvider>()
                                  .syncHealthDataForStepsHabits();
                            } catch (error) {
                              if (context.mounted) {
                                showAppSnackBar(
                                  context,
                                  message:
                                      'Refresh failed. ${error.toString().split('\n').first}',
                                );
                              }
                            }
                          },
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          child: SlidableAutoCloseBehavior(
                            closeWhenTapped: true,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: EdgeInsets.zero,
                              children: [
                                const SizedBox(height: 8),
                                _buildFilterPills(
                                  context,
                                  selectedFilter: selectedFilter,
                                  onChanged: dashboard.setSelectedFilter,
                                  allCount: allCount,
                                  challengeCount: challengeCount,
                                  groupCount: groupHabits.length,
                                  individualCount: individualCount,
                                  sharedCount: sharedCount,
                                  incompleteCount: incompleteCount,
                                  completedCount: completedCount,
                                ),
                                if (showChallenges)
                                  _buildSectionLabel(
                                    context,
                                    title: 'LIVE CHALLENGES',
                                    count: filteredChallenges.length,
                                  ),
                                if (showChallenges &&
                                    filteredChallenges.isNotEmpty)
                                  ...filteredChallenges.map((challenge) {
                                    final status = !challenge.isReadyToStart
                                        ? 'Waiting for accepts'
                                        : challenge.hasEnded
                                        ? 'Ended'
                                        : 'Live';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 8,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () =>
                                            _openChallengeFromDashboard(
                                              context,
                                              challenge,
                                            ),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      challenge.title,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      challenge.hasTarget
                                                          ? 'Target: ${formatQuantity(challenge.targetValue, maxDecimals: 1)} ${challenge.unit}'
                                                          : 'No target set',
                                                      style: GoogleFonts.inter(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.68,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                if (showGroups &&
                                    filteredGroupHabits.isNotEmpty) ...[
                                  _buildSectionLabel(
                                    context,
                                    title: 'GROUP TASKS',
                                    count: filteredGroupHabits.length,
                                  ),
                                  Column(
                                    children: [
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        proxyDecorator:
                                            (child, index, animation) {
                                              return Material(
                                                color: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                elevation: 0,
                                                child: child,
                                              );
                                            },
                                        itemCount: filteredGroupHabits.length,
                                        onReorderItem: (oldIndex, newIndex) {
                                          dashboard.reorderGroupIds(
                                            filteredGroupHabitIds,
                                            oldIndex,
                                            newIndex,
                                          );
                                        },
                                        itemBuilder: (context, index) {
                                          return _buildHabitReorderableItem(
                                            context: context,
                                            habitId:
                                                filteredGroupHabitIds[index],
                                            index: index,
                                            opensGroup: true,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ],
                                if (showPersonal &&
                                    filteredPersonalHabits.isNotEmpty)
                                  _buildSectionLabel(
                                    context,
                                    title: 'PERSONAL/SHARED TASKS',
                                    count: filteredPersonalHabits.length,
                                  ),
                                if (showPersonal)
                                  Column(
                                    children: [
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        proxyDecorator:
                                            (child, index, animation) {
                                              return Material(
                                                color: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                elevation: 0,
                                                child: child,
                                              );
                                            },
                                        itemCount:
                                            filteredPersonalHabits.length,
                                        onReorderItem: (oldIndex, newIndex) {
                                          dashboard.reorderPersonalIds(
                                            filteredPersonalHabitIds,
                                            oldIndex,
                                            newIndex,
                                          );
                                        },
                                        itemBuilder: (context, index) {
                                          return _buildHabitReorderableItem(
                                            context: context,
                                            habitId:
                                                filteredPersonalHabitIds[index],
                                            index: index,
                                            opensGroup: false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                const SizedBox(
                                  height: DashboardScreen._bottomNavClearance,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
