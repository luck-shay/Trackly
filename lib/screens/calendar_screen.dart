import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/habit.dart';
import '../providers/calendar_provider.dart';
import '../providers/habits_provider.dart';

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

  bool _isCompletedForDay(
    Habit habit,
    String userId,
    DateTime day,
  ) {
    if (userId.isEmpty) {
      return false;
    }
    return habit.completionProgressFor(userId, day) >= 1;
  }

  List<Habit> _getEventsForDay(DateTime day, List<Habit> habits) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return habits.where((habit) {
      if (_scope == _CalendarScope.mine) {
        return _isCompletedForDay(habit, uid, day);
      }

      if (habit.participants.length <= 1) {
        return false;
      }

      return _isCompletedForDay(habit, uid, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Activity History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          Consumer<CalendarProvider>(
            builder: (context, calendarProvider, child) {
              return TextButton(
                onPressed: calendarProvider.goToToday,
                child: Text(
                  'Today',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<HabitsProvider>(
        builder: (context, habitsProvider, _) {
          if (habitsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (habitsProvider.error != null) {
            return Center(
              child: Text(
                'Error: ${habitsProvider.error}',
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final habits = habitsProvider.habits;

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
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.08),
                  ),
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
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                        weekendStyle: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: GoogleFonts.inter(
                          color: scheme.onSurface,
                        ),
                        weekendTextStyle: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                        outsideTextStyle: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.35),
                        ),
                        markerDecoration: BoxDecoration(
                          color: scheme.secondary,
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
                          color: scheme.onPrimary,
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
                      color: scheme.onSurface.withValues(alpha: 0.55),
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
                          style: GoogleFonts.inter(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
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
        final dayParticipantsCompleted = habit.participants.where((
          participantId,
        ) {
          return _isCompletedForDay(habit, participantId, selectedDay);
        }).length;
        final participationSummary = _scope == _CalendarScope.mine
            ? '${habit.currentStreakFor(uid)} 🔥'
            : '$dayParticipantsCompleted/${habit.participants.length} members';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
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
