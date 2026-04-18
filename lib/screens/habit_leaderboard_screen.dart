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

  String _displayName(UserProfile friend) {
    final name = friend.displayName.trim();
    return name.isEmpty ? friend.uid : name;
  }

  String? _subtitleForFriend(UserProfile friend, bool hasDuplicateDisplayName) {
    final username = friend.username?.trim() ?? '';
    final email = friend.email.trim();

    if (username.isNotEmpty && hasDuplicateDisplayName && email.isNotEmpty) {
      return '@$username • $email';
    }
    if (username.isNotEmpty) {
      return '@$username';
    }
    if (email.isNotEmpty) {
      return email;
    }
    if (hasDuplicateDisplayName) {
      return 'ID: ${friend.uid.substring(0, friend.uid.length < 8 ? friend.uid.length : 8)}';
    }
    return null;
  }

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
    final searchController = TextEditingController();
    var searchQuery = '';

    try {
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
                    return StatefulBuilder(
                      builder: (context, setSheetState) {
                        return StreamBuilder<List<UserProfile>>(
                          stream: social.streamFriends(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 260,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final friends = snapshot.data ?? [];
                            final eligible =
                                friends
                                    .where(
                                      (friend) => !habit.participants.contains(
                                        friend.uid,
                                      ),
                                    )
                                    .toList()
                                  ..sort(
                                    (a, b) =>
                                        _displayName(a).toLowerCase().compareTo(
                                          _displayName(b).toLowerCase(),
                                        ),
                                  );

                            final nameCounts = <String, int>{};
                            for (final friend in eligible) {
                              final key = _displayName(friend).toLowerCase();
                              nameCounts[key] = (nameCounts[key] ?? 0) + 1;
                            }

                            final filtered = eligible.where((friend) {
                              if (searchQuery.isEmpty) {
                                return true;
                              }
                              final displayName = _displayName(
                                friend,
                              ).toLowerCase();
                              final username = (friend.username ?? '')
                                  .trim()
                                  .toLowerCase();
                              final email = friend.email.trim().toLowerCase();
                              return displayName.contains(searchQuery) ||
                                  username.contains(searchQuery) ||
                                  email.contains(searchQuery);
                            }).toList();

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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.68),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${inviteProvider.selected.length} selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.68),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: searchController,
                                  onChanged: (value) {
                                    setSheetState(() {
                                      searchQuery = value.trim().toLowerCase();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by name, username, or email',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (eligible.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'All your friends are already part of this group, or you have no friends yet.',
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.68),
                                      ),
                                    ),
                                  )
                                else if (filtered.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'No friends match your search.',
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.68),
                                      ),
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.08),
                                      ),
                                      itemBuilder: (context, index) {
                                        final friend = filtered[index];
                                        final isSelected = inviteProvider
                                            .isSelected(friend.uid);
                                        final subtitle = _subtitleForFriend(
                                          friend,
                                          (nameCounts[_displayName(
                                                    friend,
                                                  ).toLowerCase()] ??
                                                  0) >
                                              1,
                                        );

                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          onTap: inviteProvider.isSending
                                              ? null
                                              : () {
                                                  inviteProvider.toggle(
                                                    friend.uid,
                                                    !isSelected,
                                                  );
                                                },
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.08),
                                            backgroundImage:
                                                friend.photoUrl != null &&
                                                    friend.photoUrl!
                                                        .trim()
                                                        .isNotEmpty
                                                ? NetworkImage(
                                                    friend.photoUrl!.trim(),
                                                  )
                                                : null,
                                            child:
                                                friend.photoUrl != null &&
                                                    friend.photoUrl!
                                                        .trim()
                                                        .isNotEmpty
                                                ? null
                                                : Text(
                                                    (_displayName(
                                                              friend,
                                                            ).isEmpty
                                                            ? '?'
                                                            : _displayName(
                                                                friend,
                                                              )[0])
                                                        .toUpperCase(),
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                          ),
                                          title: Text(
                                            _displayName(friend),
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: subtitle == null
                                              ? null
                                              : Text(
                                                  subtitle,
                                                  style: GoogleFonts.inter(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.62,
                                                        ),
                                                  ),
                                                ),
                                          trailing: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 140,
                                            ),
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.18,
                                                          ),
                                              ),
                                            ),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check_rounded
                                                  : Icons.add_rounded,
                                              size: 18,
                                              color: isSelected
                                                  ? Colors.black
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                            ),
                                          ),
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
                                                      habit.groupName ??
                                                      habit.title,
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
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    } finally {
      searchController.dispose();
    }
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
    final isGroup = habit.isGroup;
    final isPersonal =
        habit.spaceType == HabitSpaceType.individual && !habit.isGroup;

    final screenTitle = isGroup
        ? 'Group Task'
        : isPersonal
        ? 'Task Details'
        : 'Shared Task';

    final headerMetaText = isGroup
        ? habit.hasMemberDefinedGroupTasks
              ? 'Member-defined group task'
              : 'Group task'
        : isPersonal
        ? 'Personal task'
        : 'Shared task';

    final participantSummary = isGroup
        ? '${habit.participants.length} member${habit.participants.length == 1 ? '' : 's'}'
        : isPersonal && habit.participants.length <= 1
        ? 'Just you'
        : '${habit.participants.length} participant${habit.participants.length == 1 ? '' : 's'}';

    final inviteCtaLabel = isPersonal
        ? 'Share task'
        : isGroup
        ? 'Invite members'
        : 'Invite participants';

    final headerIcon = isGroup
        ? Icons.groups_rounded
        : isPersonal
        ? Icons.task_alt_rounded
        : Icons.people_alt_rounded;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          screenTitle,
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
          if (isGroup)
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
                    headerIcon,
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
                        headerMetaText,
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        participantSummary,
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                      if (isGroup) ...[
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
                      if (!isGroup) const SizedBox(height: 10),
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
                        label: Text(inviteCtaLabel),
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
                            color: index == 0 ? medalColor : Colors.white,
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
