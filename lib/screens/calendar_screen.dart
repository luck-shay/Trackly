import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/habit.dart';
import '../providers/calendar_provider.dart';
import '../services/database_service.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarProvider(),
      child: const _CalendarView(),
    );
  }
}

enum _CalendarScope { mine, team }

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  _CalendarScope _scope = _CalendarScope.mine;

  List<Habit> _getEventsForDay(DateTime day, List<Habit> habits) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return habits.where((habit) {
      if (_scope == _CalendarScope.mine) {
        final userCompletions = habit.completions[uid] ?? [];
        return userCompletions.any(
          (d) => d.year == day.year && d.month == day.month && d.day == day.day,
        );
      }

      if (habit.participants.length <= 1) {
        return false;
      }

      return habit.participants.any((participantId) {
        final participantCompletions = habit.completions[participantId] ?? [];
        return participantCompletions.any(
          (d) => d.year == day.year && d.month == day.month && d.day == day.day,
        );
      });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Activity History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        
      ),
      body: StreamBuilder<List<Habit>>(
        stream: db.streamHabits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final habits = snapshot.data ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('My activity'),
                      selected: _scope == _CalendarScope.mine,
                      onSelected: (_) {
                        setState(() => _scope = _CalendarScope.mine);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Shared activity'),
                      selected: _scope == _CalendarScope.team,
                      onSelected: (_) {
                        setState(() => _scope = _CalendarScope.team);
                      },
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Consumer<CalendarProvider>(
                  builder: (context, calendarProvider, child) {
                    return TableCalendar<Habit>(
                      firstDay: DateTime.utc(2020, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: calendarProvider.focusedDay,
                      selectedDayPredicate: (day) {
                        return isSameDay(calendarProvider.selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        if (!isSameDay(
                          calendarProvider.selectedDay,
                          selectedDay,
                        )) {
                          context.read<CalendarProvider>().selectDay(
                            selectedDay,
                            focusedDay,
                          );
                        }
                      },
                      eventLoader: (day) => _getEventsForDay(day, habits),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.inter(
                          color: Colors.grey[500]!,
                          fontWeight: FontWeight.w600,
                        ),
                        weekendStyle: GoogleFonts.inter(
                          color: Colors.grey[600]!,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: GoogleFonts.inter(
                          color: Colors.white,
                        ),
                        weekendTextStyle: GoogleFonts.inter(
                          color: Colors.grey[400]!,
                        ),
                        outsideTextStyle: GoogleFonts.inter(
                          color: Colors.grey[800]!,
                        ),
                        markerDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.inter(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fade().scaleXY(begin: 0.95),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'COMPLETED HABITS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ).animate().fade(delay: 200.ms),
                ),
              ),
              Expanded(
                child: Consumer<CalendarProvider>(
                  builder: (context, calendarProvider, child) {
                    if (calendarProvider.selectedDay == null) {
                      return Center(
                        child: Text(
                          'Select a day to view your progress.',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                      ).animate().fade(delay: 300.ms);
                    }

                    return _buildEventList(
                      context,
                      _getEventsForDay(calendarProvider.selectedDay!, habits),
                      calendarProvider.selectedDay!,
                    );
                  },
                ),
              ),
              const SizedBox(height: 120),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    List<Habit> completedHabits,
    DateTime selectedDay,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (completedHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_rounded, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              _scope == _CalendarScope.mine
                  ? 'No routines completed this day.'
                  : 'No shared completions on this day.',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ],
        ),
      ).animate().fade();
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: completedHabits.length,
      itemBuilder: (context, index) {
        final habit = completedHabits[index];
        final dayParticipantsCompleted = habit.participants.where((participantId) {
          final completions = habit.completions[participantId] ?? const <DateTime>[];
          return completions.any(
            (d) =>
                d.year == selectedDay.year &&
                d.month == selectedDay.month &&
                d.day == selectedDay.day,
          );
        }).length;
        final participationSummary = _scope == _CalendarScope.mine
            ? '${habit.currentStreakFor(uid)} 🔥'
            : '$dayParticipantsCompleted/${habit.participants.length} members';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              habit.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            trailing: Text(
              participationSummary,
              style: GoogleFonts.outfit(
                color: _scope == _CalendarScope.mine
                    ? Colors.orange
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.1);
      },
    );
  }
}
