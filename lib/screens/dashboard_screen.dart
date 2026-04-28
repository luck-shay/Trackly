import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_challenge.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../widgets/habit_card.dart';
import '../providers/habits_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/quantified_log_provider.dart';
import '../services/group_service.dart';
import '../utils/quantity_format.dart';
import 'group_challenge_detail_screen.dart';
import 'group_detail_screen.dart';
import 'habit_leaderboard_screen.dart';
import 'profile_screen.dart';

enum DashboardFilter {
  all,
  challenges,
  group,
  individual,
  shared,
  incomplete,
  completed,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const double _bottomNavClearance = 124;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool _isLoadingSectionPrefs = true;
  DashboardFilter _selectedFilter = DashboardFilter.all;
  List<String> _groupOrderIds = <String>[];
  List<String> _personalOrderIds = <String>[];
  // ignore: unused_field
  List<String> _sectionOrder = ['group', 'challenges', 'individual', 'shared'];
  final Set<String> _completedHabitIdsForOrdering = <String>{};
  bool _hasCapturedInitialCompletionOrder = false;
  NavigationProvider? _navigationProvider;
  int _lastNavIndex = 0;

  String _filterLabel(DashboardFilter filter) {
    return switch (filter) {
      DashboardFilter.all => 'All',
      DashboardFilter.challenges => 'Challenges',
      DashboardFilter.group => 'Group',
      DashboardFilter.individual => 'Individual',
      DashboardFilter.shared => 'Shared',
      DashboardFilter.incomplete => 'Incomplete',
      DashboardFilter.completed => 'Completed',
    };
  }

  Widget _buildFilterPills(
    BuildContext context, {
    required int allCount,
    required int challengeCount,
    required int groupCount,
    required int individualCount,
    required int sharedCount,
    required int incompleteCount,
    required int completedCount,
  }) {
    final items = <(DashboardFilter, int)>[(DashboardFilter.all, allCount)];
    if (challengeCount > 0) {
      items.add((DashboardFilter.challenges, challengeCount));
    }
    if (groupCount > 0) {
      items.add((DashboardFilter.group, groupCount));
    }
    if (individualCount > 0) {
      items.add((DashboardFilter.individual, individualCount));
    }
    if (sharedCount > 0) {
      items.add((DashboardFilter.shared, sharedCount));
    }
    if (incompleteCount > 0) {
      items.add((DashboardFilter.incomplete, incompleteCount));
    }
    if (completedCount > 0) {
      items.add((DashboardFilter.completed, completedCount));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...items.map((item) {
              final filter = item.$1;
              final count = item.$2;
              final selected = _selectedFilter == filter;
              final useSecondary =
                  filter == DashboardFilter.incomplete ||
                  filter == DashboardFilter.completed;
              final accent = useSecondary
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary;
              final bg = selected
                  ? accent.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surface;
              final fg = selected
                  ? accent
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.78);

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () {
                    if (_selectedFilter == filter) {
                      return;
                    }
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: 0.45)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _filterLabel(filter),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? accent.withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _groupsOrderKey => 'dashboard_groups_order_$_currentUserId';
  String get _personalOrderKey => 'dashboard_personal_order_$_currentUserId';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSectionPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachNavigationListener();
      _refreshCompletedOrderSnapshot();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationProvider?.removeListener(_handleNavigationIndexChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCompletedOrderSnapshot();
    }
  }

  void _attachNavigationListener() {
    if (!mounted) return;
    final nextProvider = context.read<NavigationProvider>();
    if (identical(_navigationProvider, nextProvider)) {
      return;
    }
    _navigationProvider?.removeListener(_handleNavigationIndexChanged);
    _navigationProvider = nextProvider;
    _lastNavIndex = nextProvider.currentIndex;
    nextProvider.addListener(_handleNavigationIndexChanged);
  }

  void _handleNavigationIndexChanged() {
    final nav = _navigationProvider;
    if (nav == null) {
      return;
    }

    final nextIndex = nav.currentIndex;
    final returningToDashboard = _lastNavIndex != 0 && nextIndex == 0;
    _lastNavIndex = nextIndex;

    if (returningToDashboard) {
      _refreshCompletedOrderSnapshot();
    }
  }

  void _refreshCompletedOrderSnapshot() {
    if (!mounted) return;

    final provider = context.read<HabitsProvider>();
    if (provider.isLoading) {
      return;
    }

    final now = DateTime.now();
    final nextCompletedIds = provider.habits
        .where((habit) => habit.isCompletedOnDate(provider.userId, now))
        .map((habit) => habit.id)
        .toSet();

    if (_hasCapturedInitialCompletionOrder &&
        _sameHabitIdSet(_completedHabitIdsForOrdering, nextCompletedIds)) {
      return;
    }

    setState(() {
      _completedHabitIdsForOrdering
        ..clear()
        ..addAll(nextCompletedIds);
      _hasCapturedInitialCompletionOrder = true;
    });
  }

  bool _sameHabitIdSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
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
      _groupOrderIds = prefs.getStringList(_groupsOrderKey) ?? <String>[];
      _personalOrderIds = prefs.getStringList(_personalOrderKey) ?? <String>[];
      _sectionOrder =
          prefs.getStringList('dashboard_section_order') ??
          ['group', 'challenges', 'individual', 'shared'];
      _isLoadingSectionPrefs = false;
    });
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

  List<Habit> _orderWithCompletedLast(List<Habit> source) {
    final pending = <Habit>[];
    final completed = <Habit>[];

    for (final habit in source) {
      if (_completedHabitIdsForOrdering.contains(habit.id)) {
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

  Widget _wrapCompletionMoveAnimation({
    required String habitId,
    required Widget child,
  }) {
    // Keep completion transition minimal to avoid list reflow jank.
    return child;
  }

  Widget _buildSectionLabel(
    BuildContext context, {
    required String title,
    required int count,
  }) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
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
        ],
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

  Future<void> _openChallengeFromDashboard(
    BuildContext context,
    GroupChallenge challenge,
  ) async {
    try {
      final group = await GroupService().getGroupById(challenge.groupId);
      if (!mounted || !context.mounted) {
        return;
      }
      if (group == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find that group.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GroupChallengeDetailScreen(group: group, challenge: challenge),
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open challenge. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  Future<bool> _canDeleteHabit({
    required Habit habit,
    required String currentUserId,
  }) async {
    if (!habit.isGroup || (habit.groupEntityId ?? '').trim().isEmpty) {
      return true;
    }

    final group = await GroupService().getGroupById(
      habit.groupEntityId!.trim(),
    );
    if (group == null) {
      return false;
    }
    return group.memberIds.contains(currentUserId);
  }

  Future<bool> _confirmDeleteHabit(BuildContext context, Habit habit) async {
    final isGroupTask = habit.isGroup;
    final isShared = !isGroupTask && habit.participants.length > 1;
    final title = isShared ? 'Leave shared habit?' : 'Delete habit?';
    final message = isShared
        ? 'You will be removed from "${habit.title}". Others will keep it and be notified that you left.'
        : isGroupTask
        ? 'This will delete "${habit.title}" for the whole group. This cannot be undone.'
        : 'Are you sure you want to delete "${habit.title}"? This cannot be undone.';
    final actionLabel = isShared ? 'Leave' : 'Delete';

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 217, 4, 4),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteHabitWithPermissions(
    BuildContext context,
    HabitsProvider provider,
    Habit habit,
  ) async {
    final canDelete = await _canDeleteHabit(
      habit: habit,
      currentUserId: provider.userId,
    );

    if (!context.mounted) {
      return;
    }

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only group members can delete group tasks.'),
        ),
      );
      return;
    }

    final shouldDelete = await _confirmDeleteHabit(context, habit);
    if (!context.mounted || !shouldDelete) {
      return;
    }

    try {
      await provider.deleteHabit(habit);

      if (!context.mounted) {
        return;
      }

      final canJoinBack = !habit.isGroup && habit.participants.length > 1;
      if (canJoinBack) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('You left "${habit.title}".'),
            action: SnackBarAction(
              label: 'Join back',
              onPressed: () async {
                try {
                  final rejoined = await provider.rejoinSharedHabit(habit);
                  if (!context.mounted) {
                    return;
                  }
                  if (!rejoined) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not join back. Ask a participant to invite you.',
                        ),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rejoined "${habit.title}".')),
                  );
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not join back. ${error.toString().split('\n').first}',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete task. ${error.toString().split('\n').first}',
          ),
        ),
      );
    }
  }

  SlidableAction _buildHabitSwipeAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    return SlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: color,
      foregroundColor: Colors.white,
      icon: icon,
      label: label,
      borderRadius: borderRadius,
      spacing: 0,
      autoClose: true,
    );
  }

  Widget _buildHabitSlidable(
    BuildContext context,
    HabitsProvider provider,
    Habit habit, {
    required Future<void> Function() onToggleCompletion,
    required Widget child,
  }) {
    final completedToday = habit.isCompletedOnDate(
      provider.userId,
      DateTime.now(),
    );
    final toggleLabel = completedToday ? 'Undo' : 'Done';
    final toggleIcon = completedToday
        ? Icons.undo_rounded
        : Icons.check_circle_rounded;
    final isShared = !habit.isGroup && habit.participants.length > 1;
    final deleteLabel = isShared ? 'Leave' : 'Delete';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: completedToday
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Slidable(
            key: ValueKey('habit_slidable_${habit.id}'),
            closeOnScroll: true,
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.28,
              dismissible: DismissiblePane(
                onDismissed: () {},
                closeOnCancel: true,
                confirmDismiss: () async {
                  await onToggleCompletion();
                  return false;
                },
              ),
              children: [
                _buildHabitSwipeAction(
                  label: toggleLabel,
                  icon: toggleIcon,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.9),
                  onPressed: onToggleCompletion,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.28,
              children: [
                _buildHabitSwipeAction(
                  label: deleteLabel,
                  icon: Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () =>
                      _deleteHabitWithPermissions(context, provider, habit),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
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

                  final individualHabits = provider.habits
                      .where(
                        (habit) =>
                            !habit.isGroup &&
                            habit.spaceType == HabitSpaceType.individual,
                      )
                      .toList();
                  final sharedHabits = provider.habits
                      .where(
                        (habit) =>
                            !habit.isGroup &&
                            habit.spaceType == HabitSpaceType.sharedTask,
                      )
                      .toList();
                  final groupHabits = provider.habits
                      .where((habit) => habit.isGroup)
                      .toList();
                  final orderedGroupHabits = _applySavedOrder(
                    groupHabits,
                    _groupOrderIds,
                  );
                  // For now, keep using _personalOrderIds for both, or separate them. Let's separate them later or just combine them for ordering:
                  final personalHabits = [...individualHabits, ...sharedHabits];
                  final orderedPersonalHabits = _applySavedOrder(
                    personalHabits,
                    _personalOrderIds,
                  );
                  if (!_hasCapturedInitialCompletionOrder &&
                      !_isLoadingSectionPrefs) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _refreshCompletedOrderSnapshot();
                    });
                  }
                  final displayGroupHabits = _orderWithCompletedLast(
                    orderedGroupHabits,
                  );
                  final displayPersonalHabits = _orderWithCompletedLast(
                    orderedPersonalHabits,
                  );
                  final displayIndividualHabits = displayPersonalHabits
                      .where((h) => h.spaceType == HabitSpaceType.individual)
                      .toList();
                  final displaySharedHabits = displayPersonalHabits
                      .where((h) => h.spaceType == HabitSpaceType.sharedTask)
                      .toList();

                  final individualCount = individualHabits.length;
                  final sharedCount = sharedHabits.length;

                  final scopeHabits = <Habit>[
                    ...displayGroupHabits,
                    ...displayPersonalHabits,
                  ];
                  final now = DateTime.now();
                  final completedCount = scopeHabits
                      .where(
                        (habit) =>
                            habit.isCompletedOnDate(provider.userId, now),
                      )
                      .length;
                  final incompleteCount = scopeHabits.length - completedCount;
                  final filteredGroupHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displayGroupHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => displayGroupHabits,
                    DashboardFilter.individual => const <Habit>[],
                    DashboardFilter.shared => const <Habit>[],
                    DashboardFilter.incomplete =>
                      displayGroupHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displayGroupHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };
                  final filteredIndividualHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displayIndividualHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => const <Habit>[],
                    DashboardFilter.individual => displayIndividualHabits,
                    DashboardFilter.shared => const <Habit>[],
                    DashboardFilter.incomplete =>
                      displayIndividualHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displayIndividualHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };
                  final filteredSharedHabits = switch (_selectedFilter) {
                    DashboardFilter.all => displaySharedHabits,
                    DashboardFilter.challenges => const <Habit>[],
                    DashboardFilter.group => const <Habit>[],
                    DashboardFilter.individual => const <Habit>[],
                    DashboardFilter.shared => displaySharedHabits,
                    DashboardFilter.incomplete =>
                      displaySharedHabits
                          .where(
                            (habit) =>
                                !habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                    DashboardFilter.completed =>
                      displaySharedHabits
                          .where(
                            (habit) =>
                                habit.isCompletedOnDate(provider.userId, now),
                          )
                          .toList(),
                  };

                  final showGroups = filteredGroupHabits.isNotEmpty;
                  final showIndividual = filteredIndividualHabits.isNotEmpty;
                  final showShared = filteredSharedHabits.isNotEmpty;

                  final showPersonal = showIndividual || showShared;
                  final filteredPersonalHabits = [
                    ...filteredIndividualHabits,
                    ...filteredSharedHabits,
                  ];

                  if (_isLoadingSectionPrefs) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<List<GroupChallenge>>(
                    stream: GroupService().streamMyChallenges(),
                    builder: (context, challengeSnapshot) {
                      final myChallenges =
                          challengeSnapshot.data ?? const <GroupChallenge>[];
                      final challengeCount = myChallenges.length;
                      final allCount =
                          groupHabits.length +
                          personalHabits.length +
                          challengeCount;

                      final filteredChallenges = switch (_selectedFilter) {
                        DashboardFilter.all => myChallenges,
                        DashboardFilter.challenges => myChallenges,
                        DashboardFilter.group => const <GroupChallenge>[],
                        DashboardFilter.individual => const <GroupChallenge>[],
                        DashboardFilter.shared => const <GroupChallenge>[],
                        DashboardFilter.incomplete => const <GroupChallenge>[],
                        DashboardFilter.completed => const <GroupChallenge>[],
                      };

                      final availableFilters = <DashboardFilter>{
                        DashboardFilter.all,
                        if (challengeCount > 0) DashboardFilter.challenges,
                        if (groupHabits.isNotEmpty) DashboardFilter.group,
                        if (individualCount > 0) DashboardFilter.individual,
                        if (sharedCount > 0) DashboardFilter.shared,
                        if (incompleteCount > 0) DashboardFilter.incomplete,
                        if (completedCount > 0) DashboardFilter.completed,
                      };

                      if (!availableFilters.contains(_selectedFilter)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selectedFilter = DashboardFilter.all;
                          });
                        });
                      }

                      final showChallenges = filteredChallenges.isNotEmpty;

                      if (personalHabits.isEmpty &&
                          groupHabits.isEmpty &&
                          challengeCount == 0) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.05),
                                    ),
                                    child: Icon(
                                      Icons.spa_rounded,
                                      size: 80,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.6),
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
                                  )
                                  .animate()
                                  .fade(delay: 300.ms)
                                  .slideY(begin: 0.1),
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
                        child: SlidableAutoCloseBehavior(
                          closeWhenTapped: true,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.zero,
                            children: [
                              const SizedBox(height: 8),
                              _buildFilterPills(
                                context,
                                allCount: allCount,
                                challengeCount: challengeCount,
                                groupCount: groupHabits.length,
                                individualCount: individualCount,
                                sharedCount: sharedCount,
                                incompleteCount: incompleteCount,
                                completedCount: completedCount,
                              ),
                              if (showChallenges)
                                _buildSectionLabel(
                                  context,
                                  title: 'LIVE CHALLENGES',
                                  count: filteredChallenges.length,
                                ),
                              if (showChallenges && filteredChallenges.isNotEmpty)
                                ...filteredChallenges.map((challenge) {
                                  final status = !challenge.isReadyToStart
                                      ? 'Waiting for accepts'
                                      : challenge.hasEnded
                                      ? 'Ended'
                                      : 'Live';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _openChallengeFromDashboard(
                                        context,
                                        challenge,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    challenge.title,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    challenge.hasTarget
                                                        ? 'Target: ${formatQuantity(challenge.targetValue, maxDecimals: 1)} ${challenge.unit}'
                                                        : 'No target set',
                                                    style: GoogleFonts.inter(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.68,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                status,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              if (showGroups &&
                                  filteredGroupHabits.isNotEmpty) ...[
                                _buildSectionLabel(
                                  context,
                                  title: 'GROUP TASKS',
                                  count: filteredGroupHabits.length,
                                ),
                                Column(
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
                                      itemCount: filteredGroupHabits.length,
                                      onReorder: (oldIndex, newIndex) {
                                        _onGroupReorder(
                                          filteredGroupHabits,
                                          oldIndex,
                                          newIndex,
                                        );
                                      },
                                      itemBuilder: (context, index) {
                                        final habit =
                                            filteredGroupHabits[index];
                                        Future<void>
                                        handleToggleCompletion() async {
                                          final now = DateTime.now();
                                          final uid = provider.userId;
                                          final isQuantified = habit
                                              .isQuantifiedFor(uid);
                                          final quantMin = habit.quantMinFor(
                                            uid,
                                          );
                                          final quantMax = habit.quantMaxFor(
                                            uid,
                                          );
                                          final quantUnit = habit.quantUnitFor(
                                            uid,
                                          );

                                          if (!isQuantified) {
                                            final wasCompleted = habit
                                                .isCompletedOnDate(
                                                  provider.userId,
                                                  now,
                                                );
                                            await provider
                                                .toggleHabitCompletion(habit);
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

                                          final value =
                                              await _askQuantifiedValue(
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

                                          await provider.saveQuantifiedProgress(
                                            habit,
                                            value,
                                          );

                                          if (value >= quantMax &&
                                              context.mounted) {
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
                                        }

                                        return ReorderableDelayedDragStartListener(
                                          key: ValueKey(
                                            'group_reorder_${habit.id}',
                                          ),
                                          index: index,
                                          child: _buildHabitSlidable(
                                            context,
                                            provider,
                                            habit,
                                            onToggleCompletion:
                                                handleToggleCompletion,
                                            child: _wrapCompletionMoveAnimation(
                                              habitId: habit.id,
                                              child: HabitCard(
                                                habit: habit,
                                                currentUserId: provider.userId,
                                                margin: EdgeInsets.zero,
                                                showShadow: false,
                                                onCheck: handleToggleCompletion,
                                                onCardTap: () {
                                                  _openGroupForHabit(
                                                    context,
                                                    habit,
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ],
                              if (showPersonal &&
                                  filteredPersonalHabits.isNotEmpty)
                                _buildSectionLabel(
                                  context,
                                  title: 'PERSONAL/SHARED TASKS',
                                  count: filteredPersonalHabits.length,
                                ),
                              if (showPersonal)
                                Column(
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
                                      itemCount: filteredPersonalHabits.length,
                                      onReorder: (oldIndex, newIndex) {
                                        _onPersonalReorder(
                                          filteredPersonalHabits,
                                          oldIndex,
                                          newIndex,
                                        );
                                      },
                                      itemBuilder: (context, index) {
                                        final habit =
                                            filteredPersonalHabits[index];
                                        Future<void>
                                        handleToggleCompletion() async {
                                          final now = DateTime.now();
                                          final uid = provider.userId;
                                          final isQuantified = habit
                                              .isQuantifiedFor(uid);
                                          final quantMin = habit.quantMinFor(
                                            uid,
                                          );
                                          final quantMax = habit.quantMaxFor(
                                            uid,
                                          );
                                          final quantUnit = habit.quantUnitFor(
                                            uid,
                                          );

                                          if (!isQuantified) {
                                            final wasCompleted = habit
                                                .isCompletedOnDate(
                                                  provider.userId,
                                                  now,
                                                );
                                            await provider
                                                .toggleHabitCompletion(habit);
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

                                          final value =
                                              await _askQuantifiedValue(
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

                                          await provider.saveQuantifiedProgress(
                                            habit,
                                            value,
                                          );

                                          if (value >= quantMax &&
                                              context.mounted) {
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
                                        }

                                        return ReorderableDelayedDragStartListener(
                                          key: ValueKey(
                                            'personal_reorder_${habit.id}',
                                          ),
                                          index: index,
                                          child: _buildHabitSlidable(
                                            context,
                                            provider,
                                            habit,
                                            onToggleCompletion:
                                                handleToggleCompletion,
                                            child: _wrapCompletionMoveAnimation(
                                              habitId: habit.id,
                                              child: HabitCard(
                                                habit: habit,
                                                currentUserId: provider.userId,
                                                margin: EdgeInsets.zero,
                                                showShadow: false,
                                                onCheck: handleToggleCompletion,
                                                onCardTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          HabitLeaderboardScreen(
                                                            habit: habit,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              const SizedBox(
                                height: DashboardScreen._bottomNavClearance,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
