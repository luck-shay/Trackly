import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_leaderboard_provider.dart';

class HabitLeaderboardScreen extends StatelessWidget {
  final Habit habit;

  const HabitLeaderboardScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HabitLeaderboardProvider(habit),
      child: const _HabitLeaderboardView(),
    );
  }
}

class _HabitLeaderboardView extends StatelessWidget {
  const _HabitLeaderboardView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitLeaderboardProvider>();
    final habit = provider.habit;

    return Scaffold(
      appBar: AppBar(
        title: Text('Leaderboard', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.leaderboard_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${habit.participants.length} Participant${habit.participants.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
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
                  return Center(child: Text('Error loading leaderboard: ${provider.error}'));
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
                    
                    Color medalColor;
                    Widget? rankBadge;
                    
                    if (index == 0) {
                      medalColor = const Color(0xFFFFD700); // Gold
                      rankBadge = const Text('🥇', style: TextStyle(fontSize: 24));
                    } else if (index == 1) {
                      medalColor = const Color(0xFFC0C0C0); // Silver
                      rankBadge = const Text('🥈', style: TextStyle(fontSize: 24));
                    } else if (index == 2) {
                      medalColor = const Color(0xFFCD7F32); // Bronze
                      rankBadge = const Text('🥉', style: TextStyle(fontSize: 24));
                    } else {
                      medalColor = Colors.grey[800]!;
                      rankBadge = Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text('#${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[500])),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: index == 0 ? medalColor.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                        boxShadow: index == 0 ? [
                          BoxShadow(
                            color: medalColor.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            rankBadge,
                            const SizedBox(width: 16),
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                              child: user.photoUrl == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
                            ),
                          ],
                        ),
                        title: Text(
                          user.displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: index == 0 ? medalColor : Colors.white),
                        ),
                        subtitle: Text(
                          user.username != null ? '@${user.username}' : user.email,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: streak > 0 ? Colors.orange.withOpacity(0.1) : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded, color: streak > 0 ? Colors.orange : Colors.grey[600], size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: streak > 0 ? Colors.orange : Colors.grey[600],
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
