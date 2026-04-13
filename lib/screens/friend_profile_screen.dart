import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/habits_provider.dart';
import '../widgets/calendar_activity_sheet.dart';

class FriendProfileScreen extends StatelessWidget {
  final UserProfile friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${friend.displayName}\'s Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
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
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            friend.email,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shared Goals',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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

                final habits = habitsProvider.habits
                    .where((habit) => habit.participants.contains(friend.uid))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (habits.isEmpty) {
                  return Center(
                    child: Text(
                      'No shared goals yet.',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: habits.length,
                  itemBuilder: (context, index) {
                    final habit = habits[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: InkWell(
                        onTap: () {
                          CalendarActivitySheet.show(context, habit, friend);
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.grey),
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
                  },
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
        Text(
          name,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
        ),
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
