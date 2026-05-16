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
  final Map<String, StreamSubscription<List<GroupTask>>>
  _groupTaskSubscriptions = <String, StreamSubscription<List<GroupTask>>>{};
  final Map<String, List<Habit>> _groupHabitsByGroupId =
      <String, List<Habit>>{};
  bool _permissionRetryScheduled = false;
  List<Habit> _baseHabits = [];
  bool _baseLoaded = false;
  bool _groupsLoaded = false;

  List<Habit> _habits = [];
  Map<String, Habit> _habitLookup = <String, Habit>{};
  bool _isLoading = true;
  String? _error;

  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Habit? habitById(String id) => _habitLookup[id];

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

      _groupTaskSubscriptions[group.id] = _groupService
          .streamGroupTasks(group.id)
          .listen(
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
    final stabilized = _stabilizeHabitInstances(merged);
    final nextIsLoading = !(_baseLoaded && _groupsLoaded);
    final didHabitsChange = !_sameHabitIdentityList(_habits, stabilized);
    final didLoadingChange = _isLoading != nextIsLoading;

    _replaceHabits(stabilized, notify: didHabitsChange);
    _isLoading = nextIsLoading;

    if (didLoadingChange && !didHabitsChange) {
      notifyListeners();
    }

    _refreshReminderSchedule(reason: 'habits_provider_publish');
  }

  void _refreshReminderSchedule({required String reason, bool force = false}) {
    unawaited(
      NotificationService()
          .refreshReminderSchedule(
            habitsOverride: List<Habit>.from(_habits),
            reason: reason,
            force: force,
          )
          .catchError((error) {
            if (kDebugMode) {
              debugPrint(
                'HabitsProvider: Reminder refresh failed ($reason): $error',
              );
            }
          }),
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
      final existingTask = await _groupService.getGroupTaskById(
        groupId,
        habit.id,
      );
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

    final now = DateTime.now();
    final updates = <String, Habit>{};
    for (final habit in stepsHabits) {
      final existingValue = habit.completionValueFor(uid, now) ?? 0;
      if (steps <= existingValue) {
        continue;
      }

      final quantMax = habit.quantMaxFor(uid);
      final normalizedValue = steps.toDouble().clamp(
        habit.quantMinFor(uid),
        quantMax,
      );
      final todayKey = habit.dateKeyFor(now);

      final newCompletions = Map<String, List<DateTime>>.from(habit.completions);
      final newQuantifiedValues = Map<String, Map<String, double>>.from(
        habit.quantifiedValues,
      );

      final userCompletions = List<DateTime>.from(newCompletions[uid] ?? []);
      final userValues = Map<String, double>.from(
        newQuantifiedValues[uid] ?? {},
      );

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

      updates[habit.id] = habit.copyWith(
        completions: newCompletions,
        quantifiedValues: newQuantifiedValues,
      );
    }

    if (updates.isEmpty) {
      return;
    }

    final previousHabits = List<Habit>.from(_habits);
    final nextHabits = _habits
        .map((habit) => updates[habit.id] ?? habit)
        .toList(growable: false);

    _replaceHabits(nextHabits);

    try {
      for (final updatedHabit in updates.values) {
        await _persistHabit(updatedHabit);
      }
    } catch (_) {
      _replaceHabits(previousHabits);
      rethrow;
    }
  }

  void _applyOptimisticUpdate(Habit updatedHabit) {
    final index = _habits.indexWhere((h) => h.id == updatedHabit.id);
    if (index != -1) {
      final nextHabits = List<Habit>.from(_habits);
      nextHabits[index] = updatedHabit;
      _replaceHabits(nextHabits);
    }
  }

  void _replaceHabits(List<Habit> nextHabits, {bool notify = true}) {
    _habits = nextHabits;
    _habitLookup = <String, Habit>{
      for (final habit in nextHabits) habit.id: habit,
    };
    if (notify) {
      notifyListeners();
    }
  }

  List<Habit> _stabilizeHabitInstances(List<Habit> nextHabits) {
    if (_habitLookup.isEmpty) {
      return nextHabits;
    }

    return nextHabits.map((habit) {
      final existing = _habitLookup[habit.id];
      if (existing != null && _habitDataEquals(existing, habit)) {
        return existing;
      }
      return habit;
    }).toList(growable: false);
  }

  bool _sameHabitIdentityList(List<Habit> a, List<Habit> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  bool _habitDataEquals(Habit a, Habit b) {
    return a.id == b.id &&
        a.groupEntityId == b.groupEntityId &&
        a.title == b.title &&
        a.description == b.description &&
        a.createdAt.isAtSameMomentAs(b.createdAt) &&
        a.targetDaysPerWeek == b.targetDaysPerWeek &&
        a.spaceType == b.spaceType &&
        a.groupName == b.groupName &&
        a.isQuantified == b.isQuantified &&
        a.quantUnit == b.quantUnit &&
        a.quantMin == b.quantMin &&
        a.quantMax == b.quantMax &&
        a.groupTaskMode == b.groupTaskMode &&
        a.requiresPhotoValidation == b.requiresPhotoValidation &&
        a.reminderTime == b.reminderTime &&
        listEquals(a.participants, b.participants) &&
        listEquals(a.reminderWeekdays, b.reminderWeekdays) &&
        _dateMapEquals(a.completions, b.completions) &&
        _nestedDoubleMapEquals(a.quantifiedValues, b.quantifiedValues) &&
        mapEquals(a.memberTasks, b.memberTasks) &&
        mapEquals(a.memberIsQuantified, b.memberIsQuantified) &&
        mapEquals(a.memberQuantUnits, b.memberQuantUnits) &&
        mapEquals(a.memberQuantMax, b.memberQuantMax);
  }

  bool _dateMapEquals(
    Map<String, List<DateTime>> a,
    Map<String, List<DateTime>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || entry.value.length != other.length) {
        return false;
      }
      for (var i = 0; i < entry.value.length; i++) {
        if (!entry.value[i].isAtSameMomentAs(other[i])) {
          return false;
        }
      }
    }
    return true;
  }

  bool _nestedDoubleMapEquals(
    Map<String, Map<String, double>> a,
    Map<String, Map<String, double>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !mapEquals(entry.value, other)) {
        return false;
      }
    }
    return true;
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
      if (!group.memberIds.contains(uid)) {
        throw StateError('Only group members can delete group tasks.');
      }

      await _groupService.deleteGroupTask(groupId, habit.id);
      return;
    }

    if (habit.participants.length <= 1) {
      // True delete only when this user is the last participant.
      final previousHabits = List<Habit>.from(_habits);
      _replaceHabits(
        List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
      );

      try {
        await _db.deleteHabit(habit.id);
      } catch (_) {
        _replaceHabits(previousHabits);
        rethrow;
      }
      _refreshReminderSchedule(reason: 'habit_deleted');
      return;
    }

    if (!habit.participants.contains(uid)) {
      return;
    }

    final remainingParticipants = List<String>.from(habit.participants)
      ..remove(uid);
    final newSpaceType = (remainingParticipants.length <= 1 && habit.spaceType == HabitSpaceType.sharedTask) ? HabitSpaceType.individual : habit.spaceType;
    final updatedHabit = habit.copyWith(
      spaceType: newSpaceType,
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
    _replaceHabits(
      List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
    );

    try {
      await _db.saveHabit(updatedHabit, ensureCurrentUserParticipant: false);
    } catch (_) {
      _replaceHabits(previousHabits);
      rethrow;
    }

    _refreshReminderSchedule(reason: 'shared_habit_left');

    await _notifyParticipantDeparture(
      habit: habit,
      remainingParticipants: remainingParticipants,
    );
  }

  Future<void> convertToSharedSpace(Habit habit) async {
    if (habit.spaceType != HabitSpaceType.individual) return;

    final updatedHabit = habit.copyWith(spaceType: HabitSpaceType.sharedTask);

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
      _replaceHabits(
        List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
      );
      try {
        await _db.deleteHabit(habit.id);
      } catch (_) {
        _replaceHabits(previousHabits);
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
    _replaceHabits(
      List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
    );

    try {
      await _db.saveHabit(updatedHabit, ensureCurrentUserParticipant: false);
    } catch (_) {
      _replaceHabits(previousHabits);
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
