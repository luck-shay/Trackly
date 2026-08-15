import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
  String get userId => currentUserId ?? '';

  String createHabitId() => _db.collection('habits').doc().id;

  // Stream of active habits directly from Firestore
  Stream<List<Habit>> streamHabits() {
    final currentUserId = userId;
    if (currentUserId.isEmpty) {
      return Stream.value(const <Habit>[]);
    }

    return _db
        .collection('habits')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map(
        (snapshot) => snapshot.docs
          .map((doc) => Habit.fromMap(doc.data(), id: doc.id))
          .where((habit) => !habit.isGroup && !habit.isArchived)
          .toList(),
        );
  }

  // Stream of archived habits directly from Firestore
  Stream<List<Habit>> streamArchivedHabits() {
    final currentUserId = userId;
    if (currentUserId.isEmpty) {
      return Stream.value(const <Habit>[]);
    }

    return _db
        .collection('habits')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map(
        (snapshot) => snapshot.docs
          .map((doc) => Habit.fromMap(doc.data(), id: doc.id))
          .where((habit) => !habit.isGroup && habit.isArchived)
          .toList(),
        );
  }

  // Add or update a habit
  Future<void> saveHabit(
    Habit habit, {
    bool ensureCurrentUserParticipant = true,
  }) async {
    final currentUserId = userId;
    if (currentUserId.isEmpty) {
      throw StateError('You must be signed in to save habits.');
    }

    var habitToSave = habit;
    if (ensureCurrentUserParticipant &&
        !habit.participants.contains(currentUserId)) {
      habitToSave = habit.copyWith(
        participants: [...habit.participants, currentUserId],
      );
    }

    await _db.collection('habits').doc(habit.id).set(habitToSave.toMap());
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId) {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to delete habits.');
    }
    return _db.collection('habits').doc(habitId).delete();
  }

  // Get a habit by ID
  Future<Habit?> getHabitById(String habitId) async {
    final doc = await _db.collection('habits').doc(habitId).get();
    if (doc.exists && doc.data() != null) {
      return Habit.fromMap(doc.data()!, id: doc.id);
    }
    return null;
  }
}
