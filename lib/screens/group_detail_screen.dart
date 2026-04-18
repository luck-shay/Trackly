import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group.dart';
import '../models/group_task.dart';
import '../models/user_profile.dart';
import '../services/group_service.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';
import '../utils/quantity_format.dart';
import 'create_group_task_screen.dart';

class GroupDetailScreen extends StatelessWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  Future<void> _confirmLeaveGroup(BuildContext context, Group group) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave group?'),
          content: const Text(
            'You will stop receiving group updates. Your group tasks history will remain in the group record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !context.mounted) {
      return;
    }

    try {
      await GroupService().leaveGroup(group.id);
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You left the group.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not leave group. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  Future<void> _openInviteMembersSheet(
    BuildContext context,
    Group group,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _InviteMembersSheet(group: group);
      },
    );
  }

  Future<void> _createTask(BuildContext context, Group group) async {
    final createdTask = await Navigator.push<GroupTask>(
      context,
      MaterialPageRoute(builder: (_) => CreateGroupTaskScreen(group: group)),
    );

    if (!context.mounted || createdTask == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task created: ${createdTask.title}')),
    );
  }

  Future<void> _editTask(
    BuildContext context,
    Group group,
    GroupTask task,
  ) async {
    final updatedTask = await Navigator.push<GroupTask>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupTaskScreen(group: group, initialTask: task),
      ),
    );

    if (!context.mounted || updatedTask == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task updated: ${updatedTask.title}')),
    );
  }

  Future<void> _openMembersSheet(BuildContext context, Group group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _GroupMembersSheet(group: group);
      },
    );
  }

  Future<void> _toggleCheckboxTask(BuildContext context, GroupTask task) async {
    try {
      await GroupService().toggleCheckboxTaskCompletion(task);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update task. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    Group group,
    GroupTask task,
  ) async {
    try {
      await GroupService().deleteGroupTask(group.id, task.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task deleted: ${task.title}')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete task. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Group?>(
      stream: GroupService().streamGroupsForCurrentUser().map((groups) {
        for (final item in groups) {
          if (item.id == group.id) {
            return item;
          }
        }
        return null;
      }),
      builder: (context, snapshot) {
        final liveGroup = snapshot.data ?? group;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              liveGroup.name,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'leave') {
                    _confirmLeaveGroup(context, liveGroup);
                  }
                },
                itemBuilder: (_) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'leave',
                      child: Text('Leave group'),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: AppLayout.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppLayout.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveGroup.description.isEmpty
                            ? 'No description yet.'
                            : liveGroup.description,
                        style: GoogleFonts.inter(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                      ),
                      const VGap(AppLayout.sm),
                      Text(
                        '${liveGroup.memberIds.length} member${liveGroup.memberIds.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                      const VGap(AppLayout.xs),
                      TextButton.icon(
                        onPressed: () => _openMembersSheet(context, liveGroup),
                        icon: const Icon(Icons.people_alt_rounded, size: 18),
                        label: const Text('View members'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                            horizontal: -3,
                            vertical: -2,
                          ),
                        ),
                      ),
                      const VGap(AppLayout.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openInviteMembersSheet(context, liveGroup),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Invite'),
                            ),
                          ),
                          const HGap(AppLayout.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _createTask(context, liveGroup),
                              icon: const Icon(Icons.add_task_rounded),
                              label: const Text('Add Task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const VGap(AppLayout.lg),
                StreamBuilder<List<GroupTask>>(
                  stream: GroupService().streamGroupTasks(liveGroup.id),
                  builder: (context, taskSnapshot) {
                    if (!taskSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tasks = taskSnapshot.data!;
                    final now = DateTime.now();
                    final uid = GroupService().userId;
                    final isGroupAdmin =
                        uid.isNotEmpty && uid == liveGroup.ownerId;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GroupPulseCard(group: liveGroup, tasks: tasks),
                        const VGap(AppLayout.lg),
                        Text(
                          'Tasks',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const VGap(AppLayout.sm),
                        if (tasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppLayout.lg),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No tasks in this group yet.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const VGap(AppLayout.xs),
                                Text(
                                  'Create your first task and start tracking progress with the group.',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    height: 1.4,
                                  ),
                                ),
                                const VGap(AppLayout.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _createTask(context, liveGroup),
                                    icon: const Icon(Icons.add_task_rounded),
                                    label: const Text(
                                      'Create First Group Task',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: tasks.map((task) {
                              final completedToday =
                                  uid.isNotEmpty &&
                                  task.isCompletedOnDate(uid, now);
                              final completedTodayCount = task
                                  .completions
                                  .values
                                  .map(
                                    (dates) => dates
                                        .where(
                                          (date) =>
                                              date.year == now.year &&
                                              date.month == now.month &&
                                              date.day == now.day,
                                        )
                                        .length,
                                  )
                                  .fold<int>(0, (sum, value) => sum + value);
                              final todayValue = uid.isEmpty
                                  ? null
                                  : task.completionValueFor(uid, now);
                              final progress =
                                  (task.isQuantified &&
                                      task.quantMax > 0 &&
                                      todayValue != null)
                                  ? (todayValue / task.quantMax)
                                        .clamp(0.0, 1.0)
                                        .toDouble()
                                  : 0.0;

                              final taskCard = Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(
                                  bottom: AppLayout.sm,
                                ),
                                padding: const EdgeInsets.all(AppLayout.md),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task.title,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (task
                                                  .description
                                                  .isNotEmpty) ...[
                                                const VGap(AppLayout.xs),
                                                Text(
                                                  task.description,
                                                  style: GoogleFonts.inter(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.72,
                                                        ),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!task.isQuantified)
                                              IconButton.filledTonal(
                                                tooltip: completedToday
                                                    ? 'Undo today'
                                                    : 'Mark done today',
                                                onPressed: uid.isEmpty
                                                    ? null
                                                    : () => _toggleCheckboxTask(
                                                        context,
                                                        task,
                                                      ),
                                                icon: Icon(
                                                  completedToday
                                                      ? Icons
                                                            .check_circle_rounded
                                                      : Icons
                                                            .radio_button_unchecked_rounded,
                                                ),
                                              ),
                                            if (isGroupAdmin)
                                              IconButton(
                                                tooltip: 'Edit task',
                                                onPressed: () => _editTask(
                                                  context,
                                                  liveGroup,
                                                  task,
                                                ),
                                                icon: const Icon(
                                                  Icons.edit_rounded,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const VGap(AppLayout.sm),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '$completedTodayCount completed today',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.82),
                                            ),
                                          ),
                                        ),
                                        if (task.isQuantified)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Today: ${formatQuantity(todayValue ?? 0, maxDecimals: 1)}/${formatQuantity(task.quantMax, maxDecimals: 1)} ${task.quantUnit}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: completedToday
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: 0.16)
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              completedToday
                                                  ? 'You are done today'
                                                  : 'Not done today',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: completedToday
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.82,
                                                          ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (task.isQuantified) ...[
                                      const VGap(AppLayout.sm),
                                      LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 7,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.12),
                                      ),
                                    ],
                                  ],
                                ),
                              );

                              if (!isGroupAdmin) {
                                return taskCard;
                              }

                              return Dismissible(
                                key: Key('group_task_${task.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            title: const Text('Delete task?'),
                                            content: Text(
                                              '"${task.title}" will be removed for all group members and cannot be restored.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                  foregroundColor: Theme.of(
                                                    context,
                                                  ).colorScheme.onError,
                                                ),
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          );
                                        },
                                      ) ??
                                      false;
                                },
                                onDismissed: (_) {
                                  _deleteTask(context, liveGroup, task);
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 30),
                                  margin: const EdgeInsets.only(
                                    bottom: AppLayout.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.error.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.delete_sweep_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                    size: 30,
                                  ),
                                ),
                                child: taskCard,
                              );
                            }).toList(),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupPulseCard extends StatelessWidget {
  final Group group;
  final List<GroupTask> tasks;

  const _GroupPulseCard({required this.group, required this.tasks});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, int> _todayCounts(DateTime now) {
    final counts = <String, int>{};
    for (final task in tasks) {
      task.completions.forEach((uid, dates) {
        final total = dates.where((date) => _isSameDay(date, now)).length;
        if (total > 0) {
          counts[uid] = (counts[uid] ?? 0) + total;
        }
      });
    }
    return counts;
  }

  Map<String, int> _weekCounts(DateTime now) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final counts = <String, int>{};
    for (final task in tasks) {
      task.completions.forEach((uid, dates) {
        final total = dates.where((date) {
          return !date.isBefore(start) && !date.isAfter(end);
        }).length;
        if (total > 0) {
          counts[uid] = (counts[uid] ?? 0) + total;
        }
      });
    }
    return counts;
  }

  Future<Map<String, String>> _memberNames(List<String> memberIds) async {
    final social = SocialService();
    final names = <String, String>{};

    for (final memberId in memberIds) {
      final profile = await social.getUserProfile(memberId);
      final username = profile?.username?.trim();
      final displayName = profile?.displayName.trim();

      if (displayName != null && displayName.isNotEmpty) {
        names[memberId] = displayName;
      } else if (username != null && username.isNotEmpty) {
        names[memberId] = '@$username';
      } else {
        names[memberId] = memberId;
      }
    }

    return names;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCounts = _todayCounts(now);
    final weekCounts = _weekCounts(now);

    final activeToday = group.memberIds
        .where((memberId) => (todayCounts[memberId] ?? 0) > 0)
        .length;

    String? topUid;
    var maxCount = 0;
    for (final entry in weekCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        topUid = entry.key;
      }
    }

    final hasTasks = tasks.isNotEmpty;
    final hasMultipleMembers = group.memberIds.length > 1;

    String nextAction;
    if (!hasTasks) {
      nextAction = 'Create your first task to start this group.';
    } else if (!hasMultipleMembers) {
      nextAction = 'Invite members so progress and competition can start.';
    } else if (activeToday == 0) {
      nextAction = 'No one has logged progress today yet.';
    } else {
      nextAction = 'Group is active today. Keep the streak going.';
    }

    return FutureBuilder<Map<String, String>>(
      future: _memberNames(group.memberIds),
      builder: (context, snapshot) {
        final names = snapshot.data ?? const <String, String>{};
        final topName = topUid == null
            ? 'No leader yet'
            : '${names[topUid] ?? topUid} • $maxCount this week';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppLayout.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Pulse',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const VGap(AppLayout.xs),
              Text(
                nextAction,
                style: GoogleFonts.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),
              const VGap(AppLayout.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PulseChip(label: 'Tasks', value: '${tasks.length}'),
                  _PulseChip(
                    label: 'Active Today',
                    value: '$activeToday/${group.memberIds.length}',
                  ),
                  _PulseChip(label: 'Top Performer', value: topName),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseChip extends StatelessWidget {
  final String label;
  final String value;

  const _PulseChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _InviteMembersSheet extends StatefulWidget {
  final Group group;

  const _InviteMembersSheet({required this.group});

  @override
  State<_InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _GroupMembersSheet extends StatelessWidget {
  final Group group;

  const _GroupMembersSheet({required this.group});

  Future<List<UserProfile>> _loadMembers() async {
    final social = SocialService();
    final memberIds = group.memberIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    final profiles = await Future.wait(
      memberIds.map((id) => social.getUserProfile(id)),
    );

    final resolved = <UserProfile>[];
    for (var i = 0; i < memberIds.length; i++) {
      final uid = memberIds[i];
      final profile = profiles[i];
      if (profile != null) {
        resolved.add(profile);
      } else {
        resolved.add(
          UserProfile(
            uid: uid,
            email: '',
            displayName: uid,
            username: null,
            photoUrl: null,
            friends: const <String>[],
          ),
        );
      }
    }

    resolved.sort((a, b) {
      if (a.uid == group.ownerId) return -1;
      if (b.uid == group.ownerId) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.lg,
          AppLayout.md,
          AppLayout.lg,
          AppLayout.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group members',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const VGap(AppLayout.xs),
            Text(
              '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'} in ${group.name}',
              style: GoogleFonts.inter(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const VGap(AppLayout.md),
            Flexible(
              child: FutureBuilder<List<UserProfile>>(
                future: _loadMembers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final members = snapshot.data!;
                  if (members.isEmpty) {
                    return Text(
                      'No members found in this group.',
                      style: GoogleFonts.inter(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isOwner = member.uid == group.ownerId;
                      final subtitle =
                          member.username != null &&
                              member.username!.trim().isNotEmpty
                          ? '@${member.username!.trim()}'
                          : null;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                          backgroundImage:
                              member.photoUrl != null &&
                                  member.photoUrl!.trim().isNotEmpty
                              ? NetworkImage(member.photoUrl!.trim())
                              : null,
                          child:
                              member.photoUrl != null &&
                                  member.photoUrl!.trim().isNotEmpty
                              ? null
                              : Text(
                                  (member.displayName.isEmpty
                                          ? '?'
                                          : member.displayName[0])
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.displayName.isEmpty
                                    ? member.uid
                                    : member.displayName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Admin',
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
                        subtitle: subtitle == null
                            ? null
                            : Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.62),
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
    );
  }
}

class _InviteMembersSheetState extends State<_InviteMembersSheet> {
  final Set<String> _selectedFriendIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _sendInvites() async {
    if (_selectedFriendIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final social = SocialService();
      for (final uid in _selectedFriendIds) {
        await social.sendGroupInvite(
          groupId: widget.group.id,
          groupName: widget.group.name,
          toUserId: uid,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group invites sent.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send invites. ${error.toString().split('\n').first}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.lg,
          AppLayout.md,
          AppLayout.lg,
          AppLayout.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite members',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const VGap(AppLayout.sm),
            Text(
              'Select friends to invite to ${widget.group.name}.',
              style: GoogleFonts.inter(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const VGap(AppLayout.md),
            StreamBuilder<List<UserProfile>>(
              stream: SocialService().streamFriends(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final inviteableFriends = snapshot.data!
                    .where(
                      (friend) => !widget.group.memberIds.contains(friend.uid),
                    )
                    .toList();

                if (inviteableFriends.isEmpty) {
                  return Text(
                    'All your friends are already in this group, or you have no friends yet.',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  );
                }

                inviteableFriends.sort(
                  (a, b) => a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  ),
                );

                final nameCounts = <String, int>{};
                for (final friend in inviteableFriends) {
                  final key = _displayName(friend).toLowerCase();
                  nameCounts[key] = (nameCounts[key] ?? 0) + 1;
                }

                final filteredFriends = inviteableFriends.where((friend) {
                  if (_searchQuery.isEmpty) {
                    return true;
                  }
                  final displayName = _displayName(friend).toLowerCase();
                  final username = (friend.username ?? '').trim().toLowerCase();
                  final email = friend.email.trim().toLowerCase();
                  return displayName.contains(_searchQuery) ||
                      username.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFriendIds.length} selected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const VGap(AppLayout.xs),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, username, or email',
                        prefixIcon: const Icon(Icons.search_rounded),
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
                    ),
                    const VGap(AppLayout.sm),
                    if (filteredFriends.isEmpty)
                      Text(
                        'No friends match your search.',
                        style: GoogleFonts.inter(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      )
                    else
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.34,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredFriends.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final friend = filteredFriends[index];
                            final isSelected = _selectedFriendIds.contains(
                              friend.uid,
                            );
                            final subtitle = _subtitleForFriend(
                              friend,
                              (nameCounts[_displayName(friend).toLowerCase()] ??
                                      0) >
                                  1,
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedFriendIds.remove(friend.uid);
                                  } else {
                                    _selectedFriendIds.add(friend.uid);
                                  }
                                });
                              },
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.08),
                                backgroundImage:
                                    friend.photoUrl != null &&
                                        friend.photoUrl!.trim().isNotEmpty
                                    ? NetworkImage(friend.photoUrl!.trim())
                                    : null,
                                child:
                                    friend.photoUrl != null &&
                                        friend.photoUrl!.trim().isNotEmpty
                                    ? null
                                    : Text(
                                        (friend.displayName.isEmpty
                                                ? '?'
                                                : friend.displayName[0])
                                            .toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
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
                                            .withValues(alpha: 0.62),
                                      ),
                                    ),
                              trailing: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.black
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const VGap(AppLayout.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _sendInvites,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isSubmitting ? 'Sending...' : 'Send Invites',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
