import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../models/group.dart';
import '../models/group_task.dart';
import '../services/database_service.dart';
import '../services/group_service.dart';
import '../services/group_migration_service.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';


class HabitsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final GroupService _groupService = GroupService();
  StreamSubscription<List<Habit>>? _habitSubscription;
  StreamSubscription<List<Group>>? _groupsSubscription;
  StreamSubscription<User?>? _authSubscription;
  final Map<String, StreamSubscription<List<GroupTask>>> _groupTaskSubscriptions =
      <String, StreamSubscription<List<GroupTask>>>{};
  final Map<String, List<Habit>> _groupHabitsByGroupId =
      <String, List<Habit>>{};
  bool _permissionRetryScheduled = false;
  List<Habit> _baseHabits = [];
  bool _baseLoaded = false;
  bool _groupsLoaded = false;

  List<Habit> _habits = [];
  bool _isLoading = true;
  String? _error;

  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get userId => _db.userId;

  HabitsProvider() {
    _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((_) {
      unawaited(GroupMigrationService().migrateLegacyGroupsForCurrentUser());
      _initStream();
    });
    unawaited(GroupMigrationService().migrateLegacyGroupsForCurrentUser());
    _initStream();
  }

  void _initStream() {
    _habitSubscription?.cancel();
    _groupsSubscription?.cancel();
    for (final sub in _groupTaskSubscriptions.values) {
      sub.cancel();
    }
    _groupTaskSubscriptions.clear();
    _groupHabitsByGroupId.clear();
    _baseHabits = [];
    _baseLoaded = false;
    _groupsLoaded = false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    _habitSubscription = _db.streamHabits().listen(
      (data) {
        _baseHabits = data;
        _baseLoaded = true;
        _permissionRetryScheduled = false;
        _error = null;
        _publishMergedHabits();
      },
      onError: (err) {
        _handleStreamError(err);
      },
    );

    _groupsSubscription = _groupService.streamGroupsForCurrentUser().listen(
      (groups) {
        _groupsLoaded = true;
        _permissionRetryScheduled = false;
        _error = null;
        _bindGroupTaskStreams(groups);
      },
      onError: (err) {
        _handleStreamError(err);
      },
    );
  }

  void _handleStreamError(Object err) {
    final message = err.toString();
    if (message.contains('permission-denied')) {
      if (!_permissionRetryScheduled) {
        _permissionRetryScheduled = true;
        Future<void>.delayed(const Duration(seconds: 2), () {
          _permissionRetryScheduled = false;
          _initStream();
        });
      }
      _error = null;
      _isLoading = true;
      notifyListeners();
      return;
    }

    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  void _bindGroupTaskStreams(List<Group> groups) {
    final activeGroupIds = groups.map((group) => group.id).toSet();

    final subscriptionsToRemove = _groupTaskSubscriptions.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in subscriptionsToRemove) {
      _groupTaskSubscriptions[groupId]?.cancel();
      _groupTaskSubscriptions.remove(groupId);
      _groupHabitsByGroupId.remove(groupId);
    }

    for (final group in groups) {
      if (_groupTaskSubscriptions.containsKey(group.id)) {
        continue;
      }

      _groupTaskSubscriptions[group.id] =
          _groupService.streamGroupTasks(group.id).listen(
                (tasks) {
                  _permissionRetryScheduled = false;
                  _groupHabitsByGroupId[group.id] = tasks
                      .map((task) => _habitFromGroupTask(group, task))
                      .toList();
                  _publishMergedHabits();
                },
                onError: (err) {
                  _handleStreamError(err);
                },
              );
    }

    _publishMergedHabits();
  }

  Habit _habitFromGroupTask(Group group, GroupTask task) {
    return Habit(
      id: task.id,
      groupEntityId: group.id,
      title: task.title,
      description: task.description,
      createdAt: task.createdAt,
      completions: task.completions,
      quantifiedValues: task.quantifiedValues,
      participants: List<String>.from(group.memberIds),
      targetDaysPerWeek: 7,
      spaceType: HabitSpaceType.group,
      groupName: group.name,
      isQuantified: task.isQuantified,
      quantUnit: task.quantUnit,
      quantMin: 0,
      quantMax: task.quantMax,
      groupTaskMode: GroupTaskMode.shared,
      memberTasks: const {},
      memberIsQuantified: const {},
      memberQuantUnits: const {},
      memberQuantMax: const {},
      requiresPhotoValidation: false,
      reminderTime: null,
    );
  }

  void _publishMergedHabits() {
    final merged = <Habit>[..._baseHabits];
    for (final habits in _groupHabitsByGroupId.values) {
      merged.addAll(habits);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _habits = merged;
    _isLoading = !(_baseLoaded && _groupsLoaded);
    notifyListeners();
    NotificationService().scheduleAllHabitReminders();
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
      action: () => _persistHabit(updatedHabit),
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
      action: () => _persistHabit(updatedHabit),
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
      action: () => _persistHabit(updatedHabit),
    );
  }

  Future<void> _persistHabit(Habit habit) async {
    if (habit.isGroup && (habit.groupEntityId ?? '').trim().isNotEmpty) {
      final groupId = habit.groupEntityId!.trim();
      final existingTask = await _groupService.getGroupTaskById(groupId, habit.id);
      if (existingTask != null) {
        await _groupService.saveGroupTask(
          existingTask.copyWith(
            title: habit.title,
            description: habit.description,
            completions: habit.completions,
            quantifiedValues: habit.quantifiedValues,
            isQuantified: habit.isQuantified,
            quantUnit: habit.quantUnit,
            quantMax: habit.quantMax,
          ),
        );
        return;
      }
    }

    await _db.saveHabit(habit);
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

  Future<void> deleteHabit(Habit habit) async {
    final uid = _db.userId;

    if (habit.isGroup && (habit.groupEntityId ?? '').trim().isNotEmpty) {
      final groupId = habit.groupEntityId!.trim();
      final group = await _groupService.getGroupById(groupId);
      if (group == null) {
        throw StateError('Group not found.');
      }
      if (group.ownerId != uid) {
        throw StateError('Only the group admin can delete group tasks.');
      }

      await _groupService.deleteGroupTask(groupId, habit.id);
      return;
    }

    if (habit.participants.length <= 1) {
      // True delete only when this user is the last participant.
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

    if (!habit.participants.contains(uid)) {
      return;
    }

    final remainingParticipants =
        List<String>.from(habit.participants)..remove(uid);
    final updatedHabit = habit.copyWith(
      participants: remainingParticipants,
      completions: Map<String, List<DateTime>>.from(habit.completions)
        ..remove(uid),
      quantifiedValues: Map<String, Map<String, double>>.from(
        habit.quantifiedValues,
      )..remove(uid),
      memberTasks: Map<String, String>.from(habit.memberTasks)..remove(uid),
      memberIsQuantified: Map<String, bool>.from(habit.memberIsQuantified)
        ..remove(uid),
      memberQuantUnits: Map<String, String>.from(habit.memberQuantUnits)
        ..remove(uid),
      memberQuantMax: Map<String, double>.from(habit.memberQuantMax)
        ..remove(uid),
    );

    // If current user leaves a shared habit, remove it from local list
    // immediately so list items (e.g. Dismissible) do not keep stale keys.
    final previousHabits = List<Habit>.from(_habits);
    _habits.removeWhere((h) => h.id == habit.id);
    notifyListeners();

    try {
      await _db.saveHabit(
        updatedHabit,
        ensureCurrentUserParticipant: false,
      );
    } catch (_) {
      _habits = previousHabits;
      notifyListeners();
      rethrow;
    }

    await _notifyParticipantDeparture(
      habit: habit,
      remainingParticipants: remainingParticipants,
    );
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

    final groupId = (habit.groupEntityId ?? '').trim();
    if (groupId.isNotEmpty) {
      await _groupService.leaveGroup(groupId);
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

    // User is leaving this group, so optimistically remove from local list.
    final previousHabits = List<Habit>.from(_habits);
    _habits.removeWhere((h) => h.id == habit.id);
    notifyListeners();

    try {
      await _db.saveHabit(
        updatedHabit,
        ensureCurrentUserParticipant: false,
      );
    } catch (_) {
      _habits = previousHabits;
      notifyListeners();
      rethrow;
    }

    await _notifyParticipantDeparture(
      habit: habit,
      remainingParticipants: newParticipants,
    );
  }

  Future<bool> rejoinSharedHabit(Habit habit) async {
    if (habit.isGroup) {
      return false;
    }

    final uid = _db.userId;
    if (uid.isEmpty) {
      return false;
    }

    final latestHabit = await _db.getHabitById(habit.id);
    if (latestHabit == null || latestHabit.isGroup) {
      return false;
    }

    if (latestHabit.participants.contains(uid)) {
      return true;
    }

    final updatedHabit = latestHabit.copyWith(
      participants: [...latestHabit.participants, uid],
    );

    await _db.saveHabit(updatedHabit);
    return true;
  }

  Future<void> _notifyParticipantDeparture({
    required Habit habit,
    required List<String> remainingParticipants,
  }) async {
    if (remainingParticipants.isEmpty) {
      return;
    }

    try {
      await SocialService().notifyHabitParticipantLeft(
        habit: habit,
        departingUserId: _db.userId,
        remainingParticipantIds: remainingParticipants,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to notify participants about departure: $e');
      }
    }
  }

  @override
  void dispose() {
    _habitSubscription?.cancel();
    _groupsSubscription?.cancel();
    for (final sub in _groupTaskSubscriptions.values) {
      sub.cancel();
    }
    _authSubscription?.cancel();
    super.dispose();
  }
}
