import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';

class GroupMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _processedLegacyGroupsKeyPrefix =
      'processed_legacy_groups_';

  static final Set<String> _runningForUsers = <String>{};

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _processedLegacyGroupsKeyFor(String uid) {
    return '$_processedLegacyGroupsKeyPrefix$uid';
  }

  Future<Set<String>> _loadProcessedLegacyGroupIds(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getStringList(_processedLegacyGroupsKeyFor(uid))
            ?.toSet() ??
        <String>{};
  }

  Future<void> _saveProcessedLegacyGroupIds(String uid, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_processedLegacyGroupsKeyFor(uid), ids.toList());
  }

  Future<void> migrateLegacyGroupsForCurrentUser() async {
    final uid = userId;
    if (uid.isEmpty) {
      return;
    }

    if (_runningForUsers.contains(uid)) {
      return;
    }

    _runningForUsers.add(uid);
    try {
      final processedLegacyGroupIds = await _loadProcessedLegacyGroupIds(uid);

      final habitsSnapshot = await _db
          .collection('habits')
          .where('participants', arrayContains: uid)
          .get();

        final groupedHabits = habitsSnapshot.docs
          .map((doc) => Habit.fromMap(doc.data(), id: doc.id))
          .where((habit) => habit.isGroup)
          .toList();

        final legacyGroups = groupedHabits
          .where(_isLegacyGroupSeed)
          .toList();

        final modernGroupTaskMirrors = groupedHabits
          .where((habit) => !_isLegacyGroupSeed(habit))
          .toList();

        for (final mirror in modernGroupTaskMirrors) {
        await _cleanupGhostGroupFromTaskMirror(mirror, uid);
        }

      if (legacyGroups.isEmpty) {
        return;
      }

      var processedChanged = false;

      for (final legacyGroupHabit in legacyGroups) {
        if (processedLegacyGroupIds.contains(legacyGroupHabit.id)) {
          await _preventResurrectionForProcessedLegacyGroup(
            legacyGroupHabit,
            uid,
          );
          continue;
        }

        await _migrateLegacyGroupHabit(legacyGroupHabit, uid);
        processedLegacyGroupIds.add(legacyGroupHabit.id);
        processedChanged = true;
      }

      if (processedChanged) {
        await _saveProcessedLegacyGroupIds(uid, processedLegacyGroupIds);
      }

      if (kDebugMode) {
        debugPrint(
          'Legacy group migration complete for $uid: ${legacyGroups.length} group(s) scanned.',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Legacy group migration failed for $uid: $error');
      }
    } finally {
      _runningForUsers.remove(uid);
    }
  }

  bool _isLegacyGroupSeed(Habit habit) {
    final groupEntityId = (habit.groupEntityId ?? '').trim();
    return groupEntityId.isEmpty || groupEntityId == habit.id;
  }

  Future<void> _preventResurrectionForProcessedLegacyGroup(
    Habit legacy,
    String uid,
  ) async {
    final groupDoc = await _db.collection('groups').doc(legacy.id).get();
    if (groupDoc.exists) {
      return;
    }

    // If the modern group doc is gone, prevent legacy participants from
    // recreating it during future starts for this user.
    try {
      await _db.collection('habits').doc(legacy.id).update({
        'participants': FieldValue.arrayRemove([uid]),
      });
    } on FirebaseException catch (error) {
      if (error.code != 'not-found' && kDebugMode) {
        debugPrint(
          'Failed anti-resurrection cleanup for ${legacy.id} (${error.code}): $error',
        );
      }
    }
  }

  Future<void> _cleanupGhostGroupFromTaskMirror(Habit mirror, String uid) async {
    final groupRef = _db.collection('groups').doc(mirror.id);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists || groupDoc.data() == null) {
      return;
    }

    final data = groupDoc.data()!;
    final migratedFromLegacyHabit = data['migratedFromLegacyHabit'] == true;
    final memberIds = List<String>.from(
      (data['memberIds'] as List?) ?? const <String>[],
    );

    // Only clean synthetic groups previously created by migration.
    if (!migratedFromLegacyHabit || !memberIds.contains(uid)) {
      return;
    }

    final remainingMembers = List<String>.from(memberIds)
      ..removeWhere((memberId) => memberId == uid);

    try {
      if (remainingMembers.isEmpty) {
        final tasksSnapshot = await groupRef.collection('tasks').get();
        final batch = _db.batch();
        for (final taskDoc in tasksSnapshot.docs) {
          batch.delete(taskDoc.reference);
        }
        batch.delete(groupRef);
        await batch.commit();
        return;
      }

      final updates = <String, dynamic>{'memberIds': remainingMembers};
      final ownerId = (data['ownerId'] as String? ?? '').trim();
      if (ownerId == uid) {
        updates['ownerId'] = remainingMembers.first;
      }

      await groupRef.update(updates);
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Ghost group cleanup skipped for ${mirror.id} (${error.code}): $error',
        );
      }
    }
  }

  Future<void> _migrateLegacyGroupHabit(Habit legacy, String uid) async {
    final groupRef = _db.collection('groups').doc(legacy.id);
    final groupDoc = await groupRef.get();

    final groupName = (legacy.groupName ?? '').trim().isEmpty
        ? legacy.title.trim()
        : legacy.groupName!.trim();
    final ownerId = legacy.participants.isEmpty
        ? uid
        : legacy.participants.first.trim();
    final members = legacy.participants.toSet().toList();

    if (!groupDoc.exists) {
      await groupRef.set({
        'id': legacy.id,
        'name': groupName,
        'description': legacy.description,
        'ownerId': ownerId,
        'createdAt': legacy.createdAt.toIso8601String(),
        'memberIds': members,
        'leftMemberIds': <String>[],
        'migratedFromLegacyHabit': true,
      });
    } else {
      final existingData = groupDoc.data() ?? const <String, dynamic>{};
      final existingMembers = List<String>.from(
        (existingData['memberIds'] as List?) ?? const <String>[],
      );

      // If the current user is no longer a member, do not resurrect membership
      // from stale legacy habit participants during app startup.
      if (!existingMembers.contains(uid)) {
        return;
      }

      await groupRef.set({
        'migratedFromLegacyHabit': true,
      }, SetOptions(merge: true));
    }

    final initialTaskRef = groupRef.collection('tasks').doc(legacy.id);
    final initialTaskDoc = await initialTaskRef.get();
    if (initialTaskDoc.exists) {
      return;
    }

    await initialTaskRef.set({
      'id': legacy.id,
      'groupId': legacy.id,
      'title': legacy.title,
      'description': legacy.description,
      'createdAt': legacy.createdAt.toIso8601String(),
      'createdBy': ownerId,
      'assigneeIds': members,
      'isQuantified': legacy.isQuantified,
      'quantUnit': legacy.quantUnit,
      'quantMax': legacy.quantMax,
      'completions': legacy.completions.map(
        (key, value) =>
            MapEntry(key, value.map((date) => date.toIso8601String()).toList()),
      ),
      'quantifiedValues': legacy.quantifiedValues,
      'migratedFromLegacyHabit': true,
    });
  }
}
