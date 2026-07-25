import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/habit.dart';
import '../theme/category_colors.dart';
import '../utils/quantity_format.dart';
import 'habit_checklist_sheet.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final VoidCallback onCheck;
  final VoidCallback? onCardTap;
  final String currentUserId;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool showShadow;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onCheck,
    this.onCardTap,
    required this.currentUserId,
    this.margin = const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    this.borderRadius = 24,
    this.showShadow = true,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    DateTime now = DateTime.now();
    final streak = widget.habit.currentStreakFor(widget.currentUserId);
    final groupTaskTitle = widget.habit.hasMemberDefinedGroupTasks
        ? (widget.habit.taskFor(widget.currentUserId).trim().isEmpty
              ? 'No personal task set yet'
              : widget.habit.taskFor(widget.currentUserId).trim())
        : widget.habit.title;
    final primaryTitle = widget.habit.isGroup
        ? groupTaskTitle
        : widget.habit.displayTitle;
    final groupLabel = (widget.habit.groupName ?? '').trim();
    final todayValue = widget.habit.completionValueFor(
      widget.currentUserId,
      now,
    );
    final quantProgress = widget.habit.completionProgressFor(
      widget.currentUserId,
      now,
    );
    final quantProgressPct = (quantProgress * 100).round();
    final userIsQuantified = widget.habit.isQuantifiedFor(widget.currentUserId);
    final userQuantUnit = widget.habit.quantUnitFor(widget.currentUserId);
    final userQuantMax = widget.habit.quantMaxFor(widget.currentUserId);
    final weeklyCount = widget.habit.weeklyCompletionCountFor(
      widget.currentUserId,
      anchor: now,
    );
    final weeklyTarget = widget.habit.targetDaysPerWeek.clamp(1, 7);
    final weeklyTargetMet = widget.habit.hasMetWeeklyTarget(
      widget.currentUserId,
      anchor: now,
    );
    final reminderTimeText = (widget.habit.reminderTime ?? '').trim();
    final hasReminderTime = reminderTimeText.isNotEmpty;
    final completedToday = widget.habit.isCompletedOnDate(
      widget.currentUserId,
      now,
    );
    final userCompletions =
        widget.habit.completions[widget.currentUserId] ?? [];

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: completedToday
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: completedToday
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.onSurface.withValues(alpha: 0.08),
          width: completedToday ? 1.35 : 1,
        ),
        boxShadow: widget.showShadow
            ? [
                if (completedToday)
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 0.8,
                    offset: const Offset(0, 0),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onCardTap ??
              (widget.habit.checklist.isNotEmpty
                  ? () => HabitChecklistSheet.show(context, widget.habit)
                  : null),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animated Checkbox
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        widget.onCheck();
                      },
                      child: AnimatedContainer(
                        duration: 200.ms,
                        curve: Curves.easeOutCubic,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: completedToday
                              ? scheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: completedToday
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.45),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: 180.ms,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.7,
                                  end: 1.0,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: completedToday
                                ? const Icon(
                                    Icons.check_rounded,
                                    key: ValueKey('completed_icon'),
                                    color: Colors.black,
                                    size: 20,
                                  )
                                : const SizedBox(
                                    key: ValueKey('empty_icon'),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.habit.category != HabitCategory.general ||
                              widget.habit.timeOfDay != HabitTimeOfDay.anytime) ...[
                            Row(
                              children: [
                                if (widget.habit.category != HabitCategory.general)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CategoryColors.forCategory(
                                        widget.habit.category,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CategoryColors.iconForCategory(
                                            widget.habit.category,
                                          ),
                                          size: 12,
                                          color: CategoryColors.forCategory(
                                            widget.habit.category,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.habit.category.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: CategoryColors.forCategory(
                                              widget.habit.category,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.habit.category != HabitCategory.general &&
                                    widget.habit.timeOfDay != HabitTimeOfDay.anytime)
                                  const SizedBox(width: 6),
                                if (widget.habit.timeOfDay != HabitTimeOfDay.anytime)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CategoryColors.colorForTimeOfDay(
                                        widget.habit.timeOfDay,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CategoryColors.iconForTimeOfDay(
                                            widget.habit.timeOfDay,
                                          ),
                                          size: 12,
                                          color: CategoryColors.colorForTimeOfDay(
                                            widget.habit.timeOfDay,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.habit.timeOfDay.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: CategoryColors.colorForTimeOfDay(
                                              widget.habit.timeOfDay,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.habit.checklist.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      HabitChecklistSheet.show(context, widget.habit);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.checklist_rounded,
                                            size: 12,
                                            color: Color(0xFF3B82F6),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${widget.habit.checklist.where((i) => i.isCompleted).length}/${widget.habit.checklist.length}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              if (widget.habit.isGroup) ...[
                                Icon(
                                  Icons.groups_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                              ] else if (widget.habit.participants.length >
                                  1) ...[
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  primaryTitle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: completedToday
                                        ? scheme.onSurface.withValues(
                                            alpha: 0.6,
                                          )
                                        : scheme.onSurface,
                                    decoration: completedToday
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (widget.habit.isGroup &&
                              groupLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Group: $groupLabel',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (widget.habit.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.habit.description,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: scheme.onSurface.withValues(alpha: 0.58),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final pillWidth = (constraints.maxWidth - 8) / 2;
                              final pills = <Widget>[
                                if (!widget.habit.isGroup)
                                  _MetaPill(
                                    label: widget.habit.spaceType.label,
                                    backgroundColor: scheme.onSurface.withValues(
                                      alpha: 0.06,
                                    ),
                                    foregroundColor: scheme.onSurface.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                _MetaPill(
                                  label: widget.habit.isDailyTarget
                                      ? 'Daily target'
                                      : '$weeklyCount/$weeklyTarget this week',
                                  backgroundColor: widget.habit.isDailyTarget
                                      ? scheme.onSurface.withValues(alpha: 0.06)
                                      : (weeklyTargetMet
                                            ? scheme.primary.withValues(
                                                alpha: 0.16,
                                              )
                                            : scheme.onSurface.withValues(
                                                alpha: 0.06,
                                              )),
                                  foregroundColor: widget.habit.isDailyTarget
                                      ? scheme.onSurface.withValues(alpha: 0.72)
                                      : (weeklyTargetMet
                                            ? scheme.primary
                                            : scheme.onSurface.withValues(
                                                alpha: 0.72,
                                              )),
                                ),
                              ];

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final pill in pills)
                                    SizedBox(width: pillWidth, child: pill),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasReminderTime)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_active_rounded,
                                  size: 16,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  reminderTimeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasReminderTime) const SizedBox(height: 10),
                        // Streak indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                streak > 0
                                ? Colors.orange.withValues(alpha: 0.1)
                                : scheme.onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                    Icons.local_fire_department_rounded,
                                    color: streak > 0
                                        ? Colors.orange
                                        : scheme.onSurface.withValues(
                                            alpha: 0.45,
                                          ),
                                    size: 20,
                                  )
                                  .animate(
                                    target: (streak >= 2 && completedToday)
                                        ? 1
                                        : 0,
                                  )
                                  .scaleXY(end: 1.2, duration: 200.ms)
                                  .then()
                                  .scaleXY(end: 1.0, duration: 200.ms),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: streak > 0
                                      ? Colors.orange
                                      : scheme.onSurface.withValues(
                                          alpha: 0.45,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (userIsQuantified) ...[
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${formatQuantity(todayValue ?? 0, maxDecimals: 1)} $userQuantUnit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: completedToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          Text(
                            '${formatQuantity(userQuantMax, maxDecimals: 1)} $userQuantUnit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$quantProgressPct%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: quantProgress.clamp(0.0, 1.0),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ],
                const SizedBox(height: 16),
                // 7-Day History Bubbles
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final day = now.subtract(Duration(days: 6 - index));
                    final isCompleted = userCompletions.any(
                      (d) =>
                          d.year == day.year &&
                          d.month == day.month &&
                          d.day == day.day,
                    );

                    return Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? scheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isCompleted
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _MetaPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}

