import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';

class HabitLeaderboardScreen extends StatefulWidget {
  final Habit habit;

  const HabitLeaderboardScreen({super.key, required this.habit});

  @override
  State<HabitLeaderboardScreen> createState() => _HabitLeaderboardScreenState();
}

class _HabitLeaderboardScreenState extends State<HabitLeaderboardScreen> {
  final SocialService _social = SocialService();

  Future<List<UserProfile>> _fetchParticipants() async {
    List<UserProfile> list = [];
    for (String uid in widget.habit.participants) {
      final profile = await _social.getUserProfile(uid);
      if (profile != null) {
        list.add(profile);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
                        widget.habit.title,
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.habit.participants.length} Participant${widget.habit.participants.length != 1 ? 's' : ''}',
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
            child: FutureBuilder<List<UserProfile>>(
              future: _fetchParticipants(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(child: Text('Error loading leaderboard.'));
                }

                final participants = snapshot.data!;

                // Sort descending by current streak
                participants.sort((a, b) {
                  final streakA = widget.habit.currentStreakFor(a.uid);
                  final streakB = widget.habit.currentStreakFor(b.uid);
                  // If tie, sort alphabetically by names
                  if (streakA == streakB) {
                    return a.displayName.compareTo(b.displayName);
                  }
                  return streakB.compareTo(streakA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final user = participants[index];
                    final streak = widget.habit.currentStreakFor(user.uid);
                    
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
