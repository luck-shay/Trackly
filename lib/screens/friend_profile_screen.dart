import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../providers/habits_provider.dart';
import '../services/social_service.dart';
import '../widgets/calendar_activity_sheet.dart';

class FriendProfileScreen extends StatefulWidget {
  final UserProfile friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final SocialService _socialService = SocialService();
  bool _isRemovingFriend = false;

  Future<void> _onUnfriendPressed() async {
    if (_isRemovingFriend) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unfriend'),
          content: Text(
            'Remove ${widget.friend.displayName} from your friends list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Unfriend', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isRemovingFriend = true);
    try {
      await _socialService.removeFriend(widget.friend.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You unfriended ${widget.friend.displayName}.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not unfriend right now. Please try again.'),
        ),
      );
      setState(() => _isRemovingFriend = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final friend = widget.friend;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${friend.displayName}\'s Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Unfriend',
            onPressed: _isRemovingFriend ? null : _onUnfriendPressed,
            icon: _isRemovingFriend
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_remove_alt_1_rounded),
            color: Colors.redAccent,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            backgroundImage: friend.photoUrl != null
                ? NetworkImage(friend.photoUrl!)
                : null,
            child: friend.photoUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 48)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            friend.displayName,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            friend.email,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Consumer<HabitsProvider>(
              builder: (context, habitsProvider, _) {
                if (habitsProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (habitsProvider.error != null) {
                  return Center(
                    child: Text(
                      'Could not load shared goals.',
                      style: GoogleFonts.inter(color: Colors.redAccent),
                    ),
                  );
                }

                final habits =
                    habitsProvider.habits
                        .where(
                          (habit) => habit.participants.contains(friend.uid),
                        )
                        .toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final sharedGoals =
                    habits.where((habit) => !habit.isGroup).toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final commonGroupsByKey = <String, List<Habit>>{};
                for (final habit in habits.where((h) => h.isGroup)) {
                  final byEntityId = (habit.groupEntityId ?? '').trim();
                  final byGroupName = (habit.groupName ?? '').trim();
                  final key = byEntityId.isNotEmpty
                      ? byEntityId
                      : byGroupName.isNotEmpty
                      ? byGroupName.toLowerCase()
                      : habit.id;

                  commonGroupsByKey
                      .putIfAbsent(key, () => <Habit>[])
                      .add(habit);
                }

                final commonGroups = commonGroupsByKey.values.toList()
                  ..sort(
                    (a, b) => b.first.createdAt.compareTo(a.first.createdAt),
                  );

                if (sharedGoals.isEmpty && commonGroups.isEmpty) {
                  return Center(
                    child: Text(
                      'No shared goals or common groups yet.',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Shared Goals',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sharedGoals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'No shared goals yet.',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      )
                    else
                      ...sharedGoals.map((habit) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: InkWell(
                            onTap: () {
                              CalendarActivitySheet.show(
                                context,
                                habit,
                                friend,
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          habit.displayTitle,
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_month_rounded,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  if (habit.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      habit.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStreakColumn(
                                        context,
                                        'You',
                                        habit.currentStreakFor(currentUserId),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.white10,
                                      ),
                                      _buildStreakColumn(
                                        context,
                                        friend.displayName,
                                        habit.currentStreakFor(friend.uid),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Common Groups',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (commonGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'No common groups yet.',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      )
                    else
                      ...commonGroups.map((groupHabits) {
                        final representative = groupHabits.first;
                        final groupTitle =
                            (representative.groupName ?? '').trim().isNotEmpty
                            ? representative.groupName!.trim()
                            : representative.displayTitle;

                        final yourCombinedStreak = groupHabits.fold<int>(
                          0,
                          (sum, habit) =>
                              sum + habit.currentStreakFor(currentUserId),
                        );
                        final friendCombinedStreak = groupHabits.fold<int>(
                          0,
                          (sum, habit) =>
                              sum + habit.currentStreakFor(friend.uid),
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        groupTitle,
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
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
                                        '${groupHabits.length} task${groupHabits.length == 1 ? '' : 's'}',
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
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStreakColumn(
                                      context,
                                      'You',
                                      yourCombinedStreak,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white10,
                                    ),
                                    _buildStreakColumn(
                                      context,
                                      friend.displayName,
                                      friendCombinedStreak,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakColumn(BuildContext context, String name, int streak) {
    return Column(
      children: [
        Text(name, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: streak > 0 ? Colors.orange : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
