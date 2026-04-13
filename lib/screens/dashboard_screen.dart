import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/habit.dart';
import '../widgets/habit_card.dart';
import '../providers/habits_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/quantified_log_provider.dart';
import '../services/ai_service.dart';
import 'habit_leaderboard_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _showCompletionCelebration(
    BuildContext context,
    HabitsProvider provider,
    Habit habit,
  ) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nice work! "${habit.displayTitle}" completed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.clearTodayProgress(habit);
          },
        ),
      ),
    );
  }

  Future<bool> _runPhotoValidation(BuildContext context, Habit habit) async {
    var loaderShown = false;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile == null) return false;

      if (!context.mounted) return false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      loaderShown = true;

      final isValid = await AIService.validateHabitCompletion(
        habit.title,
        File(pickedFile.path),
      );

      if (loaderShown && context.mounted) {
        Navigator.pop(context); // close loader
        loaderShown = false;
      }

      if (!isValid && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI didn\'t think the photo matches the habit. Try again!',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }

      // In a real app we'd also upload to Storage here to keep a gallery
      return true;
    } catch (_) {
      if (loaderShown && context.mounted) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture/validate photo. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }


  Future<double?> _askQuantifiedValue(
    BuildContext context,
    Habit habit,
    String quantUnit,
    double quantMin,
    double quantMax, {
    double? initialValue,
  }) async {
    final startValue = (initialValue ?? quantMin).clamp(quantMin, quantMax);

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => QuantifiedLogProvider(
            min: quantMin,
            max: quantMax,
            initialValue: startValue,
          ),
          child: Consumer<QuantifiedLogProvider>(
            builder: (context, quantProvider, _) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Log your progress',
                      style: GoogleFonts.outfit(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      habit.title,
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${quantProvider.formattedValue} $quantUnit',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ).animate().scaleXY(begin: 0.9, duration: 200.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              quantProvider.decrement();
                            },
                            icon: const Icon(Icons.remove_rounded, size: 28),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 12,
                              activeTrackColor: Theme.of(context).colorScheme.primary,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                              thumbColor: Colors.white,
                              overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                            ),
                            child: Slider(
                              value: quantProvider.value,
                              min: quantMin,
                              max: quantMax,
                              divisions: quantProvider.divisions,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                quantProvider.setValue(val);
                              },
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              quantProvider.increment();
                            },
                            icon: const Icon(Icons.add_rounded, size: 28),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(sheetContext, quantProvider.value);
                        },
                        child: Text(
                          'Save Progress',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                // bottom: 20.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
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
                        Row(
                          children: [
                            Icon(
                                  Icons.track_changes_rounded,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                                .animate()
                                .fade(duration: 500.ms, delay: 100.ms)
                                .scaleXY(begin: 0.8),
                            const SizedBox(width: 8),
                            Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Your Habits',
                                      style: GoogleFonts.outfit(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                )
                                .animate()
                                .fade(duration: 500.ms, delay: 100.ms)
                                .slideX(begin: -0.1),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      heroTag: 'dashboard_profile_fab',
                      shape: const CircleBorder(),
                      elevation: 0,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.person_rounded, size: 34),
                    ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<HabitsProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00E676),
                      ),
                    );
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Text(
                        'Error: ${provider.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final personalHabits = provider.habits
                      .where((habit) => !habit.isGroup)
                      .toList();
                  final groupHabits = provider.habits
                      .where((habit) => habit.isGroup)
                      .toList();

                  if (personalHabits.isEmpty && groupHabits.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.05),
                                ),
                                child: Icon(
                                  Icons.spa_rounded,
                                  size: 80,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.6),
                                ),
                              )
                              .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true),
                              )
                              .scaleXY(
                                end: 1.05,
                                duration: 2.seconds,
                                curve: Curves.easeInOut,
                              ),
                          const SizedBox(height: 32),
                          Text(
                            'It\'s mighty quiet here.',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
                          const SizedBox(height: 12),
                          Text(
                            'Tap the + icon to build better routines.',
                            style: GoogleFonts.inter(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ).animate().fade(delay: 400.ms),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      try {
                        await context
                            .read<HabitsProvider>()
                            .syncHealthDataForStepsHabits();
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Refresh failed. ${error.toString().split('\n').first}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                      if (groupHabits.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                          child: Text(
                            'GROUPS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...groupHabits.map((habit) {
                          return HabitCard(
                                habit: habit,
                                currentUserId: provider.userId,
                                onCheck: () async {
                                  final now = DateTime.now();
                                  final uid = provider.userId;
                                  final isQuantified = habit.isQuantifiedFor(
                                    uid,
                                  );
                                  final quantMin = habit.quantMinFor(uid);
                                  final quantMax = habit.quantMaxFor(uid);
                                  final quantUnit = habit.quantUnitFor(uid);

                                  if (!isQuantified) {
                                    final wasCompleted = habit.isCompletedOnDate(
                                      provider.userId,
                                      now,
                                    );
                                    if (habit.requiresPhotoValidation && !habit.isCompletedOnDate(provider.userId, now)) {
                                      final aiCheckOk = await _runPhotoValidation(context, habit);
                                      if (!aiCheckOk) return;
                                    }
                                    await provider.toggleHabitCompletion(habit);
                                    if (!wasCompleted && context.mounted) {
                                      await _showCompletionCelebration(
                                        context,
                                        provider,
                                        habit,
                                      );
                                    }
                                    return;
                                  }

                                  if (habit.isCompletedOnDate(
                                    provider.userId,
                                    now,
                                  )) {
                                    await provider.clearTodayProgress(habit);
                                    return;
                                  }

                                  final existingValue = habit
                                      .completionValueFor(provider.userId, now);

                                  final value = await _askQuantifiedValue(
                                    context,
                                    habit,
                                    quantUnit,
                                    quantMin,
                                    quantMax,
                                    initialValue: existingValue,
                                  );

                                  if (value == null) {
                                    return;
                                  }

                                  if (!context.mounted) {
                                    return;
                                  }

                                  if (habit.requiresPhotoValidation &&
                                      value >= quantMax &&
                                      !habit.isCompletedOnDate(
                                        provider.userId,
                                        now,
                                      )) {
                                    final aiCheckOk = await _runPhotoValidation(
                                      context,
                                      habit,
                                    );
                                    if (!aiCheckOk) {
                                      return;
                                    }
                                  }

                                  await provider.saveQuantifiedProgress(
                                    habit,
                                    value,
                                  );
                                  if (value >= quantMax && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Awesome! You hit today\'s ${habit.quantUnitFor(provider.userId)} goal.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onCardTap: () {
                                  // Keep group edits/settings centralized in Groups tab.
                                  context.read<NavigationProvider>().setIndex(
                                    2,
                                  );
                                },
                              )
                              .animate(key: ValueKey('group_anim_${habit.id}'))
                              .fade()
                              .slideY(begin: 0.15);
                        }),
                        const SizedBox(height: 8),
                      ],
                      if (personalHabits.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                          child: Text(
                            'PERSONAL TASKS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ...personalHabits.map((habit) {
                        return Dismissible(
                          key: Key(habit.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Delete habit?'),
                                  content: Text(
                                    'Are you sure you want to delete "${habit.title}"? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                            return shouldDelete ?? false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 30),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          onDismissed: (direction) {
                            provider.deleteHabit(habit.id);
                          },
                          child:
                              HabitCard(
                                    habit: habit,
                                    currentUserId: provider.userId,
                                    onCheck: () async {
                                      final now = DateTime.now();
                                      final uid = provider.userId;
                                      final isQuantified = habit
                                          .isQuantifiedFor(uid);
                                      final quantMin = habit.quantMinFor(uid);
                                      final quantMax = habit.quantMaxFor(uid);
                                      final quantUnit = habit.quantUnitFor(uid);

                                      if (!isQuantified) {
                                        final wasCompleted =
                                            habit.isCompletedOnDate(
                                              provider.userId,
                                              now,
                                            );
                                        if (habit.requiresPhotoValidation &&
                                            !habit.isCompletedOnDate(
                                              provider.userId,
                                              now,
                                            )) {
                                          final aiCheckOk =
                                              await _runPhotoValidation(
                                                context,
                                                habit,
                                              );
                                          if (!aiCheckOk) return;
                                        }
                                        await provider.toggleHabitCompletion(
                                          habit,
                                        );
                                        if (!wasCompleted && context.mounted) {
                                          await _showCompletionCelebration(
                                            context,
                                            provider,
                                            habit,
                                          );
                                        }
                                        return;
                                      }

                                      if (habit.isCompletedOnDate(
                                        provider.userId,
                                        now,
                                      )) {
                                        await provider.clearTodayProgress(
                                          habit,
                                        );
                                        return;
                                      }

                                      final existingValue = habit
                                          .completionValueFor(
                                            provider.userId,
                                            now,
                                          );

                                      final value = await _askQuantifiedValue(
                                        context,
                                        habit,
                                        quantUnit,
                                        quantMin,
                                        quantMax,
                                        initialValue: existingValue,
                                      );

                                      if (value == null) {
                                        return;
                                      }

                                      if (!context.mounted) {
                                        return;
                                      }

                                      if (habit.requiresPhotoValidation &&
                                          value >= quantMax &&
                                          !habit.isCompletedOnDate(
                                            provider.userId,
                                            now,
                                          )) {
                                        final aiCheckOk =
                                            await _runPhotoValidation(
                                              context,
                                              habit,
                                            );
                                        if (!aiCheckOk) {
                                          return;
                                        }
                                      }

                                      await provider.saveQuantifiedProgress(
                                        habit,
                                        value,
                                      );
                                      if (value >= quantMax && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Awesome! You hit today\'s ${habit.quantUnitFor(provider.userId)} goal.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    onCardTap: () {
                                      if (habit.participants.length > 1) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                HabitLeaderboardScreen(
                                                  habit: habit,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                  )
                                  .animate(key: ValueKey('anim_${habit.id}'))
                                  .fade()
                                  .slideY(begin: 0.2),
                        );
                      }),
                    ],
                  ),
                );
              },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
