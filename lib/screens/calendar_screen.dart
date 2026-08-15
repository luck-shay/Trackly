import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/habit.dart';
import '../models/mood_entry.dart';
import '../providers/calendar_provider.dart';
import '../providers/habits_provider.dart';
import '../providers/mood_provider.dart';
import 'mood_journal_screen.dart';

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
  String? _selectedHabitId;

  IconData _getHabitIcon(int? codePoint) {
    if (codePoint == null) return Icons.check_circle_outline_rounded;
    // ignore: non_const_argument_for_const_parameter
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }

  bool _isCompletedForDay(Habit habit, String userId, DateTime day) {
    if (userId.isEmpty) {
      return false;
    }
    return habit.completionProgressFor(userId, day) >= 1;
  }

  List<Habit> _getEventsForDay(DateTime day, List<Habit> habits) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetHabits = _selectedHabitId == null
        ? habits
        : habits.where((h) => h.id == _selectedHabitId).toList();

    return targetHabits.where((habit) {
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
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            );
          }

          final habits = habitsProvider.habits;

          // Deduplicate habits by ID to avoid duplicate DropdownMenuItem keys
          final uniqueHabitsMap = <String, Habit>{};
          for (final h in habits) {
            uniqueHabitsMap[h.id] = h;
          }
          final uniqueHabits = uniqueHabitsMap.values.toList();

          // Ensure selected habit ID exists in current habits list to prevent assertion crash
          final bool selectedHabitExists =
              _selectedHabitId != null &&
              uniqueHabitsMap.containsKey(_selectedHabitId);
          final activeSelectedHabitId = selectedHabitExists
              ? _selectedHabitId
              : null;

          final calendarProvider = context.watch<CalendarProvider>();

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: activeSelectedHabitId != null
                              ? scheme.primary.withValues(alpha: 0.15)
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: activeSelectedHabitId != null
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.15),
                            width: 1.2,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: activeSelectedHabitId,
                            isDense: true,
                            borderRadius: BorderRadius.circular(20),
                            dropdownColor: scheme.surface,
                            icon: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: activeSelectedHabitId != null
                                    ? scheme.primary
                                    : scheme.onSurface.withValues(alpha: 0.7),
                                size: 18,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 16,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'All Habits',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...uniqueHabits.map((habit) {
                                return DropdownMenuItem<String?>(
                                  value: habit.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getHabitIcon(habit.iconCodePoint),
                                        size: 16,
                                        color: habit.colorValue != null
                                            ? Color(habit.colorValue!)
                                            : scheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 160,
                                        ),
                                        child: Text(
                                          habit.displayTitle,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedHabitId = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'My activity',
                        isSelected: _scope == _CalendarScope.mine,
                        onTap: () {
                          setState(() => _scope = _CalendarScope.mine);
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Shared activity',
                        isSelected: _scope == _CalendarScope.team,
                        onTap: () {
                          setState(() => _scope = _CalendarScope.team);
                        },
                      ),
                    ],
                  ),
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
                      rowHeight: 44,
                      daysOfWeekHeight: 20,
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
                        markersMaxCount: 8,
                        markerSize: 6,
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
              if (calendarProvider.selectedDay == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 140),
                  child: Center(
                    child: Text(
                      'Select a day to view your progress.',
                      style: GoogleFonts.inter(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ).animate().fade(delay: 300.ms),
                )
              else ...[
                _buildMoodSection(context, calendarProvider.selectedDay!),
                _buildEventList(
                  context,
                  _getEventsForDay(calendarProvider.selectedDay!, habits),
                  calendarProvider.selectedDay!,
                ),
              ],
              const SizedBox(height: 140),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMoodSection(BuildContext context, DateTime selectedDay) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moodProvider = context.watch<MoodProvider>();

    final dateKey = MoodEntry.dateKey(selectedDay);
    final moodEntry = moodProvider.recentMoods
        .where((m) => m.dateKeyValue == dateKey)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: moodEntry != null
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                moodEntry?.moodLevel.emoji ?? '😶',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moodEntry != null
                          ? 'Mood: ${moodEntry.moodLevel.label}'
                          : 'No mood logged for this day',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (moodEntry != null && moodEntry.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          moodEntry.tags.join(' • '),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MoodJournalScreen(date: selectedDay),
                    ),
                  );
                },
                icon: Icon(
                  moodEntry != null ? Icons.edit_rounded : Icons.add_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                label: Text(
                  moodEntry != null ? 'Edit' : 'Log Mood',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (moodEntry != null && moodEntry.journalText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: isDark ? 0.04 : 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                moodEntry.journalText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
        child: Center(
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
        ).animate().fade(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        children: List.generate(completedHabits.length, (index) {
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
        }),
      ),
    );
  }
}

// ── Filter Pill Widget ────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isSelected
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
