import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../providers/group_interaction_provider.dart';
import '../providers/habit_leaderboard_provider.dart';
import '../providers/habits_provider.dart';
import '../services/social_service.dart';
import '../utils/quantity_format.dart';
import 'create_habit_screen.dart';
import '../widgets/calendar_activity_sheet.dart';

class HabitLeaderboardScreen extends StatelessWidget {
  final Habit habit;

  const HabitLeaderboardScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<
      HabitsProvider,
      HabitLeaderboardProvider
    >(
      create: (_) => HabitLeaderboardProvider(habit),
      update: (_, habitsProvider, provider) {
        final liveHabit = habitsProvider.habits.firstWhere(
          (candidate) => candidate.id == habit.id,
          orElse: () => habit,
        );
        final leaderboardProvider =
            provider ?? HabitLeaderboardProvider(liveHabit);
        leaderboardProvider.syncWithHabit(liveHabit);
        return leaderboardProvider;
      },
      child: const _HabitLeaderboardView(),
    );
  }
}

class _HabitLeaderboardView extends StatelessWidget {
  const _HabitLeaderboardView();

  Future<void> _confirmLeaveGroup(BuildContext context, Habit habit) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave group?'),
          content: const Text(
            'You will stop receiving updates and your personal progress will be removed from this group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !context.mounted) {
      return;
    }

    await context.read<HabitsProvider>().leaveGroup(habit);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You left the group.')));
    }
  }

  Future<void> _showInviteMembersSheet(
    BuildContext context,
    Habit habit,
  ) async {
    final social = SocialService();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => GroupInviteSelectionProvider(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Consumer<GroupInviteSelectionProvider>(
                builder: (context, inviteProvider, _) {
                  return StreamBuilder<List<UserProfile>>(
                    stream: social.streamFriends(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 260,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final friends = snapshot.data ?? [];
                      final eligible = friends
                          .where(
                            (friend) =>
                                !habit.participants.contains(friend.uid),
                          )
                          .toList();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invite members',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select friends to invite to ${habit.groupName?.isNotEmpty == true ? habit.groupName : habit.title}.',
                            style: GoogleFonts.inter(
                              color: Colors.grey[400],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (eligible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'All your friends are already part of this group, or you have no friends yet.',
                                style: GoogleFonts.inter(
                                  color: Colors.grey[500],
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: eligible.length,
                                separatorBuilder: (_, index) => const Divider(
                                  height: 1,
                                  color: Colors.white10,
                                ),
                                itemBuilder: (context, index) {
                                  final friend = eligible[index];
                                  final isSelected = inviteProvider.isSelected(
                                    friend.uid,
                                  );

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: inviteProvider.isSending
                                        ? null
                                        : (value) {
                                            inviteProvider.toggle(
                                              friend.uid,
                                              value == true,
                                            );
                                          },
                                    title: Text(
                                      friend.displayName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      friend.username != null
                                          ? '@${friend.username}'
                                          : friend.email,
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    fillColor: WidgetStatePropertyAll(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                    checkColor: Colors.black,
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  inviteProvider.isSending ||
                                      inviteProvider.selected.isEmpty
                                  ? null
                                  : () async {
                                      inviteProvider.setSending(true);

                                      for (final uid
                                          in inviteProvider.selected) {
                                        if (habit.isGroup) {
                                          await social.sendGroupInvite(
                                            groupId: habit.id,
                                            groupName:
                                                habit.groupName ?? habit.title,
                                            toUserId: uid,
                                          );
                                        } else {
                                          await social.sendHabitInvite(
                                            habitId: habit.id,
                                            toUserId: uid,
                                          );
                                        }
                                      }

                                      if (context.mounted) {
                                        Navigator.pop(sheetContext);
                                        final inviteLabel = habit.isGroup
                                            ? 'group invite'
                                            : 'task invite';
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Sent ${inviteProvider.selected.length} $inviteLabel${inviteProvider.selected.length == 1 ? '' : 's'}.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.black,
                              ),
                              child: inviteProvider.isSending
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      inviteProvider.selected.isEmpty
                                          ? 'Select friends to invite'
                                          : 'Send invites',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditMyGroupTaskSheet(
    BuildContext context,
    Habit habit,
    String currentUserId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => GroupTaskEditorProvider(
            initialTask: habit.taskFor(currentUserId),
            initialIsQuantified: habit.isQuantifiedFor(currentUserId),
            initialQuantUnit: habit.quantUnitFor(currentUserId),
            initialQuantMax: habit.quantMaxFor(currentUserId),
          ),
          child: Consumer<GroupTaskEditorProvider>(
            builder: (context, taskProvider, _) {
              const units = ['km', 'hours', 'reps', 'pages', 'steps', 'units'];

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set my task',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      autofocus: true,
                      initialValue: taskProvider.draft,
                      onChanged: taskProvider.setDraft,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 5 km run, 30 min yoga',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: taskProvider.isQuantified,
                      onChanged: taskProvider.setIsQuantified,
                      title: Text(
                        'Quantified for me',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        taskProvider.isQuantified
                            ? 'I will log numeric values for this task.'
                            : 'Simple done / undone for me.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (taskProvider.isQuantified) ...[
                      TextFormField(
                        initialValue: taskProvider.quantUnit,
                        onChanged: taskProvider.setQuantUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'e.g. km, pages, units',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: units.map((unit) {
                          final selected = taskProvider.quantUnit == unit;
                          return ChoiceChip(
                            label: Text(unit),
                            selected: selected,
                            onSelected: (_) => taskProvider.setQuantUnit(unit),
                            labelStyle: GoogleFonts.inter(
                              color: selected ? Colors.black : Colors.white,
                            ),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: formatQuantity(
                          taskProvider.quantMax,
                          maxDecimals: taskProvider.quantDecimals,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Daily target',
                          hintText: 'Enter max value',
                          suffixText: taskProvider.quantUnit,
                        ),
                        onChanged: (raw) {
                          final parsed = double.tryParse(raw.trim());
                          if (parsed == null ||
                              !parsed.isFinite ||
                              parsed <= 0) {
                            return;
                          }
                          taskProvider.setQuantMax(parsed);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MAX DAILY VALUE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            '${formatQuantity(taskProvider.quantMax, maxDecimals: taskProvider.quantDecimals)} ${taskProvider.quantUnit}',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: taskProvider.quantMax,
                        min: taskProvider.quantSliderMin,
                        max: taskProvider.quantSliderMax,
                        divisions: taskProvider.quantSliderDivisions,
                        onChanged: taskProvider.setQuantMax,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: taskProvider.isSaving
                            ? null
                            : () async {
                                taskProvider.setSaving(true);
                                await context
                                    .read<HabitsProvider>()
                                    .updateMyGroupTask(
                                      habit,
                                      taskProvider.draft,
                                      isQuantified: taskProvider.isQuantified,
                                      quantUnit: taskProvider.quantUnit,
                                      quantMax: taskProvider.quantMax,
                                    );
                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                        child: taskProvider.isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save task'),
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitLeaderboardProvider>();
    final habit = provider.habit;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leaderboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit habit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateHabitScreen(initialHabit: habit),
                ),
              );
            },
            icon: const Icon(Icons.edit_rounded),
          ),
          if (habit.isGroup)
            IconButton(
              tooltip: 'Leave group',
              onPressed: () => _confirmLeaveGroup(context, habit),
              icon: const Icon(Icons.exit_to_app_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.leaderboard_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.displayTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        habit.isGroup && (habit.groupName ?? '').isNotEmpty
                            ? habit.hasMemberDefinedGroupTasks
                                  ? 'Member-defined group tasks'
                                  : 'Task: ${habit.title}'
                            : habit.spaceType.label,
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${habit.participants.length} ${habit.isGroup ? 'Member' : 'Participant'}${habit.participants.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                      if (habit.isGroup) ...[
                        const SizedBox(height: 10),
                        if (habit.hasMemberDefinedGroupTasks) ...[
                          OutlinedButton.icon(
                            onPressed: () => _showEditMyGroupTaskSheet(
                              context,
                              habit,
                              context.read<HabitsProvider>().userId,
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Set my task'),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (!habit.isGroup) const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (habit.spaceType == HabitSpaceType.individual) {
                            await context
                                .read<HabitsProvider>()
                                .convertToSharedSpace(habit);
                          }
                          if (context.mounted) {
                            _showInviteMembersSheet(context, habit);
                          }
                        },
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: const Text('Invite members'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.15),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fade().slideY(begin: 0.1),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: Builder(
              builder: (context) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(
                    child: Text('Error loading leaderboard: ${provider.error}'),
                  );
                }

                final participants = provider.participants;

                if (participants.isEmpty) {
                  return const Center(child: Text('No participants found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final user = participants[index];
                    final streak = habit.currentStreakFor(user.uid);
                    final today = DateTime.now();
                    final todayValue = habit.completionValueFor(
                      user.uid,
                      today,
                    );
                    final userQuantMax = habit.quantMaxFor(user.uid);
                    final userQuantUnit = habit.quantUnitFor(user.uid);
                    final userIsQuantified = habit.isQuantifiedFor(user.uid);
                    final todayProgress =
                        (habit.completionProgressFor(user.uid, today) * 100)
                            .round();

                    Color medalColor;
                    Widget? rankBadge;

                    if (index == 0) {
                      medalColor = const Color(0xFFFFD700); // Gold
                      rankBadge = const Text(
                        '🥇',
                        style: TextStyle(fontSize: 24),
                      );
                    } else if (index == 1) {
                      medalColor = const Color(0xFFC0C0C0); // Silver
                      rankBadge = const Text(
                        '🥈',
                        style: TextStyle(fontSize: 24),
                      );
                    } else if (index == 2) {
                      medalColor = const Color(0xFFCD7F32); // Bronze
                      rankBadge = const Text(
                        '🥉',
                        style: TextStyle(fontSize: 24),
                      );
                    } else {
                      medalColor = Colors.grey[800]!;
                      rankBadge = Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text(
                          '#${index + 1}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                          ),
                        ),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: index == 0
                              ? medalColor.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                        boxShadow: index == 0
                            ? [
                                BoxShadow(
                                  color: medalColor.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: ListTile(
                        onTap: () =>
                            CalendarActivitySheet.show(context, habit, user),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            rankBadge,
                            const SizedBox(width: 16),
                            CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              backgroundImage: user.photoUrl != null
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: user.photoUrl == null
                                  ? Icon(
                                      Icons.person,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        title: Text(
                          user.displayName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: index == 0
                                ? medalColor
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${user.username != null ? '@${user.username}' : user.email}  •  ${habit.hasMemberDefinedGroupTasks
                              ? '${habit.taskFor(user.uid).isEmpty ? 'No task set yet' : habit.taskFor(user.uid)}${userIsQuantified && todayValue != null ? ' • ${formatQuantity(todayValue, maxDecimals: 1)} / ${formatQuantity(userQuantMax, maxDecimals: 1)} $userQuantUnit ($todayProgress%)' : ''}'
                              : userIsQuantified && todayValue != null
                              ? '${formatQuantity(todayValue, maxDecimals: 1)} / ${formatQuantity(userQuantMax, maxDecimals: 1)} $userQuantUnit ($todayProgress%)'
                              : 'Tap for activity'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: streak > 0
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: streak > 0
                                    ? Colors.orange
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: streak > 0
                                      ? Colors.orange
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
