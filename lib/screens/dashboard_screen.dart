import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/habit.dart';
import '../widgets/habit_card.dart';
import '../services/database_service.dart';
import 'create_habit_screen.dart';
import 'calendar_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _db = DatabaseService();

  Future<void> _toggleHabitCompletion(Habit habit) async {
    DateTime now = DateTime.now();
    bool foundToday = false;
    
    for (int i = 0; i < habit.completionDates.length; i++) {
        var date = habit.completionDates[i];
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          habit.completionDates.removeAt(i);
          foundToday = true;
          break;
        }
    }
    
    if (!foundToday) {
      habit.completionDates.add(now);
    }

    // Save back to Firestore
    await _db.saveHabit(habit);
  }

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0, bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                      Text(
                        'Your Habits',
                        style: GoogleFonts.outfit(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ).animate().fade(duration: 500.ms, delay: 100.ms).slideX(begin: -0.1),
                    ],
                  ),
                  StreamBuilder<List<Habit>>(
                    stream: _db.streamHabits(),
                    builder: (context, snapshot) {
                      final habits = snapshot.data ?? [];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, size: 28),
                          color: Colors.white70,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CalendarScreen(habits: habits),
                              ),
                            );
                          },
                        ),
                      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
                    }
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Habit>>(
                stream: _db.streamHabits(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                  }

                  final habits = snapshot.data ?? [];

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

                  // Sort habits logically or sequentially
                  habits.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                    itemCount: habits.length,
                    itemBuilder: (context, index) {
                      final habit = habits[index];
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
                          _db.deleteHabit(habit.id);
                        },
                        child: HabitCard(
                          habit: habit,
                          onCheck: () => _toggleHabitCompletion(habit),
                        ).animate().fade(delay: (50 * index).ms).slideY(begin: 0.2),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newHabit = await Navigator.push<Habit>(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const CreateHabitScreen(),
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
          if (newHabit != null) {
            await _db.saveHabit(newHabit);
          }
        },
        child: const Icon(Icons.add, size: 36),
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
