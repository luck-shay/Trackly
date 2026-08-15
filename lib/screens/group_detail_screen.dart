import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/group.dart';
import '../models/group_challenge.dart';
import '../models/group_task.dart';
import '../models/user_profile.dart';
import '../providers/habits_provider.dart';
import '../services/group_service.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';
import '../utils/quantity_format.dart';
import 'create_group_challenge_screen.dart';
import 'group_challenge_detail_screen.dart';
import 'create_group_task_screen.dart';

part 'group_detail_insights.dart';
part 'group_detail_members.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _isChallengesExpanded = true;
  bool _isTasksExpanded = false;
  bool _isLeavingGroup = false;

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
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive group?'),
          content: const Text(
            'The group will be moved to Archive. You can restore it anytime with all data from Profile > Archived Habits & Groups.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (shouldArchive != true || !context.mounted) {
      return;
    }

    setState(() {
      _isLeavingGroup = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await GroupService().archiveGroup(group.id);
      if (!context.mounted) {
        return;
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Group moved to Archive.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _isLeavingGroup = false;
      });
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
      await context.read<HabitsProvider>().deleteGroupTask(group.id, task.id);
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
        final liveGroup = snapshot.data;
        final groupMissingFromLiveStream =
            liveGroup == null &&
            snapshot.connectionState != ConnectionState.waiting;
        if (_isLeavingGroup || groupMissingFromLiveStream) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.group.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final group = liveGroup ?? widget.group;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              group.name,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            actions: [
              PopupMenuButton<String>(
                enabled: !_isLeavingGroup,
                onSelected: (value) {
                  if (value == 'leave') {
                    _confirmLeaveGroup(context, group);
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
                        group.description.isEmpty
                            ? 'No description yet.'
                            : group.description,
                        style: GoogleFonts.inter(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                      ),
                      const VGap(AppLayout.sm),
                      Text(
                        '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                      const VGap(AppLayout.xs),
                      TextButton.icon(
                        onPressed: () => _openMembersSheet(context, group),
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
                                  _openInviteMembersSheet(context, group),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Invite'),
                            ),
                          ),
                          const HGap(AppLayout.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _createTask(context, group),
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
                          onPressed: () => _createChallenge(context, group),
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('Start Challenge'),
                        ),
                      ),
                    ],
                  ),
                ),
                const VGap(AppLayout.lg),
                StreamBuilder<List<GroupChallenge>>(
                  stream: GroupService().streamGroupChallenges(group.id),
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
                                        group,
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
                  stream: GroupService().streamGroupTasks(group.id),
                  builder: (context, taskSnapshot) {
                    if (!taskSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tasks = taskSnapshot.data!;
                    final now = DateTime.now();
                    final uid = GroupService().userId;
                    final isGroupAdmin =
                        uid.isNotEmpty && group.memberIds.contains(uid);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GroupPulseCard(group: group, tasks: tasks),
                        const VGap(AppLayout.md),
                        _GroupLeaderboardCard(group: group, tasks: tasks),
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
                                          _createTask(context, group),
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
                                                    group,
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
                                  group,
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
