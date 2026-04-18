import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group.dart';
import '../models/group_task.dart';
import '../models/habit.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _hiddenGroupsKeyPrefix = 'hidden_groups_';

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _hiddenGroupsPrefsKey => '$_hiddenGroupsKeyPrefix$userId';

  Future<Set<String>> _loadHiddenGroupIds() async {
    final uid = userId;
    if (uid.isEmpty) {
      return <String>{};
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenGroupsPrefsKey)?.toSet() ?? <String>{};
  }

  Future<void> _saveHiddenGroupIds(Set<String> groupIds) async {
    final uid = userId;
    if (uid.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenGroupsPrefsKey, groupIds.toList());
  }

  Future<void> markGroupHidden(String groupId) async {
    final normalized = groupId.trim();
    if (normalized.isEmpty) {
      return;
    }

    final hiddenIds = await _loadHiddenGroupIds();
    hiddenIds.add(normalized);
    await _saveHiddenGroupIds(hiddenIds);
  }

  Future<void> clearHiddenGroup(String groupId) async {
    final normalized = groupId.trim();
    if (normalized.isEmpty) {
      return;
    }

    final hiddenIds = await _loadHiddenGroupIds();
    if (!hiddenIds.remove(normalized)) {
      return;
    }
    await _saveHiddenGroupIds(hiddenIds);
  }

  String createGroupId() => _db.collection('groups').doc().id;

  String createGroupTaskId(String groupId) {
    return _db.collection('groups').doc(groupId).collection('tasks').doc().id;
  }

  Stream<List<Group>> streamGroupsForCurrentUser() {
    if (userId.isEmpty) {
      return Stream.value(const <Group>[]);
    }

    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final hiddenGroupIds = await _loadHiddenGroupIds();
          return snapshot.docs
              .map((doc) => Group.fromMap(doc.data(), id: doc.id))
              .where((group) => !hiddenGroupIds.contains(group.id))
              .where((group) => !group.leftMemberIds.contains(userId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
  }

  Future<Group?> getGroupById(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Group.fromMap(doc.data()!, id: doc.id);
  }

  Future<Group> createGroup({
    required String name,
    String description = '',
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to create groups.');
    }

    final groupId = createGroupId();
    final members = <String>[userId];

    final group = Group(
      id: groupId,
      name: name.trim(),
      description: description.trim(),
      ownerId: userId,
      createdAt: DateTime.now(),
      memberIds: members,
      leftMemberIds: const <String>[],
    );

    await _db.collection('groups').doc(group.id).set(group.toMap());
    return group;
  }

  Future<void> saveGroup(Group group) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to update groups.');
    }

    await _db.collection('groups').doc(group.id).set(group.toMap());
  }

  Future<void> addMemberToGroup(String groupId, String memberId) async {
    if (userId.isEmpty || memberId.trim().isEmpty) {
      return;
    }

    await _db.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([memberId]),
      'leftMemberIds': FieldValue.arrayRemove([memberId]),
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = userId;
    if (uid.isEmpty || groupId.trim().isEmpty) {
      return;
    }

    final groupRef = _db.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists || groupDoc.data() == null) {
      return;
    }

    final group = Group.fromMap(groupDoc.data()!, id: groupDoc.id);
    if (!group.memberIds.contains(uid)) {
      return;
    }

    final remainingMembers = List<String>.from(group.memberIds)
      ..removeWhere((memberId) => memberId == uid);

    if (remainingMembers.isEmpty) {
      final tasksSnapshot = await groupRef.collection('tasks').get();
      final batch = _db.batch();
      for (final taskDoc in tasksSnapshot.docs) {
        batch.delete(taskDoc.reference);
      }
      batch.delete(groupRef);
      await batch.commit();
      await markGroupHidden(groupId);
      return;
    }

    final updates = <String, dynamic>{
      'memberIds': remainingMembers,
      'leftMemberIds': FieldValue.arrayUnion([uid]),
    };

    if (group.ownerId == uid) {
      updates['ownerId'] = remainingMembers.first;
    }

    await groupRef.update(updates);
    await markGroupHidden(groupId);

    // Legacy compatibility: older app versions stored groups in `habits` using
    // the same id. Remove the current user from that participant list so
    // migration does not re-add them to the group on next app launch.
    final legacyGroupHabitRef = _db.collection('habits').doc(groupId);
    try {
      await legacyGroupHabitRef.update({
        'participants': FieldValue.arrayRemove([uid]),
      });
    } on FirebaseException catch (error) {
      // `not-found` is expected when no legacy habit mirror exists.
      if (error.code != 'not-found') {
        rethrow;
      }
    }
  }

  Stream<List<GroupTask>> streamGroupTasks(String groupId) {
    if (groupId.trim().isEmpty) {
      return Stream.value(const <GroupTask>[]);
    }

    return _db
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupTask.fromMap(doc.data(), id: doc.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<GroupTask?> getGroupTaskById(String groupId, String taskId) async {
    if (groupId.trim().isEmpty || taskId.trim().isEmpty) {
      return null;
    }

    final doc = await _db
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .doc(taskId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return GroupTask.fromMap(doc.data()!, id: doc.id);
  }

  Future<GroupTask?> findGroupTaskByTaskId(String taskId) async {
    if (taskId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _db
        .collectionGroup('tasks')
        .where('id', isEqualTo: taskId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty || snapshot.docs.first.data().isEmpty) {
      return null;
    }

    return GroupTask.fromMap(snapshot.docs.first.data(), id: snapshot.docs.first.id);
  }

  Future<void> syncTaskMirrorsForGroup(String groupId) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      return;
    }

    final tasks = await _db
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .get();

    for (final taskDoc in tasks.docs) {
      final task = GroupTask.fromMap(taskDoc.data(), id: taskDoc.id);
      await _upsertTaskHabitMirror(task, group: group);
    }
  }

  Future<GroupTask> createGroupTask({
    required String groupId,
    required String title,
    String description = '',
    bool isQuantified = false,
    String quantUnit = 'units',
    double quantMax = 10,
    List<String> assigneeIds = const <String>[],
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to create group tasks.');
    }

    final taskId = createGroupTaskId(groupId);
    final task = GroupTask(
      id: taskId,
      groupId: groupId,
      title: title.trim(),
      description: description.trim(),
      createdAt: DateTime.now(),
      createdBy: userId,
      assigneeIds: assigneeIds,
      isQuantified: isQuantified,
      quantUnit: quantUnit,
      quantMax: quantMax,
      completions: const <String, List<DateTime>>{},
      quantifiedValues: const <String, Map<String, double>>{},
    );

    await _db
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .doc(task.id)
        .set(task.toMap());

    final group = await getGroupById(groupId);
    if (group != null) {
      await _upsertTaskHabitMirror(task, group: group);
    }

    return task;
  }

  Future<void> saveGroupTask(GroupTask task) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to update group tasks.');
    }

    await _db
        .collection('groups')
        .doc(task.groupId)
        .collection('tasks')
        .doc(task.id)
        .set(task.toMap());

    final group = await getGroupById(task.groupId);
    if (group != null) {
      await _upsertTaskHabitMirror(task, group: group);
    }
  }

  Future<void> deleteGroupTask(String groupId, String taskId) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to delete group tasks.');
    }

    final group = await getGroupById(groupId);
    if (group == null) {
      throw StateError('Group not found.');
    }

    if (group.ownerId != userId) {
      throw StateError('Only the group admin can delete tasks.');
    }

    await _db
        .collection('groups')
        .doc(groupId)
        .collection('tasks')
        .doc(taskId)
        .delete();

    await _db.collection('habits').doc(taskId).delete();
  }

  Future<void> toggleCheckboxTaskCompletion(GroupTask task) async {
    final uid = userId;
    if (uid.isEmpty) {
      throw StateError('You must be signed in to update group tasks.');
    }

    if (task.isQuantified) {
      return;
    }

    final now = DateTime.now();
    final updatedCompletions = <String, List<DateTime>>{};
    task.completions.forEach((key, value) {
      updatedCompletions[key] = List<DateTime>.from(value);
    });

    final userDates = List<DateTime>.from(updatedCompletions[uid] ?? const []);
    final hadToday = userDates.any(
      (date) =>
          date.year == now.year && date.month == now.month && date.day == now.day,
    );

    userDates.removeWhere(
      (date) =>
          date.year == now.year && date.month == now.month && date.day == now.day,
    );

    if (!hadToday) {
      userDates.add(now);
    }

    updatedCompletions[uid] = userDates;

    final updatedTask = task.copyWith(completions: updatedCompletions);
    await saveGroupTask(updatedTask);
  }

  Future<void> _upsertTaskHabitMirror(
    GroupTask task, {
    required Group group,
  }) async {
    final mirror = Habit(
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

    await _db.collection('habits').doc(task.id).set(mirror.toMap());
  }
}
