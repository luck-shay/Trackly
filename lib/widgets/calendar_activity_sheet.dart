import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../providers/group_interaction_provider.dart';

class CalendarActivitySheet {
  static Set<DateTime> _normalizedCompletionSet(Habit habit, String userId) {
    final entries = habit.completions[userId] ?? const <DateTime>[];
    return entries.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  }

  static int _completedDaysInMonth(Set<DateTime> completions, DateTime month) {
    return completions
        .where((d) => d.year == month.year && d.month == month.month)
        .length;
  }

  static int _trackableDaysInMonth(Habit habit, DateTime month) {
    final now = DateTime.now();
    final firstTrackableDay = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(
      month.year,
      month.month,
      DateUtils.getDaysInMonth(month.year, month.month),
    );
    final lastTrackableDay =
        month.year == now.year && month.month == now.month
            ? DateTime(now.year, now.month, now.day)
            : monthEnd;

    if (lastTrackableDay.isBefore(firstTrackableDay) ||
        lastTrackableDay.isBefore(monthStart)) {
      return 0;
    }

    final effectiveStart = firstTrackableDay.isAfter(monthStart)
        ? firstTrackableDay
        : monthStart;
    return lastTrackableDay.difference(effectiveStart).inDays + 1;
  }

  static Future<void> show(
    BuildContext context,
    Habit habit,
    UserProfile user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => MemberActivitySheetProvider(),
          child: Consumer<MemberActivitySheetProvider>(
            builder: (context, sheetProvider, _) {
              final focusedDay = sheetProvider.focusedDay;
              final completions = _normalizedCompletionSet(habit, user.uid);
              final completed = _completedDaysInMonth(completions, focusedDay);
              final totalTrackable = _trackableDaysInMonth(habit, focusedDay);
              final skipped = (totalTrackable - completed).clamp(
                0,
                totalTrackable,
              );

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.displayName} activity',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'For ${habit.title}',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TableCalendar<DateTime>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: focusedDay,
                        selectedDayPredicate: (_) => false,
                        onPageChanged: sheetProvider.setFocusedDay,
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            final key = DateTime(day.year, day.month, day.day);
                            if (!completions.contains(key)) {
                              return null;
                            }
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                          defaultBuilder: (context, day, _) {
                            final key = DateTime(day.year, day.month, day.day);
                            final isCompleted = completions.contains(key);
                            final now = DateTime.now();
                            final isPastOrToday = !day.isAfter(
                              DateTime(now.year, now.month, now.day),
                            );

                            if (isCompleted) {
                              return Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }

                            if (isPastOrToday &&
                                day.month == focusedDay.month &&
                                day.year == focusedDay.year) {
                              return Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent.withValues(alpha: 0.85),
                                  ),
                                ),
                              );
                            }

                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$completed',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Did (month)',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$skipped',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Skipped (month)',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
