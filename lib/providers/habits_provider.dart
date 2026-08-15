import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  StreamSubscription<List<Habit>>? _archivedHabitsSubscription;
  StreamSubscription<List<Group>>? _archivedGroupsSubscription;
  StreamSubscription<User?>? _authSubscription;
  final Map<String, StreamSubscription<List<GroupTask>>>
  _groupTaskSubscriptions = <String, StreamSubscription<List<GroupTask>>>{};
  final Map<String, List<Habit>> _groupHabitsByGroupId =
      <String, List<Habit>>{};
  bool _permissionRetryScheduled = false;
  List<Habit> _baseHabits = [];
  List<Habit> _archivedHabits = [];
  List<Group> _archivedGroups = [];
  bool _baseLoaded = false;
  bool _groupsLoaded = false;
  final Set<String> _pendingRemovalIds = <String>{};
  final Map<String, int> _pendingRemovalTimestamps = <String, int>{};
  bool _pendingRemovalsLoaded = false;
  static const Duration _pendingRemovalTtl = Duration(minutes: 15);

  List<Habit> _habits = [];
  Map<String, Habit> _habitLookup = <String, Habit>{};
  bool _isLoading = true;
  String? _error;

  List<Habit> get habits => _habits;
  List<Habit> get archivedHabits => _archivedHabits;
  List<Group> get archivedGroups => _archivedGroups;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Habit? habitById(String id) => _habitLookup[id];

  String get userId => _db.userId;

  String get _pendingRemovalPrefsKey => 'pending_removed_habits_$userId';

  HabitsProvider() {
    _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((_) {
      unawaited(GroupMigrationService().migrateLegacyGroupsForCurrentUser());
      unawaited(_initStream());
    });
    unawaited(GroupMigrationService().migrateLegacyGroupsForCurrentUser());
    unawaited(_initStream());
  }

  Future<void> _initStream() async {
    _habitSubscription?.cancel();
    _groupsSubscription?.cancel();
    _archivedHabitsSubscription?.cancel();
    _archivedGroupsSubscription?.cancel();
    for (final sub in _groupTaskSubscriptions.values) {
      sub.cancel();
    }
    _groupTaskSubscriptions.clear();
    _groupHabitsByGroupId.clear();
    _baseHabits = [];
    _archivedHabits = [];
    _archivedGroups = [];
    _baseLoaded = false;
    _groupsLoaded = false;
    _pendingRemovalIds.clear();
    _pendingRemovalTimestamps.clear();
    _pendingRemovalsLoaded = false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    await _loadPendingRemovals();

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

    _archivedHabitsSubscription = _db.streamArchivedHabits().listen(
      (archived) {
        _archivedHabits = archived;
        notifyListeners();
      },
      onError: (_) {},
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

    _archivedGroupsSubscription = _groupService
        .streamArchivedGroupsForCurrentUser()
        .listen(
          (archivedGroups) {
            _archivedGroups = archivedGroups;
            notifyListeners();
          },
          onError: (_) {},
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

    _prunePendingRemovals();

    if (_pendingRemovalIds.isNotEmpty) {
      final mergedIds = merged.map((habit) => habit.id).toSet();
      _pendingRemovalIds.removeWhere((id) => !mergedIds.contains(id));
      _pendingRemovalTimestamps.removeWhere((id, _) => !mergedIds.contains(id));
    }

    final filtered = _pendingRemovalIds.isEmpty
        ? merged
        : merged
            .where((habit) => !_pendingRemovalIds.contains(habit.id))
            .toList();

    final scoped = filtered.where(_isHabitInScope).toList();

    scoped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final stabilized = _stabilizeHabitInstances(scoped);
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

  Future<void> toggleChecklistItem(Habit habit, String itemId) async {
    final updatedChecklist = habit.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isCompleted: !item.isCompleted);
      }
      return item;
    }).toList();

    final updatedHabit = habit.copyWith(checklist: updatedChecklist);
    
    // Auto-trigger completion if all items checked
    final allCompleted = updatedChecklist.isNotEmpty &&
        updatedChecklist.every((item) => item.isCompleted);
    final now = DateTime.now();
    if (allCompleted && !habit.isCompletedOnDate(_db.userId, now)) {
      await logHabitCompletion(updatedHabit);
    } else {
      await _db.saveHabit(updatedHabit);
    }
  }

  Future<void> markAllChecklistDone(Habit habit) async {
    final updatedChecklist = habit.checklist.map((item) {
      return item.copyWith(isCompleted: true);
    }).toList();

    final updatedHabit = habit.copyWith(checklist: updatedChecklist);

    final now = DateTime.now();
    if (!habit.isCompletedOnDate(_db.userId, now)) {
      await logHabitCompletion(updatedHabit);
    } else {
      await _db.saveHabit(updatedHabit);
    }
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

      _recordPendingRemoval(habit.id);
      try {
        await _groupService.deleteGroupTask(groupId, habit.id);
      } catch (_) {
        _clearPendingRemoval(habit.id);
        rethrow;
      }
      return;
    }

    final previousHabits = List<Habit>.from(_habits);
    _recordPendingRemoval(habit.id);
    _replaceHabits(
      List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
    );

    try {
      final archivedHabit = habit.copyWith(isArchived: true);
      await _db.saveHabit(archivedHabit, ensureCurrentUserParticipant: false);
    } catch (_) {
      _clearPendingRemoval(habit.id);
      _replaceHabits(previousHabits);
      rethrow;
    }
    _refreshReminderSchedule(reason: 'habit_archived');
  }

  Future<void> restoreHabit(Habit habit) async {
    _clearPendingRemoval(habit.id);
    final restoredHabit = habit.copyWith(isArchived: false);
    await _db.saveHabit(restoredHabit, ensureCurrentUserParticipant: false);
    _refreshReminderSchedule(reason: 'habit_restored');
  }

  Future<void> deleteHabitPermanently(Habit habit) async {
    _recordPendingRemoval(habit.id);
    try {
      if (habit.isGroup && (habit.groupEntityId ?? '').trim().isNotEmpty) {
        await _groupService.deleteGroupTask(habit.groupEntityId!.trim(), habit.id);
      } else {
        await _db.deleteHabit(habit.id);
      }
    } catch (_) {
      _clearPendingRemoval(habit.id);
      rethrow;
    }
    _refreshReminderSchedule(reason: 'habit_deleted_permanently');
  }

  Future<void> archiveGroup(Group group) async {
    await _groupService.archiveGroup(group.id);
  }

  Future<void> restoreGroup(Group group) async {
    await _groupService.restoreGroup(group.id);
  }

  Future<void> deleteGroupPermanently(Group group) async {
    await _groupService.permanentlyDeleteGroup(group.id);
  }

  Future<void> deleteGroupTask(String groupId, String taskId) async {
    final uid = _db.userId;
    final normalizedGroupId = groupId.trim();
    final normalizedTaskId = taskId.trim();
    if (normalizedGroupId.isEmpty || normalizedTaskId.isEmpty) {
      return;
    }

    final group = await _groupService.getGroupById(normalizedGroupId);
    if (group == null) {
      throw StateError('Group not found.');
    }
    if (!group.memberIds.contains(uid)) {
      throw StateError('Only group members can delete group tasks.');
    }

    _recordPendingRemoval(normalizedTaskId);
    _publishMergedHabits();

    try {
      await _groupService.deleteGroupTask(normalizedGroupId, normalizedTaskId);
    } catch (_) {
      _clearPendingRemoval(normalizedTaskId);
      rethrow;
    }
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
      _recordPendingRemoval(habit.id);
      _replaceHabits(
        List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
      );
      try {
        await _db.deleteHabit(habit.id);
      } catch (_) {
        _clearPendingRemoval(habit.id);
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
    _recordPendingRemoval(habit.id);
    _replaceHabits(
      List<Habit>.from(_habits)..removeWhere((h) => h.id == habit.id),
    );

    try {
      await _db.saveHabit(updatedHabit, ensureCurrentUserParticipant: false);
    } catch (_) {
      _clearPendingRemoval(habit.id);
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
    _clearPendingRemoval(habit.id);
    return true;
  }

  bool _isHabitInScope(Habit habit) {
    final uid = userId;
    if (uid.isEmpty) {
      return false;
    }

    if (habit.isGroup) {
      final groupId = (habit.groupEntityId ?? '').trim();
      if (groupId.isEmpty) {
        return false;
      }
      if (!_groupHabitsByGroupId.containsKey(groupId)) {
        return false;
      }
      return habit.participants.contains(uid);
    }

    return habit.participants.contains(uid);
  }

  Future<void> _loadPendingRemovals() async {
    final uid = userId;
    if (uid.isEmpty) {
      _pendingRemovalsLoaded = true;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingRemovalPrefsKey);
    if (raw == null || raw.isEmpty) {
      _pendingRemovalsLoaded = true;
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _pendingRemovalTimestamps
        ..clear()
        ..addAll(
          decoded.map((key, value) => MapEntry(key, value as int)),
        );
      _pendingRemovalIds
        ..clear()
        ..addAll(_pendingRemovalTimestamps.keys);
    }

    _pendingRemovalsLoaded = true;
    _prunePendingRemovals();
    _publishMergedHabits();
  }

  void _recordPendingRemoval(String habitId) {
    final trimmed = habitId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingRemovalIds.add(trimmed);
    _pendingRemovalTimestamps[trimmed] = DateTime.now().millisecondsSinceEpoch;
    unawaited(_savePendingRemovals());
  }

  void _clearPendingRemoval(String habitId) {
    final trimmed = habitId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingRemovalIds.remove(trimmed);
    _pendingRemovalTimestamps.remove(trimmed);
    unawaited(_savePendingRemovals());
  }

  void _prunePendingRemovals() {
    if (!_pendingRemovalsLoaded) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoff = nowMs - _pendingRemovalTtl.inMilliseconds;
    final expired = _pendingRemovalTimestamps.entries
        .where((entry) => entry.value < cutoff)
        .map((entry) => entry.key)
        .toList();
    if (expired.isEmpty) {
      return;
    }
    for (final id in expired) {
      _pendingRemovalTimestamps.remove(id);
      _pendingRemovalIds.remove(id);
    }
    unawaited(_savePendingRemovals());
  }

  Future<void> _savePendingRemovals() async {
    final uid = userId;
    if (uid.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_pendingRemovalTimestamps);
    await prefs.setString(_pendingRemovalPrefsKey, payload);
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
    _archivedHabitsSubscription?.cancel();
    _archivedGroupsSubscription?.cancel();
    for (final sub in _groupTaskSubscriptions.values) {
      sub.cancel();
    }
    _authSubscription?.cancel();
    super.dispose();
  }
}
