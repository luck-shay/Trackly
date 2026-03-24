import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/habit.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final VoidCallback onCheck;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onCheck,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 200.ms);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool completedToday = false;
    DateTime now = DateTime.now();
    for (var date in widget.habit.completionDates) {
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        completedToday = true;
        break;
      }
    }

    if (completedToday) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: completedToday 
            ? Theme.of(context).colorScheme.surface.withOpacity(0.8)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: completedToday 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.05)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            widget.onCheck();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Animated Checkbox
                GestureDetector(
                  onTap: () {
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
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.transparent,
                      border: Border.all(
                        color: completedToday 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey[600]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: completedToday
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 20)
                              .animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.habit.title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: completedToday ? Colors.grey[300] : Colors.white,
                          decoration: completedToday ? TextDecoration.lineThrough : null,
                          decorationColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (widget.habit.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.habit.description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Streak indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.habit.currentStreak > 0 
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded, 
                        color: widget.habit.currentStreak > 0 ? Colors.orange : Colors.grey[600], 
                        size: 20
                      )
                      .animate(
                        target: (widget.habit.currentStreak >= 2 && completedToday) ? 1 : 0,
                      ).scaleXY(end: 1.2, duration: 200.ms).then().scaleXY(end: 1.0, duration: 200.ms),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.habit.currentStreak}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: widget.habit.currentStreak > 0 ? Colors.orange : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
