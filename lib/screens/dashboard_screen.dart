import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/habit_card.dart';
import '../providers/habits_provider.dart';
import 'create_habit_screen.dart';
import 'habit_leaderboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = _formatDate(today);

    // Sync user if necessary once on load (normally done at app start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        AuthService().syncUserToFirestore(user);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ).animate().fade(duration: 400.ms).slideX(begin: -0.1),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.track_changes_rounded,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ).animate().fade(duration: 500.ms, delay: 100.ms).scaleXY(begin: 0.8),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Your Habits',
                                  style: GoogleFonts.outfit(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ).animate().fade(duration: 500.ms, delay: 100.ms).slideX(begin: -0.1),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FloatingActionButton(
                    mini: true,
                    elevation: 0,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => CreateHabitScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(0.0, 1.0);
                            const end = Offset.zero;
                            const curve = Curves.easeOutCubic;
                            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            return SlideTransition(position: animation.drive(tween), child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                    child: const Icon(Icons.add),
                  ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
                ],
              ),
            ),
            Expanded(
              child: Consumer<HabitsProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
                  }

                  if (provider.error != null) {
                    return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final habits = provider.habits;

                  if (habits.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                            ),
                            child: Icon(
                              Icons.spa_rounded,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                            ),
                          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                           .scaleXY(end: 1.05, duration: 2.seconds, curve: Curves.easeInOut),
                          const SizedBox(height: 32),
                          Text(
                            'It\'s mighty quiet here.',
                            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600),
                          ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
                          const SizedBox(height: 12),
                          Text(
                            'Tap the + icon to build better routines.',
                            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
                          ).animate().fade(delay: 400.ms),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                    itemCount: habits.length,
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      // Provide a unique global key directly to the container to stabilize the entry animation
                      return Dismissible(
                        key: Key(habit.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 30),
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
                        ),
                        onDismissed: (direction) {
                          provider.deleteHabit(habit.id);
                        },
                        child: HabitCard(
                          habit: habit,
                          currentUserId: provider.userId,
                          onCheck: () => provider.toggleHabitCompletion(habit),
                          onCardTap: () {
                            if (habit.participants.length > 1) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HabitLeaderboardScreen(habit: habit),
                                ),
                              );
                            }
                          },
                        ).animate(key: ValueKey('anim_${habit.id}')).fade().slideY(begin: 0.2), // Removed dynamic index delay to prevent re-shuffling stutters
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

