import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/group.dart';
import '../models/group_challenge.dart';
import '../models/group_task.dart';
import '../models/user_profile.dart';
import '../services/group_service.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';
import '../utils/quantity_format.dart';
import 'create_group_challenge_screen.dart';
import 'group_challenge_detail_screen.dart';
import 'create_group_task_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _isChallengesExpanded = true;
  bool _isTasksExpanded = false;

  Widget _buildChallengesHeader(BuildContext context, int challengeCount) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () {
        setState(() {
          _isChallengesExpanded = !_isChallengesExpanded;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'LIVE CHALLENGES ($challengeCount)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: onSurface.withValues(alpha: 0.62),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(
              _isChallengesExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: onSurface.withValues(alpha: 0.62),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksHeader(BuildContext context, int taskCount) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () {
        setState(() {
          _isTasksExpanded = !_isTasksExpanded;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'TASKS ($taskCount)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: onSurface.withValues(alpha: 0.62),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(
              _isTasksExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: onSurface.withValues(alpha: 0.62),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _createChallenge(BuildContext context, Group group) async {
    final createdChallenge = await Navigator.push<GroupChallenge>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupChallengeScreen(group: group),
      ),
    );

    if (!context.mounted || createdChallenge == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Challenge started: ${createdChallenge.title}')),
    );
  }

  Future<void> _openChallenge(
    BuildContext context,
    Group group,
    GroupChallenge challenge,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GroupChallengeDetailScreen(group: group, challenge: challenge),
      ),
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

  Future<bool> _confirmDeleteTask(BuildContext context, GroupTask task) async {
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
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _showTaskInfoSheet(
    BuildContext context,
    GroupTask task, {
    required int completedTodayCount,
  }) async {
    final todayValue = GroupService().userId.isEmpty
        ? null
        : task.completionValueFor(GroupService().userId, DateTime.now());

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  task.title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const VGap(AppLayout.sm),
                if (task.description.trim().isNotEmpty)
                  Text(
                    task.description,
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                if (task.description.trim().isNotEmpty)
                  const VGap(AppLayout.md),
                Text(
                  'Completed today by group: $completedTodayCount',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const VGap(AppLayout.xs),
                Text(
                  task.isQuantified
                      ? 'Your progress today: ${formatQuantity(todayValue ?? 0, maxDecimals: 1)}/${formatQuantity(task.quantMax, maxDecimals: 1)} ${task.quantUnit}'
                      : 'Type: checkbox task',
                  style: GoogleFonts.inter(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SlidableAction _buildGroupTaskSwipeAction({
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

  Widget _buildTaskSlidable(
    BuildContext context,
    Group group,
    GroupTask task, {
    required bool isGroupAdmin,
    required int completedTodayCount,
    required Widget child,
  }) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Slidable(
          key: ValueKey('group_task_slide_${task.id}'),
          closeOnScroll: true,
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: isGroupAdmin ? 0.5 : 0.25,
            dismissible: DismissiblePane(
              onDismissed: () {},
              closeOnCancel: true,
              confirmDismiss: () async {
                await _showTaskInfoSheet(
                  context,
                  task,
                  completedTodayCount: completedTodayCount,
                );
                return false;
              },
            ),
            children: [
              _buildGroupTaskSwipeAction(
                label: 'Info',
                icon: Icons.info_outline_rounded,
                color: secondaryColor.withValues(alpha: 0.9),
                onPressed: () => _showTaskInfoSheet(
                  context,
                  task,
                  completedTodayCount: completedTodayCount,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
              if (isGroupAdmin)
                _buildGroupTaskSwipeAction(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: secondaryColor.withValues(alpha: 0.72),
                  onPressed: () => _editTask(context, group, task),
                ),
            ],
          ),
          endActionPane: isGroupAdmin
              ? ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.28,
                  dismissible: DismissiblePane(
                    onDismissed: () {},
                    closeOnCancel: true,
                    confirmDismiss: () async {
                      final shouldDelete = await _confirmDeleteTask(
                        context,
                        task,
                      );
                      if (!context.mounted || !shouldDelete) {
                        return false;
                      }
                      await _deleteTask(context, group, task);
                      return false;
                    },
                  ),
                  children: [
                    _buildGroupTaskSwipeAction(
                      label: 'Delete',
                      icon: Icons.delete_rounded,
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () async {
                        final shouldDelete = await _confirmDeleteTask(
                          context,
                          task,
                        );
                        if (!context.mounted || !shouldDelete) {
                          return;
                        }
                        await _deleteTask(context, group, task);
                      },
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                  ],
                )
              : null,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Group?>(
      stream: GroupService().streamGroupsForCurrentUser().map((groups) {
        for (final item in groups) {
          if (item.id == widget.group.id) {
            return item;
          }
        }
        return null;
      }),
      builder: (context, snapshot) {
        final liveGroup = snapshot.data ?? widget.group;

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
                      const VGap(AppLayout.xs),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _createChallenge(context, liveGroup),
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('Start Challenge'),
                        ),
                      ),
                    ],
                  ),
                ),
                const VGap(AppLayout.lg),
                StreamBuilder<List<GroupChallenge>>(
                  stream: GroupService().streamGroupChallenges(liveGroup.id),
                  builder: (context, challengeSnapshot) {
                    final challenges =
                        challengeSnapshot.data ?? const <GroupChallenge>[];
                    final activeCount = challenges
                        .where((challenge) => challenge.isActive)
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChallengesHeader(context, challenges.length),
                        const VGap(AppLayout.sm),
                        if (_isChallengesExpanded)
                          if (challenges.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppLayout.md),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No challenges yet.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const VGap(AppLayout.xs),
                                  Text(
                                    'Start a time-boxed head-to-head challenge for this group.',
                                    style: GoogleFonts.inter(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppLayout.xs,
                                      bottom: AppLayout.xs,
                                    ),
                                    child: Text(
                                      '$activeCount active right now',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                ...challenges.map((challenge) {
                                  final now = DateTime.now();
                                  final hasStarted = !now.isBefore(
                                    challenge.startAt,
                                  );
                                  final hasEnded = now.isAfter(challenge.endAt);
                                  final daysLeft = hasEnded
                                      ? 0
                                      : challenge.endAt
                                                .difference(
                                                  DateTime(
                                                    now.year,
                                                    now.month,
                                                    now.day,
                                                  ),
                                                )
                                                .inDays +
                                            1;

                                  String statusLabel;
                                  Color statusColor;
                                  if (!challenge.isReadyToStart) {
                                    statusLabel = 'Waiting';
                                    statusColor = Theme.of(
                                      context,
                                    ).colorScheme.secondary;
                                  } else if (!hasStarted) {
                                    statusLabel = 'Upcoming';
                                    statusColor = Theme.of(
                                      context,
                                    ).colorScheme.secondary;
                                  } else if (hasEnded) {
                                    statusLabel = 'Ended';
                                    statusColor = Theme.of(
                                      context,
                                    ).colorScheme.onSurface;
                                  } else {
                                    statusLabel =
                                        '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
                                    statusColor = Theme.of(
                                      context,
                                    ).colorScheme.primary;
                                  }

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                      bottom: AppLayout.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () => _openChallenge(
                                        context,
                                        liveGroup,
                                        challenge,
                                      ),
                                      title: Text(
                                        challenge.title,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 6),
                                          Text(
                                            challenge.hasTarget
                                                ? 'Target: ${formatQuantity(challenge.targetValue, maxDecimals: 1)} ${challenge.unit}'
                                                : 'No target set',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.72),
                                            ),
                                          ),
                                          Text(
                                            '${challenge.participantIds.length} participants',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.62),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                      ],
                    );
                  },
                ),
                const VGap(AppLayout.md),
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
                        uid.isNotEmpty && liveGroup.memberIds.contains(uid);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GroupPulseCard(group: liveGroup, tasks: tasks),
                        const VGap(AppLayout.md),
                        _GroupLeaderboardCard(group: liveGroup, tasks: tasks),
                        const VGap(AppLayout.lg),
                        _buildTasksHeader(context, tasks.length),
                        const VGap(AppLayout.sm),
                        if (_isTasksExpanded)
                          if (tasks.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppLayout.lg),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.1),
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
                                  padding: const EdgeInsets.all(AppLayout.md),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: completedToday
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.16,
                                                          )
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

                                return _buildTaskSlidable(
                                  context,
                                  liveGroup,
                                  task,
                                  isGroupAdmin: isGroupAdmin,
                                  completedTodayCount: completedTodayCount,
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

enum _LeaderboardWindow { today, week, allTime }

class _GroupLeaderboardCard extends StatefulWidget {
  final Group group;
  final List<GroupTask> tasks;

  const _GroupLeaderboardCard({required this.group, required this.tasks});

  @override
  State<_GroupLeaderboardCard> createState() => _GroupLeaderboardCardState();
}

class _GroupLeaderboardCardState extends State<_GroupLeaderboardCard> {
  _LeaderboardWindow _window = _LeaderboardWindow.week;
  bool _showCalendar = false;
  DateTime _calendarFocusedDay = DateTime.now();
  DateTime? _calendarSelectedDay;
  String? _calendarSelectedUid;

  Widget _buildWindowChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: selected
              ? (isDark ? Colors.white : scheme.onPrimary)
              : scheme.onSurface.withValues(alpha: isDark ? 0.88 : 0.78),
        ),
      ),
      selected: selected,
      selectedColor: isDark
          ? scheme.primary.withValues(alpha: 0.36)
          : scheme.primary.withValues(alpha: 0.2),
      backgroundColor: scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.04),
      checkmarkColor: isDark ? Colors.white : scheme.onPrimary,
      side: BorderSide(
        color: selected
            ? (isDark
                  ? scheme.primary.withValues(alpha: 0.72)
                  : scheme.primary.withValues(alpha: 0.35))
            : scheme.onSurface.withValues(alpha: isDark ? 0.5 : 0.25),
        width: 1.5,
      ),
      onSelected: (_) => onTap(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isWithinRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }

  DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<Map<String, UserProfile?>> _loadProfiles(
    List<String> memberIds,
  ) async {
    final social = SocialService();
    final profiles = await Future.wait(
      memberIds.map((memberId) => social.getUserProfile(memberId)),
    );

    final byId = <String, UserProfile?>{};
    for (var index = 0; index < memberIds.length; index++) {
      byId[memberIds[index]] = profiles[index];
    }
    return byId;
  }

  String _displayNameFor(String uid, Map<String, UserProfile?> profiles) {
    final profile = profiles[uid];
    final displayName = profile?.displayName.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final username = profile?.username?.trim() ?? '';
    if (username.isNotEmpty) {
      return '@$username';
    }
    return uid;
  }

  int _completionEventsForUser({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    var total = 0;
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      total += dates.where((date) => _isWithinRange(date, start, end)).length;
    }
    return total;
  }

  int _activeDaysForUser({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) {
    final days = <DateTime>{};
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      for (final date in dates) {
        if (_isWithinRange(date, start, end)) {
          days.add(_dayOnly(date));
        }
      }
    }
    return days.length;
  }

  int _todayTaskCompletions(GroupTask task, DateTime now) {
    var total = 0;
    for (final dates in task.completions.values) {
      total += dates.where((date) => _isSameDay(date, now)).length;
    }
    return total;
  }

  int _completionsOnDateForUser({required String uid, required DateTime day}) {
    var total = 0;
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      total += dates.where((date) => _isSameDay(date, day)).length;
    }
    return total;
  }

  Map<DateTime, int> _calendarCountsForUser(String uid) {
    final counts = <DateTime, int>{};
    for (final task in widget.tasks) {
      final dates = task.completions[uid] ?? const <DateTime>[];
      for (final date in dates) {
        final day = _dayOnly(date);
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    return FutureBuilder<Map<String, UserProfile?>>(
      future: _loadProfiles(widget.group.memberIds),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? const <String, UserProfile?>{};

        final rankRows =
            widget.group.memberIds.map((uid) {
              final todayEvents = _completionEventsForUser(
                uid: uid,
                start: todayStart,
                end: todayEnd,
              );
              final weekEvents = _completionEventsForUser(
                uid: uid,
                start: weekStart,
                end: todayEnd,
              );
              final allEvents = _completionEventsForUser(
                uid: uid,
                start: DateTime(2020, 1, 1),
                end: todayEnd,
              );

              final weekActiveDays = _activeDaysForUser(
                uid: uid,
                start: weekStart,
                end: todayEnd,
              );

              final score = switch (_window) {
                _LeaderboardWindow.today => todayEvents,
                _LeaderboardWindow.week => weekEvents,
                _LeaderboardWindow.allTime => allEvents,
              };

              return _LeaderboardMemberRow(
                uid: uid,
                name: _displayNameFor(uid, profiles),
                photoUrl: profiles[uid]?.photoUrl,
                score: score,
                todayEvents: todayEvents,
                weekEvents: weekEvents,
                allEvents: allEvents,
                weekActiveDays: weekActiveDays,
              );
            }).toList()..sort((a, b) {
              final scoreCompare = b.score.compareTo(a.score);
              if (scoreCompare != 0) {
                return scoreCompare;
              }
              final consistencyCompare = b.weekActiveDays.compareTo(
                a.weekActiveDays,
              );
              if (consistencyCompare != 0) {
                return consistencyCompare;
              }
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

        _LeaderboardMemberRow? mostConsistent;
        _LeaderboardMemberRow? mostActiveToday;
        for (final row in rankRows) {
          if (mostConsistent == null ||
              row.weekActiveDays > mostConsistent.weekActiveDays) {
            mostConsistent = row;
          }
          if (mostActiveToday == null ||
              row.todayEvents > mostActiveToday.todayEvents) {
            mostActiveToday = row;
          }
        }

        GroupTask? topTaskToday;
        var topTaskTodayCompletions = 0;
        for (final task in widget.tasks) {
          final taskCompletions = _todayTaskCompletions(task, now);
          if (taskCompletions > topTaskTodayCompletions) {
            topTaskTodayCompletions = taskCompletions;
            topTaskToday = task;
          }
        }

        final scoreLabel = switch (_window) {
          _LeaderboardWindow.today => 'today',
          _LeaderboardWindow.week => 'this week',
          _LeaderboardWindow.allTime => 'all time',
        };

        if (rankRows.isNotEmpty && _calendarSelectedUid == null) {
          _calendarSelectedUid = rankRows.first.uid;
        }
        final selectedUid = _calendarSelectedUid;
        final dayCounts = selectedUid == null
            ? const <DateTime, int>{}
            : _calendarCountsForUser(selectedUid);
        final selectedDay = _calendarSelectedDay ?? _dayOnly(now);
        final selectedDayCount = selectedUid == null
            ? 0
            : _completionsOnDateForUser(uid: selectedUid, day: selectedDay);

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
                'Group Leaderboard',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const VGap(AppLayout.xs),
              Text(
                'Ranked by completions $scoreLabel.',
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
                  _buildWindowChip(
                    context,
                    label: 'Leaderboard',
                    selected: !_showCalendar,
                    onTap: () {
                      setState(() => _showCalendar = false);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'Calendar',
                    selected: _showCalendar,
                    onTap: () {
                      setState(() => _showCalendar = true);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'Today',
                    selected: _window == _LeaderboardWindow.today,
                    onTap: () {
                      setState(() => _window = _LeaderboardWindow.today);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'Week',
                    selected: _window == _LeaderboardWindow.week,
                    onTap: () {
                      setState(() => _window = _LeaderboardWindow.week);
                    },
                  ),
                  _buildWindowChip(
                    context,
                    label: 'All time',
                    selected: _window == _LeaderboardWindow.allTime,
                    onTap: () {
                      setState(() => _window = _LeaderboardWindow.allTime);
                    },
                  ),
                ],
              ),
              const VGap(AppLayout.sm),
              if (_showCalendar) ...[
                if (rankRows.isEmpty)
                  Text(
                    'No members yet.',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'Member',
                      border: OutlineInputBorder(),
                    ),
                    items: rankRows
                        .map(
                          (row) => DropdownMenuItem<String>(
                            value: row.uid,
                            child: Text(row.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _calendarSelectedUid = value;
                      });
                    },
                  ),
                  const VGap(AppLayout.sm),
                  TableCalendar<void>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _calendarFocusedDay,
                    selectedDayPredicate: (day) =>
                        _isSameDay(day, _calendarSelectedDay ?? _dayOnly(now)),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _calendarSelectedDay = selected;
                        _calendarFocusedDay = focused;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final count = dayCounts[_dayOnly(day)] ?? 0;
                        if (count <= 0) {
                          return null;
                        }
                        final intensity = count >= 5
                            ? 0.45
                            : count >= 3
                            ? 0.32
                            : 0.2;
                        return Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: intensity),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const VGap(AppLayout.xs),
                  Text(
                    'Selected day: ${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')} • $selectedDayCount completions',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ] else ...[
                if (rankRows.isEmpty)
                  Text(
                    'No members yet.',
                    style: GoogleFonts.inter(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  )
                else
                  ...rankRows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return _LeaderboardTile(
                      rank: index + 1,
                      row: row,
                      metricLabel: scoreLabel,
                    );
                  }),
              ],
              const VGap(AppLayout.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PulseChip(
                    label: 'Most consistent',
                    value: mostConsistent == null
                        ? 'No data yet'
                        : '${mostConsistent.name} • ${mostConsistent.weekActiveDays}/7 days',
                  ),
                  _PulseChip(
                    label: 'Most active today',
                    value: mostActiveToday == null
                        ? 'No data yet'
                        : '${mostActiveToday.name} • ${mostActiveToday.todayEvents} completions',
                  ),
                  _PulseChip(
                    label: 'Top task today',
                    value: topTaskToday == null || topTaskTodayCompletions == 0
                        ? 'No completions yet'
                        : '${topTaskToday.title} • $topTaskTodayCompletions',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardMemberRow {
  final String uid;
  final String name;
  final String? photoUrl;
  final int score;
  final int todayEvents;
  final int weekEvents;
  final int allEvents;
  final int weekActiveDays;

  const _LeaderboardMemberRow({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.score,
    required this.todayEvents,
    required this.weekEvents,
    required this.allEvents,
    required this.weekActiveDays,
  });
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final _LeaderboardMemberRow row;
  final String metricLabel;

  const _LeaderboardTile({
    required this.rank,
    required this.row,
    required this.metricLabel,
  });

  IconData _rankIcon(int rank) {
    if (rank == 1) return Icons.emoji_events_rounded;
    if (rank == 2) return Icons.workspace_premium_rounded;
    if (rank == 3) return Icons.military_tech_rounded;
    return Icons.tag_rounded;
  }

  Color _rankColor(BuildContext context, int rank) {
    if (rank == 1) return const Color(0xFFFFC107);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(_rankIcon(rank), color: _rankColor(context, rank), size: 20),
          const HGap(10),
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
            backgroundImage:
                row.photoUrl != null && row.photoUrl!.trim().isNotEmpty
                ? NetworkImage(row.photoUrl!.trim())
                : null,
            child: row.photoUrl != null && row.photoUrl!.trim().isNotEmpty
                ? null
                : Text(
                    (row.name.isEmpty ? '?' : row.name[0]).toUpperCase(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
          ),
          const HGap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${row.todayEvents} today • ${row.weekEvents} week • ${row.allEvents} total',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${row.score}',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const HGap(4),
          Text(
            metricLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
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
