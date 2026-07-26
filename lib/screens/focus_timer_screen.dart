// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Focus Timer Screen
// Pomodoro-style focus timer linked to habits.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../models/focus_session.dart';
import '../models/habit.dart';
import '../providers/habits_provider.dart';
import '../theme/category_colors.dart';

class FocusTimerScreen extends StatefulWidget {
  final Habit? linkedHabit;

  const FocusTimerScreen({super.key, this.linkedHabit});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with TickerProviderStateMixin {
  static const List<int> _presetMinutes = [5, 15, 25, 30, 45, 60];

  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isComplete = false;
  Timer? _timer;
  Habit? _selectedHabit;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _selectedHabit = widget.linkedHabit;
    _remainingSeconds = _selectedMinutes * 60;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRunning = true;
      _isComplete = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          _isRunning = false;
          _isComplete = true;
        });
        _saveSession();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _pauseTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isComplete = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  void _setDuration(int minutes) {
    if (_isRunning) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _isComplete = false;
    });
  }

  Future<void> _saveSession() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final session = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      habitId: _selectedHabit?.id,
      habitTitle: _selectedHabit?.title,
      type: FocusSessionType.pomodoro,
      durationSeconds: _selectedMinutes * 60,
      completedAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('focusSessions')
        .doc(session.id)
        .set(session.toMap());
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final totalSeconds = _selectedMinutes * 60;
    if (totalSeconds <= 0) return 0;
    return 1.0 - (_remainingSeconds / totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Focus Timer',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Linked Habit Selector ──
              _buildHabitSelector(scheme, isDark)
                  .animate()
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 40),

              // ── Timer Circle ──
              Expanded(
                child: Center(
                  child: _buildTimerCircle(scheme, isDark)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 500.ms)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        delay: 100.ms,
                        duration: 500.ms,
                      ),
                ),
              ),

              // ── Duration Presets ──
              if (!_isRunning && !_isComplete)
                _buildDurationPresets(scheme, isDark)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 24),

              // ── Controls ──
              _buildControls(scheme, isDark)
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitSelector(ColorScheme scheme, bool isDark) {
    final habits = context.watch<HabitsProvider>().habits;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final personalHabits = habits
        .where((h) =>
            h.spaceType == HabitSpaceType.individual ||
            h.participants.contains(userId))
        .toList();

    return GestureDetector(
      onTap: _isRunning
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                backgroundColor: scheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => _HabitPickerSheet(
                  habits: personalHabits,
                  selected: _selectedHabit,
                  onSelected: (habit) {
                    setState(() => _selectedHabit = habit);
                    Navigator.pop(ctx);
                  },
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121816) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedHabit?.title ?? 'Link to a habit (optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _selectedHabit != null
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCircle(ColorScheme scheme, bool isDark) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: _TimerRingPainter(
                progress: _progress,
                progressColor: _isComplete
                    ? scheme.primary
                    : scheme.primary,
                backgroundColor:
                    scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
                strokeWidth: 8,
              ),
            ),
          ),
          // Time display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isComplete)
                Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: scheme.primary,
                )
              else
                Text(
                  _formattedTime,
                  style: GoogleFonts.outfit(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: 2,
                  ),
                ),
              if (_isComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Session Complete!',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPresets(ColorScheme scheme, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _presetMinutes.map((minutes) {
        final isSelected = _selectedMinutes == minutes;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => _setDuration(minutes),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.15)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: scheme.primary.withValues(alpha: 0.4))
                    : null,
              ),
              child: Text(
                '${minutes}m',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
    );
  }

  Widget _buildControls(ColorScheme scheme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isRunning || _isComplete || _remainingSeconds != _selectedMinutes * 60)
          _ControlButton(
            icon: Icons.stop_rounded,
            label: 'Reset',
            onTap: _resetTimer,
            scheme: scheme,
            isDark: isDark,
            isPrimary: false,
          ),
        const SizedBox(width: 20),
        if (!_isComplete)
          _ControlButton(
            icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: _isRunning ? 'Pause' : 'Start',
            onTap: _isRunning ? _pauseTimer : _startTimer,
            scheme: scheme,
            isDark: isDark,
            isPrimary: true,
          ),
      ],
    );
  }
}

// ── Control Button ──────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool isDark;
  final bool isPrimary;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
    required this.isDark,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isPrimary
                  ? scheme.primary
                  : isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: isPrimary ? Colors.black : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timer Ring Painter ──────────────────────────────────────────────────────

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _TimerRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ── Habit Picker Sheet ──────────────────────────────────────────────────────

class _HabitPickerSheet extends StatelessWidget {
  final List<Habit> habits;
  final Habit? selected;
  final ValueChanged<Habit?> onSelected;

  const _HabitPickerSheet({
    required this.habits,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link to Habit',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completing this timer will mark the habit as done',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            // None option
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: Text(
                'No linked habit',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              selected: selected == null,
              selectedTileColor: scheme.primary.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => onSelected(null),
            ),
            ...habits.map((habit) {
              final isSelected = selected?.id == habit.id;
              return ListTile(
                leading: Icon(
                  CategoryColors.iconForCategory(habit.category),
                  color: CategoryColors.forCategory(habit.category),
                ),
                title: Text(
                  habit.title,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                selected: isSelected,
                selectedTileColor: scheme.primary.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => onSelected(habit),
              );
            }),
          ],
        ),
      ),
    );
  }
}
