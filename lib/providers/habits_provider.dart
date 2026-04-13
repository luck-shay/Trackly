import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';

class HabitsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  StreamSubscription<List<Habit>>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  List<Habit> _habits = [];
  bool _isLoading = true;
  String? _error;

  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get userId => _db.userId;

  HabitsProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      _initStream();
    });
    _initStream();
  }

  void _initStream() {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _db.streamHabits().listen(
      (data) {
        _habits = data;
        _habits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (err) {
        _error = err.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> toggleHabitCompletion(Habit habit) async {
    final now = DateTime.now();
    final uid = _db.userId;
    if (habit.isCompletedOnDate(_db.userId, now)) {
      return clearTodayProgress(habit);
    }

    if (habit.isQuantifiedFor(uid)) {
      return;
    }

    return logHabitCompletion(habit);
  }

  Future<void> logHabitCompletion(
    Habit habit, {
    double? quantifiedValue,
  }) async {
    final uid = _db.userId;
    if (habit.isQuantifiedFor(uid) && quantifiedValue != null) {
      return saveQuantifiedProgress(habit, quantifiedValue);
    }

    DateTime now = DateTime.now();
    bool foundToday = false;

    // Copy completions to mutate
    final newCompletions = Map<String, List<DateTime>>.from(habit.completions);
    final newQuantifiedValues = Map<String, Map<String, double>>.from(
      habit.quantifiedValues,
    );

    if (!newCompletions.containsKey(uid)) {
      newCompletions[uid] = [];
    }

    newQuantifiedValues[uid] = Map<String, double>.from(
      newQuantifiedValues[uid] ?? {},
    );

    final userCompletions = List<DateTime>.from(newCompletions[uid]!);

    for (int i = 0; i < userCompletions.length; i++) {
      var date = userCompletions[i];
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        userCompletions.removeAt(i);
        newQuantifiedValues[uid]!.remove(habit.dateKeyFor(now));
        foundToday = true;
        break;
      }
    }

    if (!foundToday) {
      userCompletions.add(now);
      if (habit.isQuantifiedFor(uid) && quantifiedValue != null) {
        newQuantifiedValues[uid]![habit.dateKeyFor(now)] = quantifiedValue;
      }
    }

    newCompletions[uid] = userCompletions;
    final updatedHabit = habit.copyWith(
      completions: newCompletions,
      quantifiedValues: newQuantifiedValues,
    );

    await _runWithRollback(
      previousHabit: habit,
      updatedHabit: updatedHabit,
      action: () => _db.saveHabit(updatedHabit),
    );
  }

  Future<void> clearTodayProgress(Habit habit) async {
    final now = DateTime.now();
    final uid = _db.userId;

    final newCompletions = Map<String, List<DateTime>>.from(habit.completions);
    final newQuantifiedValues = Map<String, Map<String, double>>.from(
      habit.quantifiedValues,
    );

    final userCompletions = List<DateTime>.from(newCompletions[uid] ?? []);
    userCompletions.removeWhere(
      (date) =>
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day,
    );
    newCompletions[uid] = userCompletions;

    final userValues = Map<String, double>.from(newQuantifiedValues[uid] ?? {});
    userValues.remove(habit.dateKeyFor(now));
    newQuantifiedValues[uid] = userValues;

    final updatedHabit = habit.copyWith(
      completions: newCompletions,
      quantifiedValues: newQuantifiedValues,
    );

    await _runWithRollback(
      previousHabit: habit,
      updatedHabit: updatedHabit,
      action: () => _db.saveHabit(updatedHabit),
    );
  }

  Future<void> saveQuantifiedProgress(Habit habit, double value) async {
    final now = DateTime.now();
    final uid = _db.userId;
    final quantMin = habit.quantMinFor(uid);
    final quantMax = habit.quantMaxFor(uid);
    final normalizedValue = value.clamp(quantMin, quantMax).toDouble();

    final newCompletions = Map<String, List<DateTime>>.from(habit.completions);
    final newQuantifiedValues = Map<String, Map<String, double>>.from(
      habit.quantifiedValues,
    );

    final userCompletions = List<DateTime>.from(newCompletions[uid] ?? []);
    final userValues = Map<String, double>.from(newQuantifiedValues[uid] ?? {});
    final todayKey = habit.dateKeyFor(now);

    userValues[todayKey] = normalizedValue;

    userCompletions.removeWhere(
      (date) =>
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day,
    );

    if (normalizedValue >= quantMax) {
      userCompletions.add(now);
    }

    newCompletions[uid] = userCompletions;
    newQuantifiedValues[uid] = userValues;

    final updatedHabit = habit.copyWith(
      completions: newCompletions,
      quantifiedValues: newQuantifiedValues,
    );

    await _runWithRollback(
      previousHabit: habit,
      updatedHabit: updatedHabit,
      action: () => _db.saveHabit(updatedHabit),
    );
  }

  Future<void> syncHealthDataForStepsHabits() async {
    final uid = _db.userId;
    if (uid.isEmpty) return;

    final stepsHabits = _habits
        .where(
          (habit) =>
              habit.isQuantifiedFor(uid) &&
              habit.quantUnitFor(uid).toLowerCase() == 'steps',
        )
        .toList();
    if (stepsHabits.isEmpty) {
      return;
    }

    final healthService = HealthService();
    final hasPerms = await healthService.requestPermissions();
    if (!hasPerms) return;

    final steps = await healthService.fetchStepsForToday();
    if (steps == 0) return;

    for (final habit in stepsHabits) {
      final existingValue = habit.completionValueFor(uid, DateTime.now()) ?? 0;
      if (steps > existingValue) {
        // Optimization: only update if steps have increased.
        await saveQuantifiedProgress(habit, steps.toDouble());
      }
    }
  }


  void _applyOptimisticUpdate(Habit updatedHabit) {
    final index = _habits.indexWhere((h) => h.id == updatedHabit.id);
    if (index != -1) {
      _habits[index] = updatedHabit;
      notifyListeners();
    }
  }

  Future<void> _runWithRollback({
    required Habit previousHabit,
    required Habit updatedHabit,
    required Future<void> Function() action,
  }) async {
    _applyOptimisticUpdate(updatedHabit);
    try {
      await action();
    } catch (_) {
      _applyOptimisticUpdate(previousHabit);
      rethrow;
    }
  }

  Future<void> deleteHabit(String habitId) async {
    // Optimistic delete
    final previousHabits = List<Habit>.from(_habits);
    _habits.removeWhere((h) => h.id == habitId);
    notifyListeners();

    try {
      await _db.deleteHabit(habitId);
    } catch (_) {
      _habits = previousHabits;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> convertToSharedSpace(Habit habit) async {
    if (habit.spaceType != HabitSpaceType.individual) return;
    
    final updatedHabit = habit.copyWith(
      spaceType: HabitSpaceType.sharedTask,
    );
    
    await _runWithRollback(
      previousHabit: habit,
      updatedHabit: updatedHabit,
      action: () => _db.saveHabit(updatedHabit),
    );
  }

  Future<void> updateMyGroupTask(
    Habit habit,
    String task, {
    bool? isQuantified,
    String? quantUnit,
    double? quantMax,
  }) async {
    if (!habit.isGroup || !habit.hasMemberDefinedGroupTasks) {
      return;
    }

    final uid = _db.userId;
    final trimmed = task.trim();
    final newMemberTasks = Map<String, String>.from(habit.memberTasks);
    final newMemberIsQuantified = Map<String, bool>.from(
      habit.memberIsQuantified,
    );
    final newMemberQuantUnits = Map<String, String>.from(
      habit.memberQuantUnits,
    );
    final newMemberQuantMax = Map<String, double>.from(habit.memberQuantMax);

    if (trimmed.isEmpty) {
      newMemberTasks.remove(uid);
    } else {
      newMemberTasks[uid] = trimmed;
    }

    if (isQuantified != null) {
      newMemberIsQuantified[uid] = isQuantified;
    }
    if (quantUnit != null) {
      newMemberQuantUnits[uid] = quantUnit;
    }
    if (quantMax != null) {
      newMemberQuantMax[uid] = quantMax.clamp(1, 500).toDouble();
    }

    final updatedHabit = habit.copyWith(
      memberTasks: newMemberTasks,
      memberIsQuantified: newMemberIsQuantified,
      memberQuantUnits: newMemberQuantUnits,
      memberQuantMax: newMemberQuantMax,
    );
    await _runWithRollback(
      previousHabit: habit,
      updatedHabit: updatedHabit,
      action: () => _db.saveHabit(updatedHabit),
    );
  }

  Future<void> leaveGroup(Habit habit) async {
    if (!habit.isGroup) {
      return;
    }

    final uid = _db.userId;
    if (!habit.participants.contains(uid)) {
      return;
    }

    final newParticipants = List<String>.from(habit.participants)..remove(uid);
    final newCompletions = Map<String, List<DateTime>>.from(habit.completions)
      ..remove(uid);
    final newQuantifiedValues = Map<String, Map<String, double>>.from(
      habit.quantifiedValues,
    )..remove(uid);
    final newMemberTasks = Map<String, String>.from(habit.memberTasks)
      ..remove(uid);
    final newMemberIsQuantified = Map<String, bool>.from(
      habit.memberIsQuantified,
    )..remove(uid);
    final newMemberQuantUnits = Map<String, String>.from(habit.memberQuantUnits)
      ..remove(uid);
    final newMemberQuantMax = Map<String, double>.from(habit.memberQuantMax)
      ..remove(uid);

    if (newParticipants.isEmpty) {
      final previousHabits = List<Habit>.from(_habits);
      _habits.removeWhere((h) => h.id == habit.id);
      notifyListeners();
      try {
        await _db.deleteHabit(habit.id);
      } catch (_) {
        _habits = previousHabits;
        notifyListeners();
        rethrow;
      }
      return;
    }

    final updatedHabit = habit.copyWith(
      participants: newParticipants,
      completions: newCompletions,
      quantifiedValues: newQuantifiedValues,
      memberTasks: newMemberTasks,
      memberIsQuantified: newMemberIsQuantified,
      memberQuantUnits: newMemberQuantUnits,
      memberQuantMax: newMemberQuantMax,
    );

    await _runWithRollback(
      previousHabit: habit,
      updatedHabit: updatedHabit,
      action: () => _db.saveHabit(
        updatedHabit,
        ensureCurrentUserParticipant: false,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
