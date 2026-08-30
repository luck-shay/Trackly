import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group.dart';
import '../models/group_invite.dart';
import '../models/group_task.dart';
import '../services/subscription_constants.dart';
import '../services/subscription_exceptions.dart';
import '../services/group_service.dart';
import '../services/premium_feature_guard.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';
import '../widgets/premium_upgrade_sheet.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _activeTodayCount(Group group, List<GroupTask> tasks) {
    final now = DateTime.now();
    final activeMembers = <String>{};
    for (final task in tasks) {
      task.completions.forEach((uid, dates) {
        final completedToday = dates.any((date) => _isSameDay(date, now));
        if (completedToday) {
          activeMembers.add(uid);
        }
      });
    }
    return activeMembers.where(group.memberIds.contains).length;
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    final canCreate = await requirePremiumFeatureAccess(
      context,
      feature: PremiumFeature.unlimitedGroups,
    );
    if (!context.mounted || !canCreate) {
      return;
    }

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );

    if (!context.mounted || result == null) {
      return;
    }

    final data = result is Map<String, dynamic>
        ? result
        : (result is Map ? Map<String, dynamic>.from(result) : null);
    if (data == null) {
      return;
    }

    final message = data['snackbarMessage'];
    if (message is String && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = SocialService();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Groups',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Group>>(
        stream: GroupService().streamGroupsForCurrentUser(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: scheme.primary),
            );
          }

          final groups = groupSnapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.lg,
                    20,
                    AppLayout.lg,
                    AppLayout.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create communities and manage multiple tasks in each group.',
                        style: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.68),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const VGap(AppLayout.md),
                      Row(
                        children: [
                          _StatPill(
                            label: 'Groups',
                            value: groups.length.toString(),
                            icon: Icons.groups_rounded,
                          ),
                          const HGap(AppLayout.sm),
                          _StatPill(
                            label: 'Members',
                            value: groups.isEmpty
                                ? '0'
                                : groups
                                      .fold<int>(
                                        0,
                                        (sum, group) => sum + group.memberIds.length,
                                      )
                                      .toString(),
                            icon: Icons.people_alt_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: StreamBuilder(
                  stream: social.streamGroupInvites(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final invites = snapshot.data!.docs
                        .map(
                          (doc) => GroupInvite.fromMap(
                            doc.data() as Map<String, dynamic>,
                            id: doc.id,
                          ),
                        )
                        .toList();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.lg,
                        0,
                        AppLayout.lg,
                        AppLayout.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending invites',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const VGap(AppLayout.sm),
                          ...invites.map((invite) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppLayout.sm),
                              padding: const EdgeInsets.all(AppLayout.md),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: scheme.onSurface.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invite.groupName?.isNotEmpty == true
                                        ? invite.groupName!
                                        : 'Group invite',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const VGap(AppLayout.xxs),
                                  Text(
                                    'You were invited to join this group.',
                                    style: GoogleFonts.inter(
                                      color: scheme.onSurface.withValues(alpha: 0.68),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const VGap(14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            try {
                                              await social.declineGroupInvite(invite.id);
                                            } catch (_) {
                                              if (!context.mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not decline invite. Please try again.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Decline'),
                                        ),
                                      ),
                                      const HGap(AppLayout.sm),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              await social.acceptGroupInvite(
                                                invite.id,
                                                invite.groupId,
                                              );
                                            } on UpgradeRequiredException catch (
                                              error
                                            ) {
                                              if (!context.mounted) {
                                                return;
                                              }
                                              await showPremiumUpgradeSheet(
                                                context,
                                                feature: PremiumFeature.unlimitedGroups,
                                              );
                                              if (!context.mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(error.message),
                                                ),
                                              );
                                            } catch (_) {
                                              if (!context.mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not accept invite. Please try again.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Theme.of(context).colorScheme.primary,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text('Accept'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (groups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppLayout.lg),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.08),
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              size: 72,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ).animate().scaleXY(end: 1.05, duration: 1.8.seconds),
                          const VGap(28),
                          Text(
                            'No groups yet',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const VGap(10),
                          Text(
                            'Create a group and manage multiple tasks in one shared place.',
                            style: GoogleFonts.inter(
                              color: scheme.onSurface.withValues(alpha: 0.68),
                              fontSize: 15,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const VGap(28),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () => _openCreateGroup(context),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create a group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const VGap(110),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: groups.length + 1,
                  separatorBuilder: (context, index) => const VGap(0),
                  itemBuilder: (context, index) {
                    if (index == groups.length) {
                      return const VGap(140);
                    }

                    final group = groups[index];
                    return StreamBuilder<List<GroupTask>>(
                      stream: GroupService().streamGroupTasks(group.id),
                      builder: (context, taskSnapshot) {
                        final tasks = taskSnapshot.data ?? const <GroupTask>[];
                        final activeToday = _activeTodayCount(group, tasks);

                        return Container(
                          margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: scheme.onSurface.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GroupDetailScreen(group: group),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.14),
                                          ),
                                          child: Icon(
                                            Icons.groups_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                group.name,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${group.memberIds.length} members',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: scheme.onSurface.withValues(alpha: 0.68),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: scheme.onSurface.withValues(alpha: 0.58),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _MetricChip(label: 'Tasks', value: '${tasks.length}'),
                                        _MetricChip(
                                          label: 'Active today',
                                          value: '$activeToday/${group.memberIds.length}',
                                        ),
                                      ],
                                    ),
                                    if (group.description.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        group.description,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: scheme.onSurface.withValues(alpha: 0.64),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fade().slideY(begin: 0.08);
                      },
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
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
