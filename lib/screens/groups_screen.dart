import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../models/group_invite.dart';
import '../providers/habits_provider.dart';
import '../screens/create_habit_screen.dart';
import '../screens/habit_leaderboard_screen.dart';
import '../services/social_service.dart';
import '../theme/app_layout.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final social = SocialService();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Groups',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<HabitsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
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

          final groupHabits =
              provider.habits.where((habit) => habit.isGroup).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                        'Shared structure for teams, friends, and premium communities.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const VGap(AppLayout.md),
                      Row(
                        children: [
                          _StatPill(
                            label: 'Groups',
                            value: groupHabits.length.toString(),
                            icon: Icons.groups_rounded,
                          ),
                          const HGap(AppLayout.sm),
                          _StatPill(
                            label: 'People',
                            value: groupHabits.isEmpty
                                ? '0'
                                : groupHabits
                                      .fold<int>(
                                        0,
                                        (sum, habit) =>
                                            sum + habit.participants.length,
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
                              margin: const EdgeInsets.only(
                                bottom: AppLayout.sm,
                              ),
                              padding: const EdgeInsets.all(AppLayout.md),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
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
                                      color: Colors.grey[500],
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
                                              await social.declineGroupInvite(
                                                invite.id,
                                              );
                                            } catch (_) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                            } catch (_) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not accept invite. Please try again.',
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
              if (groupHabits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.lg,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.08),
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
                            'Create a group for a premium shared experience with richer coordination and verification.',
                            style: GoogleFonts.inter(
                              color: Colors.grey[500],
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateHabitScreen(
                                      initialSpaceType: HabitSpaceType.group,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create a group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: groupHabits.length + 1,
                  separatorBuilder: (context, index) => const VGap(0),
                  itemBuilder: (context, index) {
                    if (index == groupHabits.length) {
                      return const VGap(140);
                    }

                    final habit = groupHabits[index];
                    final myTask = habit.taskFor(provider.userId);
                    final myHasTask = myTask.trim().isNotEmpty;
                    final myIsQuantified = habit.isQuantifiedFor(
                      provider.userId,
                    );
                    final taskModeLabel = habit.hasMemberDefinedGroupTasks
                        ? 'Member-defined tasks'
                        : 'Single shared task';

                    return Container(
                      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
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
                                builder: (_) =>
                                    HabitLeaderboardScreen(habit: habit),
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
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
                                            habit.displayTitle,
                                            style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${habit.participants.length} members',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey[500],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
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
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        taskModeLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[300],
                                        ),
                                      ),
                                    ),
                                    if (habit.hasMemberDefinedGroupTasks)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: myIsQuantified
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.18)
                                              : Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          myIsQuantified
                                              ? 'My task: quantified'
                                              : 'My task: checkbox',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: myIsQuantified
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  habit.hasMemberDefinedGroupTasks
                                      ? (myHasTask
                                            ? 'My task: $myTask'
                                            : 'No personal task set yet. Tap to set your task and log progress.')
                                      : 'Shared task: ${habit.title}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey[400],
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    
                                   
                                    
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fade().slideY(begin: 0.08);
                  },
                ),
            ],
          );
        },
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    color: Colors.grey[500],
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
