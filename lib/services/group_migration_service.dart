import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/habit.dart';

class GroupMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final Set<String> _runningForUsers = <String>{};

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
      final habitsSnapshot = await _db
          .collection('habits')
          .where('participants', arrayContains: uid)
          .get();

      final legacyGroups = habitsSnapshot.docs
          .map((doc) => Habit.fromMap(doc.data(), id: doc.id))
          .where((habit) => habit.isGroup)
          .toList();

      if (legacyGroups.isEmpty) {
        return;
      }

      for (final legacyGroupHabit in legacyGroups) {
        await _migrateLegacyGroupHabit(legacyGroupHabit, uid);
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
        'migratedFromLegacyHabit': true,
      });
    } else {
      await groupRef.set({
        'memberIds': FieldValue.arrayUnion(members),
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
