import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/group_challenge.dart';
import '../models/user_profile.dart';
import '../providers/group_interaction_provider.dart';
import '../utils/quantity_format.dart';

class ChallengeActivitySheet {
  static double _getLoggedValue(GroupChallenge challenge, String userId, DateTime day) {
    final logs = challenge.progressLogs[userId] ?? const <String, double>{};
    return logs[challenge.dateKeyFor(day)] ?? 0.0;
  }

  static Future<void> show(
    BuildContext context,
    GroupChallenge challenge,
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
              final scheme = Theme.of(context).colorScheme;
              final focusedDay = sheetProvider.focusedDay;
              
              double totalForMonth = 0;
              final logs = challenge.progressLogs[user.uid] ?? const <String, double>{};
              logs.forEach((key, value) {
                try {
                  final parts = key.split('-');
                  if (parts.length == 3) {
                    final y = int.parse(parts[0]);
                    final m = int.parse(parts[1]);
                    if (y == focusedDay.year && m == focusedDay.month) {
                      totalForMonth += value;
                    }
                  }
                } catch (_) {}
              });
              
              final totalTrackableDays = challenge.endAt.difference(challenge.startAt).inDays + 1;

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
                        'For ${challenge.title}',
                        style: GoogleFonts.inter(
                          color: scheme.onSurface.withValues(alpha: 0.68),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TableCalendar<DateTime>(
                        firstDay: challenge.startAt,
                        lastDay: challenge.endAt,
                        focusedDay: focusedDay,
                        onPageChanged: (newMonth) {
                          sheetProvider.setFocusedDay(newMonth);
                        },
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          weekendTextStyle: GoogleFonts.inter(
                            color: scheme.onSurface.withValues(alpha: 0.8),
                          ),
                          defaultTextStyle: GoogleFonts.inter(
                            color: scheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          weekendStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            return _buildDayCell(
                              context,
                              day,
                              challenge,
                              user.uid,
                            );
                          },
                          todayBuilder: (context, day, focusedDay) {
                            return _buildDayCell(
                              context,
                              day,
                              challenge,
                              user.uid,
                              isToday: true,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MONTH TOTAL',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    challenge.hasTarget
                                        ? '${formatQuantity(totalForMonth, maxDecimals: 1)} ${challenge.unit}'
                                        : '${formatQuantity(totalForMonth, maxDecimals: 1)} logs',
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  static Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    GroupChallenge challenge,
    String userId, {
    bool isToday = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final value = _getLoggedValue(challenge, userId, day);
    final hasLogged = value > 0;
    
    // Determine color based on target achievement
    final targetVal = challenge.hasTarget ? challenge.targetValue : 1.0;
    final progressVal = hasLogged ? value : 0.0;
    final achieved = challenge.hasTarget ? (progressVal >= targetVal) : hasLogged;
    
    final Color? bgColor;
    final Color textColor;
    
    if (hasLogged) {
      if (achieved) {
        bgColor = scheme.primary.withValues(alpha: 0.25);
        textColor = scheme.primary;
      } else {
        bgColor = scheme.secondary.withValues(alpha: 0.15);
        textColor = scheme.secondary;
      }
    } else {
      if (isToday) {
        bgColor = scheme.onSurface.withValues(alpha: 0.08);
      } else {
        bgColor = Colors.transparent;
      }
      textColor = scheme.onSurface.withValues(alpha: 0.6);
    }
    
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: isToday && !hasLogged ? Border.all(color: scheme.onSurface.withValues(alpha: 0.15)) : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textColor,
            ),
          ),
          if (hasLogged && !achieved)
            Text(
              formatQuantity(value, maxDecimals: 0),
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
        ],
      )
    );
  }
}
