import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/habit.dart';

class CalendarScreen extends StatefulWidget {
  final List<Habit> habits;

  const CalendarScreen({super.key, required this.habits});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Determine which habits were completed on a given day
  List<Habit> _getEventsForDay(DateTime day) {
    return widget.habits.where((habit) {
      return habit.completionDates.any((d) => 
        d.year == day.year && d.month == day.month && d.day == day.day
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Activity History', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: TableCalendar<Habit>(
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              eventLoader: _getEventsForDay,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                // iconContainerPadding: EdgeInsets.zero,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: GoogleFonts.inter(color: Colors.grey[500]!, fontWeight: FontWeight.w600),
                weekendStyle: GoogleFonts.inter(color: Colors.grey[600]!, fontWeight: FontWeight.w600),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: GoogleFonts.inter(color: Colors.white),
                weekendTextStyle: GoogleFonts.inter(color: Colors.grey[400]!),
                outsideTextStyle: GoogleFonts.inter(color: Colors.grey[800]!),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
            ),
          ).animate().fade().scaleXY(begin: 0.95),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COMPLETED HABITS',
                style: GoogleFonts.inter(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey[500],
                  letterSpacing: 1.2
                ),
              ).animate().fade(delay: 200.ms),
            ),
          ),
          Expanded(
            child: _selectedDay == null 
              ? Center(
                  child: Text(
                    'Select a day to view your progress.',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                ).animate().fade(delay: 300.ms)
              : _buildEventList(_getEventsForDay(_selectedDay!)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(List<Habit> completedHabits) {
    if (completedHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_rounded, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              'No routines completed this day.',
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            title: Text(
              habit.title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            trailing: Text(
              '${habit.currentStreak} 🔥',
              style: GoogleFonts.outfit(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.1);
      },
    );
  }
}
