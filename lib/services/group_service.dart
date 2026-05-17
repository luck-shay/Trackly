import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group.dart';
import '../models/group_challenge.dart';
import '../models/group_task.dart';
import '../models/habit.dart';
import 'subscription_exceptions.dart';
import 'subscription_service.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
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

  String createGroupChallengeId(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc()
        .id;
  }

  Stream<List<GroupChallenge>> streamMyChallenges() {
    if (userId.isEmpty) {
      return Stream.value(const <GroupChallenge>[]);
    }

    return _db
        .collectionGroup('challenges')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GroupChallenge.fromMap(doc.data(), id: doc.id))
                  .toList()
                ..sort((a, b) {
                  if (a.isActive != b.isActive) {
                    return a.isActive ? -1 : 1;
                  }
                  return b.createdAt.compareTo(a.createdAt);
                }),
        );
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

    final hasAccess = await _subscriptionService.hasPremiumAccess(userId);
    if (!hasAccess) {
      throw const UpgradeRequiredException(
        'Trackly Pro is required to create groups.',
      );
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

    await markGroupHidden(groupId);
    try {
      await _db.runTransaction((transaction) async {
        final latestDoc = await transaction.get(groupRef);
        if (!latestDoc.exists || latestDoc.data() == null) {
          return;
        }

        final latestGroup = Group.fromMap(latestDoc.data()!, id: latestDoc.id);
        if (!latestGroup.memberIds.contains(uid)) {
          return;
        }

        final latestRemainingMembers = List<String>.from(latestGroup.memberIds)
          ..removeWhere((memberId) => memberId == uid);
        if (latestRemainingMembers.isEmpty) {
          throw StateError('Cannot leave group with no remaining owner.');
        }

        final updates = <String, dynamic>{
          'memberIds': latestRemainingMembers,
          'leftMemberIds': FieldValue.arrayUnion([uid]),
        };

        if (latestGroup.ownerId == uid) {
          updates['ownerId'] = latestRemainingMembers.first;
        }

        transaction.update(groupRef, updates);
      });
    } catch (_) {
      await clearHiddenGroup(groupId);
      rethrow;
    }

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
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GroupTask.fromMap(doc.data(), id: doc.id))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<GroupChallenge>> streamGroupChallenges(String groupId) {
    if (groupId.trim().isEmpty) {
      return Stream.value(const <GroupChallenge>[]);
    }

    return _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GroupChallenge.fromMap(doc.data(), id: doc.id))
                  .toList()
                ..sort((a, b) {
                  final aEnded = a.hasEnded;
                  final bEnded = b.hasEnded;
                  if (aEnded != bEnded) {
                    return aEnded ? 1 : -1;
                  }
                  return b.createdAt.compareTo(a.createdAt);
                }),
        );
  }

  Future<GroupChallenge?> getGroupChallengeById(
    String groupId,
    String challengeId,
  ) async {
    if (groupId.trim().isEmpty || challengeId.trim().isEmpty) {
      return null;
    }

    final doc = await _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc(challengeId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return GroupChallenge.fromMap(doc.data()!, id: doc.id);
  }

  Future<GroupChallenge> createGroupChallenge({
    required String groupId,
    required String title,
    String description = '',
    required List<String> participantIds,
    required String unit,
    required double targetValue,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to create challenges.');
    }

    if (title.trim().isEmpty) {
      throw StateError('Challenge title cannot be empty.');
    }

    if (endAt.isBefore(startAt) || endAt.isAtSameMomentAs(startAt)) {
      throw StateError('Challenge end time must be after start time.');
    }

    final selectedMembers = <String>{
      for (final uid in participantIds)
        if (uid.trim().isNotEmpty) uid.trim(),
      userId,
    }.toList();

    final group = await getGroupById(groupId);
    if (group == null) {
      throw StateError('Group not found.');
    }

    for (final uid in selectedMembers) {
      if (!group.memberIds.contains(uid)) {
        throw StateError('All challenge participants must be group members.');
      }
    }

    final inviteeIds = selectedMembers.where((uid) => uid != userId).toList();
    if (inviteeIds.isEmpty) {
      throw StateError('Select at least one member to challenge.');
    }

    final challengeId = createGroupChallengeId(groupId);
    final challenge = GroupChallenge(
      id: challengeId,
      groupId: groupId,
      title: title.trim(),
      description: description.trim(),
      createdBy: userId,
      createdAt: DateTime.now(),
      startAt: startAt,
      endAt: endAt,
      participantIds: <String>[userId],
      unit: unit.trim(),
      targetValue: targetValue < 0 ? 0 : targetValue,
      progressLogs: const <String, Map<String, double>>{},
    );

    final batch = _db.batch();

    final challengeRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc(challenge.id);
    batch.set(challengeRef, challenge.toMap());

    for (final inviteeId in inviteeIds) {
      final inviteRef = _db.collection('challengeInvites').doc();
      batch.set(inviteRef, {
        'from': userId,
        'to': inviteeId,
        'groupId': groupId,
        'challengeId': challenge.id,
        'challengeTitle': challenge.title,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    return challenge;
  }

  Future<void> endGroupChallenge(GroupChallenge challenge) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to end challenges.');
    }

    final group = await getGroupById(challenge.groupId);
    if (group == null) {
      throw StateError('Group not found.');
    }
    if (!group.memberIds.contains(userId)) {
      throw StateError('Only group members can end challenges.');
    }

    await _db
        .collection('groups')
        .doc(challenge.groupId)
        .collection('challenges')
        .doc(challenge.id)
        .update({'endAt': DateTime.now().toIso8601String()});
  }

  Future<void> acceptChallengeInvite({
    required String inviteId,
    required String groupId,
    required String challengeId,
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to accept challenge invites.');
    }

    final challengeRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('challenges')
        .doc(challengeId);
    final inviteRef = _db.collection('challengeInvites').doc(inviteId);

    await _db.runTransaction((txn) async {
      final challengeSnap = await txn.get(challengeRef);
      final inviteSnap = await txn.get(inviteRef);

      if (!inviteSnap.exists || inviteSnap.data() == null) {
        throw StateError('Invite no longer exists.');
      }
      final invite = inviteSnap.data()!;
      if ((invite['to'] as String? ?? '') != userId) {
        throw StateError('This invite is not for you.');
      }
      if ((invite['status'] as String? ?? 'pending') != 'pending') {
        return;
      }

      if (!challengeSnap.exists || challengeSnap.data() == null) {
        txn.update(inviteRef, {'status': 'declined'});
        return;
      }

      final challenge = GroupChallenge.fromMap(
        challengeSnap.data()!,
        id: challengeSnap.id,
      );

      final nextParticipants = <String>{
        ...challenge.participantIds,
        userId,
      }.toList();

      txn.update(challengeRef, {'participantIds': nextParticipants});
      txn.update(inviteRef, {'status': 'accepted'});
    });
  }

  Future<void> declineChallengeInvite(String inviteId) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to decline challenge invites.');
    }

    await _db.collection('challengeInvites').doc(inviteId).update({
      'status': 'declined',
    });
  }

  Future<void> saveGroupChallenge(GroupChallenge challenge) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to update challenges.');
    }

    await _db
        .collection('groups')
        .doc(challenge.groupId)
        .collection('challenges')
        .doc(challenge.id)
        .set(challenge.toMap());
  }

  Future<GroupChallenge> addChallengeProgress({
    required GroupChallenge challenge,
    required double delta,
    DateTime? day,
  }) async {
    final uid = userId;
    if (uid.isEmpty) {
      throw StateError('You must be signed in to log challenge progress.');
    }

    if (!challenge.participantIds.contains(uid)) {
      throw StateError('Only challenge participants can log progress.');
    }

    final now = day ?? DateTime.now();
    if (now.isBefore(challenge.startAt) || now.isAfter(challenge.endAt)) {
      throw StateError('This challenge is not active right now.');
    }

    if (!delta.isFinite || delta <= 0) {
      throw StateError('Progress value must be greater than 0.');
    }

    final logs = <String, Map<String, double>>{};
    challenge.progressLogs.forEach((memberId, valuesByDay) {
      logs[memberId] = Map<String, double>.from(valuesByDay);
    });

    final dateKey = challenge.dateKeyFor(now);
    final memberLogs = Map<String, double>.from(
      logs[uid] ?? const <String, double>{},
    );
    memberLogs[dateKey] = (memberLogs[dateKey] ?? 0) + delta;
    logs[uid] = memberLogs;

    final updated = challenge.copyWith(progressLogs: logs);
    await saveGroupChallenge(updated);
    return updated;
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

    return GroupTask.fromMap(
      snapshot.docs.first.data(),
      id: snapshot.docs.first.id,
    );
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

  Future<GroupTask> updateGroupTaskAsAdmin({
    required GroupTask existingTask,
    required String title,
    String description = '',
    required bool isQuantified,
    required String quantUnit,
    required double quantMax,
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to update group tasks.');
    }

    final group = await getGroupById(existingTask.groupId);
    if (group == null) {
      throw StateError('Group not found.');
    }

    if (!group.memberIds.contains(userId)) {
      throw StateError('Only group members can edit tasks.');
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw StateError('Task title cannot be empty.');
    }

    final normalizedUnit = quantUnit.trim().isEmpty
        ? 'units'
        : quantUnit.trim();
    final normalizedQuantMax = quantMax.isFinite
        ? quantMax.clamp(0.1, 100000).toDouble()
        : existingTask.quantMax;

    final updatedTask = existingTask.copyWith(
      title: normalizedTitle,
      description: description.trim(),
      isQuantified: isQuantified,
      quantUnit: normalizedUnit,
      quantMax: normalizedQuantMax,
    );

    await saveGroupTask(updatedTask);
    return updatedTask;
  }

  Future<void> deleteGroupTask(String groupId, String taskId) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to delete group tasks.');
    }

    final group = await getGroupById(groupId);
    if (group == null) {
      throw StateError('Group not found.');
    }

    if (!group.memberIds.contains(userId)) {
      throw StateError('Only group members can delete tasks.');
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
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day,
    );

    userDates.removeWhere(
      (date) =>
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day,
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
