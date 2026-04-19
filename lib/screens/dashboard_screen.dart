import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../widgets/habit_card.dart';
import '../providers/habits_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/quantified_log_provider.dart';
import '../services/group_service.dart';
import '../utils/quantity_format.dart';
import 'group_detail_screen.dart';
import 'habit_leaderboard_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const double _bottomNavClearance = 124;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _groupsExpanded = true;
  bool _personalExpanded = true;
  bool _isLoadingSectionPrefs = true;
  List<String> _groupOrderIds = <String>[];
  List<String> _personalOrderIds = <String>[];
  final Set<String> _movingToBottomHabitIds = <String>{};

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _groupsExpandedKey => 'dashboard_groups_expanded_$_currentUserId';
  String get _personalExpandedKey =>
      'dashboard_personal_expanded_$_currentUserId';
  String get _groupsOrderKey => 'dashboard_groups_order_$_currentUserId';
  String get _personalOrderKey => 'dashboard_personal_order_$_currentUserId';

  @override
  void initState() {
    super.initState();
    _loadSectionPrefs();
  }

  Future<void> _loadSectionPrefs() async {
    final uid = _currentUserId;
    if (uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingSectionPrefs = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _groupsExpanded = prefs.getBool(_groupsExpandedKey) ?? true;
      _personalExpanded = prefs.getBool(_personalExpandedKey) ?? true;
      _groupOrderIds = prefs.getStringList(_groupsOrderKey) ?? <String>[];
      _personalOrderIds = prefs.getStringList(_personalOrderKey) ?? <String>[];
      _isLoadingSectionPrefs = false;
    });
  }

  Future<void> _setGroupsExpanded(bool value) async {
    setState(() => _groupsExpanded = value);
    final uid = _currentUserId;
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_groupsExpandedKey, value);
  }

  Future<void> _setPersonalExpanded(bool value) async {
    setState(() => _personalExpanded = value);
    final uid = _currentUserId;
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personalExpandedKey, value);
  }

  Future<void> _saveOrderPrefs({
    List<String>? groupOrder,
    List<String>? personalOrder,
  }) async {
    final uid = _currentUserId;
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (groupOrder != null) {
      await prefs.setStringList(_groupsOrderKey, groupOrder);
    }
    if (personalOrder != null) {
      await prefs.setStringList(_personalOrderKey, personalOrder);
    }
  }

  List<Habit> _applySavedOrder(List<Habit> source, List<String> orderedIds) {
    if (source.isEmpty) return const <Habit>[];
    if (orderedIds.isEmpty) return List<Habit>.from(source);

    final rank = <String, int>{};
    for (var i = 0; i < orderedIds.length; i++) {
      rank[orderedIds[i]] = i;
    }

    final indexed = source.indexed.toList();
    indexed.sort((a, b) {
      final aRank = rank[a.$2.id] ?? (100000 + a.$1);
      final bRank = rank[b.$2.id] ?? (100000 + b.$1);
      return aRank.compareTo(bRank);
    });

    return indexed.map((entry) => entry.$2).toList();
  }

  List<Habit> _orderWithCompletedLast(List<Habit> source, String userId) {
    final now = DateTime.now();
    final pending = <Habit>[];
    final completed = <Habit>[];

    for (final habit in source) {
      if (habit.isCompletedOnDate(userId, now)) {
        completed.add(habit);
      } else {
        pending.add(habit);
      }
    }

    return <Habit>[...pending, ...completed];
  }

  Future<void> _setGroupOrderFromItems(List<Habit> items) async {
    final ids = items.map((habit) => habit.id).toList();
    setState(() {
      _groupOrderIds = ids;
    });
    await _saveOrderPrefs(groupOrder: ids);
  }

  Future<void> _setPersonalOrderFromItems(List<Habit> items) async {
    final ids = items.map((habit) => habit.id).toList();
    setState(() {
      _personalOrderIds = ids;
    });
    await _saveOrderPrefs(personalOrder: ids);
  }

  Future<void> _onGroupReorder(
    List<Habit> ordered,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final next = List<Habit>.from(ordered);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    await _setGroupOrderFromItems(next);
  }

  Future<void> _onPersonalReorder(
    List<Habit> ordered,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final next = List<Habit>.from(ordered);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    await _setPersonalOrderFromItems(next);
  }

  Future<void> _startMoveToBottomAnimation(String habitId) async {
    if (_movingToBottomHabitIds.contains(habitId)) {
      return;
    }

    if (mounted) {
      setState(() {
        _movingToBottomHabitIds.add(habitId);
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  Future<void> _finishMoveToBottomAnimation(String habitId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    setState(() {
      _movingToBottomHabitIds.remove(habitId);
    });
  }

  Widget _wrapCompletionMoveAnimation({
    required String habitId,
    required Widget child,
  }) {
    final moving = _movingToBottomHabitIds.contains(habitId);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      offset: moving ? const Offset(0, 0.18) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        opacity: moving ? 0.75 : 1,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: moving ? 0.0 : 1.0,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$title ($count)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: muted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompletionCelebration(
    BuildContext context,
    HabitsProvider provider,
    Habit habit,
  ) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final completionLabel = _completionLabelForHabit(habit, provider.userId);

    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('Nice work! "$completionLabel" completed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.clearTodayProgress(habit);
          },
        ),
      ),
    );

    // Force-close the same controller to avoid lingering action snackbars.
    Timer(const Duration(milliseconds: 3600), () {
      if (!context.mounted) return;
      controller.close();
    });
  }

  String _completionLabelForHabit(Habit habit, String userId) {
    if (!habit.isGroup) {
      return habit.displayTitle;
    }
    final memberTask = habit.taskFor(userId).trim();
    if (memberTask.isNotEmpty) {
      return memberTask;
    }
    return habit.title;
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
    final valueController = TextEditingController(
      text: formatQuantity(
        startValue,
        maxDecimals: (quantMax - quantMin) <= 20 ? 1 : 0,
      ),
    );

    final selectedValue = await showModalBottomSheet<double>(
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 32,
                ),
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
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${quantProvider.formattedValue} $quantUnit',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ).animate().scaleXY(
                      begin: 0.9,
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Type quantity',
                        suffixText: quantUnit,
                        hintText: 'Enter value manually',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                      onSubmitted: (raw) {
                        final ok = quantProvider.trySetFromText(raw);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid number.'),
                            ),
                          );
                          return;
                        }
                        valueController.text = quantProvider.formattedValue;
                      },
                    ),
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
                              valueController.text =
                                  quantProvider.formattedValue;
                            },
                            icon: const Icon(Icons.remove_rounded, size: 28),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 12,
                              activeTrackColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              thumbColor: Colors.white,
                              overlayColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 14,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24,
                              ),
                            ),
                            child: Slider(
                              value: quantProvider.value,
                              min: quantMin,
                              max: quantMax,
                              divisions: quantProvider.divisions,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                quantProvider.setValue(val);
                                valueController.text =
                                    quantProvider.formattedValue;
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
                              valueController.text =
                                  quantProvider.formattedValue;
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
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final ok = quantProvider.trySetFromText(
                            valueController.text,
                          );
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid number.'),
                              ),
                            );
                            return;
                          }
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

    valueController.dispose();
    return selectedValue;
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

  Future<void> _openGroupForHabit(BuildContext context, Habit habit) async {
    final groupId = (habit.groupEntityId ?? '').trim();
    if (groupId.isEmpty) {
      context.read<NavigationProvider>().setIndex(2);
      return;
    }

    try {
      final group = await GroupService().getGroupById(groupId);
      if (!mounted || !context.mounted) {
        return;
      }

      if (group == null) {
        context.read<NavigationProvider>().setIndex(2);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find that group. Opened Groups instead.'),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      );
    } catch (error) {
      if (!mounted || !context.mounted) {
        return;
      }
      context.read<NavigationProvider>().setIndex(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open group. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = _formatDate(today);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                    height: 100,
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
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: userId.isEmpty
                                ? null
                                : FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .snapshots(),
                            builder: (context, snapshot) {
                              final data = snapshot.data?.data();
                              final profile = data != null
                                  ? UserProfile.fromMap(data)
                                  : null;
                              final photoUrl = profile?.photoUrl?.trim();

                              if (photoUrl != null && photoUrl.isNotEmpty) {
                                return CircleAvatar(
                                  radius: 22,
                                  backgroundImage: NetworkImage(photoUrl),
                                  backgroundColor: Colors.transparent,
                                );
                              }

                              return const Icon(Icons.person_rounded, size: 34);
                            },
                          ),
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
                  final orderedGroupHabits = _applySavedOrder(
                    groupHabits,
                    _groupOrderIds,
                  );
                  final orderedPersonalHabits = _applySavedOrder(
                    personalHabits,
                    _personalOrderIds,
                  );
                  final displayGroupHabits = _orderWithCompletedLast(
                    orderedGroupHabits,
                    provider.userId,
                  );
                  final displayPersonalHabits = _orderWithCompletedLast(
                    orderedPersonalHabits,
                    provider.userId,
                  );

                  if (_isLoadingSectionPrefs) {
                    return const Center(child: CircularProgressIndicator());
                  }

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
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 8),
                        if (groupHabits.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            title: 'GROUP TASKS',
                            count: groupHabits.length,
                            expanded: _groupsExpanded,
                            onToggle: () {
                              _setGroupsExpanded(!_groupsExpanded);
                            },
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1,
                                    child: child,
                                  ),
                                );
                              },
                              child: _groupsExpanded
                                  ? Column(
                                      key: const ValueKey('groups_open'),
                                      children: [
                                        ReorderableListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          buildDefaultDragHandles: false,
                                          proxyDecorator:
                                              (child, index, animation) {
                                                return Material(
                                                  color: Colors.transparent,
                                                  shadowColor:
                                                      Colors.transparent,
                                                  elevation: 0,
                                                  child: child,
                                                );
                                              },
                                          itemCount: displayGroupHabits.length,
                                          onReorder: (oldIndex, newIndex) {
                                            _onGroupReorder(
                                              displayGroupHabits,
                                              oldIndex,
                                              newIndex,
                                            );
                                          },
                                          itemBuilder: (context, index) {
                                            final habit =
                                                displayGroupHabits[index];
                                            return ReorderableDelayedDragStartListener(
                                              key: ValueKey(
                                                'group_reorder_${habit.id}',
                                              ),
                                              index: index,
                                              child: _wrapCompletionMoveAnimation(
                                                habitId: habit.id,
                                                child: HabitCard(
                                                  habit: habit,
                                                  currentUserId:
                                                      provider.userId,
                                                  onCheck: () async {
                                                    final now = DateTime.now();
                                                    final uid = provider.userId;
                                                    final isQuantified = habit
                                                        .isQuantifiedFor(uid);
                                                    final quantMin = habit
                                                        .quantMinFor(uid);
                                                    final quantMax = habit
                                                        .quantMaxFor(uid);
                                                    final quantUnit = habit
                                                        .quantUnitFor(uid);

                                                    if (!isQuantified) {
                                                      final wasCompleted = habit
                                                          .isCompletedOnDate(
                                                            provider.userId,
                                                            now,
                                                          );
                                                      if (!wasCompleted) {
                                                        await _startMoveToBottomAnimation(
                                                          habit.id,
                                                        );
                                                      }
                                                      await provider
                                                          .toggleHabitCompletion(
                                                            habit,
                                                          );
                                                      if (!wasCompleted) {
                                                        await _finishMoveToBottomAnimation(
                                                          habit.id,
                                                        );
                                                      }
                                                      if (!wasCompleted &&
                                                          context.mounted) {
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
                                                      await provider
                                                          .clearTodayProgress(
                                                            habit,
                                                          );
                                                      return;
                                                    }

                                                    final existingValue = habit
                                                        .completionValueFor(
                                                          provider.userId,
                                                          now,
                                                        );

                                                    final value =
                                                        await _askQuantifiedValue(
                                                          context,
                                                          habit,
                                                          quantUnit,
                                                          quantMin,
                                                          quantMax,
                                                          initialValue:
                                                              existingValue,
                                                        );

                                                    if (value == null) {
                                                      return;
                                                    }

                                                    if (!context.mounted) {
                                                      return;
                                                    }

                                                    if (value >= quantMax &&
                                                        context.mounted) {
                                                      await _startMoveToBottomAnimation(
                                                        habit.id,
                                                      );
                                                    }

                                                    await provider
                                                        .saveQuantifiedProgress(
                                                          habit,
                                                          value,
                                                        );

                                                    if (value >= quantMax &&
                                                        context.mounted) {
                                                      await _finishMoveToBottomAnimation(
                                                        habit.id,
                                                      );
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Awesome! You hit today\'s ${habit.quantUnitFor(provider.userId)} goal.',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  onCardTap: () {
                                                    _openGroupForHabit(
                                                      context,
                                                      habit,
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    )
                                  : const SizedBox(
                                      key: ValueKey('groups_closed'),
                                    ),
                            ),
                          ),
                        ],
                        if (personalHabits.isNotEmpty)
                          _buildSectionHeader(
                            context,
                            title: 'PERSONAL/SHARED TASKS',
                            count: personalHabits.length,
                            expanded: _personalExpanded,
                            onToggle: () {
                              _setPersonalExpanded(!_personalExpanded);
                            },
                          ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child: _personalExpanded
                                ? Column(
                                    key: const ValueKey('personal_open'),
                                    children: [
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        proxyDecorator:
                                            (child, index, animation) {
                                              return Material(
                                                color: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                elevation: 0,
                                                child: child,
                                              );
                                            },
                                        itemCount: displayPersonalHabits.length,
                                        onReorder: (oldIndex, newIndex) {
                                          _onPersonalReorder(
                                            displayPersonalHabits,
                                            oldIndex,
                                            newIndex,
                                          );
                                        },
                                        itemBuilder: (context, index) {
                                          final habit =
                                              displayPersonalHabits[index];
                                          return ReorderableDelayedDragStartListener(
                                            key: ValueKey(
                                              'personal_reorder_${habit.id}',
                                            ),
                                            index: index,
                                            child: Dismissible(
                                              key: Key(habit.id),
                                              direction:
                                                  DismissDirection.endToStart,
                                              confirmDismiss: (direction) async {
                                                final isShared =
                                                    habit.participants.length >
                                                    1;
                                                final shouldDelete = await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      title: Text(
                                                        isShared
                                                            ? 'Leave shared habit?'
                                                            : 'Delete habit?',
                                                      ),
                                                      content: Text(
                                                        isShared
                                                            ? 'You will be removed from "${habit.title}". Others will keep it and be notified that you left.'
                                                            : 'Are you sure you want to delete "${habit.title}"? This cannot be undone.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogContext,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Color.fromARGB(
                                                                  255,
                                                                  217,
                                                                  4,
                                                                  4,
                                                                ),
                                                          ),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogContext,
                                                                true,
                                                              ),
                                                          child: Text(
                                                            isShared
                                                                ? 'Leave'
                                                                : 'Delete',
                                                            style: TextStyle(
                                                              color:
                                                                  const Color.fromARGB(
                                                                    255,
                                                                    255,
                                                                    255,
                                                                    255,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                                return shouldDelete ?? false;
                                              },
                                              background: Container(
                                                alignment:
                                                    Alignment.centerRight,
                                                padding: const EdgeInsets.only(
                                                  right: 30,
                                                ),
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent
                                                      .withValues(alpha: 0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_sweep_rounded,
                                                  color: Colors.white,
                                                  size: 32,
                                                ),
                                              ),
                                              onDismissed: (direction) {
                                                provider.deleteHabit(habit);
                                              },
                                              child: _wrapCompletionMoveAnimation(
                                                habitId: habit.id,
                                                child:
                                                    HabitCard(
                                                          habit: habit,
                                                          currentUserId:
                                                              provider.userId,
                                                          onCheck: () async {
                                                            final now =
                                                                DateTime.now();
                                                            final uid =
                                                                provider.userId;
                                                            final isQuantified =
                                                                habit
                                                                    .isQuantifiedFor(
                                                                      uid,
                                                                    );
                                                            final quantMin =
                                                                habit
                                                                    .quantMinFor(
                                                                      uid,
                                                                    );
                                                            final quantMax =
                                                                habit
                                                                    .quantMaxFor(
                                                                      uid,
                                                                    );
                                                            final quantUnit =
                                                                habit
                                                                    .quantUnitFor(
                                                                      uid,
                                                                    );

                                                            if (!isQuantified) {
                                                              final wasCompleted =
                                                                  habit.isCompletedOnDate(
                                                                    provider
                                                                        .userId,
                                                                    now,
                                                                  );
                                                              if (!wasCompleted) {
                                                                await _startMoveToBottomAnimation(
                                                                  habit.id,
                                                                );
                                                              }
                                                              await provider
                                                                  .toggleHabitCompletion(
                                                                    habit,
                                                                  );
                                                              if (!wasCompleted) {
                                                                await _finishMoveToBottomAnimation(
                                                                  habit.id,
                                                                );
                                                              }
                                                              if (!wasCompleted &&
                                                                  context
                                                                      .mounted) {
                                                                await _showCompletionCelebration(
                                                                  context,
                                                                  provider,
                                                                  habit,
                                                                );
                                                              }
                                                              return;
                                                            }

                                                            if (habit
                                                                .isCompletedOnDate(
                                                                  provider
                                                                      .userId,
                                                                  now,
                                                                )) {
                                                              await provider
                                                                  .clearTodayProgress(
                                                                    habit,
                                                                  );
                                                              return;
                                                            }

                                                            final existingValue =
                                                                habit.completionValueFor(
                                                                  provider
                                                                      .userId,
                                                                  now,
                                                                );

                                                            final value =
                                                                await _askQuantifiedValue(
                                                                  context,
                                                                  habit,
                                                                  quantUnit,
                                                                  quantMin,
                                                                  quantMax,
                                                                  initialValue:
                                                                      existingValue,
                                                                );

                                                            if (value == null) {
                                                              return;
                                                            }

                                                            if (!context
                                                                .mounted) {
                                                              return;
                                                            }

                                                            if (value >=
                                                                    quantMax &&
                                                                context
                                                                    .mounted) {
                                                              await _startMoveToBottomAnimation(
                                                                habit.id,
                                                              );
                                                            }

                                                            await provider
                                                                .saveQuantifiedProgress(
                                                                  habit,
                                                                  value,
                                                                );

                                                            if (value >=
                                                                    quantMax &&
                                                                context
                                                                    .mounted) {
                                                              await _finishMoveToBottomAnimation(
                                                                habit.id,
                                                              );
                                                              if (!context
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Awesome! You hit today\'s ${habit.quantUnitFor(provider.userId)} goal.',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                          onCardTap: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) =>
                                                                    HabitLeaderboardScreen(
                                                                      habit:
                                                                          habit,
                                                                    ),
                                                              ),
                                                            );
                                                          },
                                                        )
                                                        .animate(
                                                          key: ValueKey(
                                                            'anim_${habit.id}',
                                                          ),
                                                        )
                                                        .fade()
                                                        .slideY(begin: 0.2),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  )
                                : const SizedBox(
                                    key: ValueKey('personal_closed'),
                                  ),
                          ),
                        ),
                        const SizedBox(
                          height: DashboardScreen._bottomNavClearance,
                        ),
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
