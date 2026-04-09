import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Dynamically fetch the real User ID from Firebase Auth
  String get userId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous'; 

  // Stream of habits directly from Firestore
  Stream<List<Habit>> streamHabits() {
    return _db
        .collection('habits')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Habit.fromMap(doc.data(), id: doc.id))
            .toList());
  }

  // Add or update a habit
  Future<void> saveHabit(Habit habit) {
    // Ensure the current user is always a participant
    if (!habit.participants.contains(userId)) {
      habit.participants.add(userId);
    }
    return _db
        .collection('habits')
        .doc(habit.id)
        .set(habit.toMap());
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId) {
    return _db
        .collection('habits')
        .doc(habitId)
        .delete();
  }
}
