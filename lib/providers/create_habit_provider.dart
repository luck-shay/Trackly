import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../services/social_service.dart';

class CreateHabitProvider extends ChangeNotifier {
  int _targetDays = 7;
  final List<String> _selectedFriends = [];

  int get targetDays => _targetDays;
  List<String> get selectedFriends => _selectedFriends;

  void setTargetDays(int days) {
    _targetDays = days;
    notifyListeners();
  }

  void toggleFriend(String uid) {
    if (_selectedFriends.contains(uid)) {
      _selectedFriends.remove(uid);
    } else {
      _selectedFriends.add(uid);
    }
    notifyListeners();
  }

  Future<Habit> saveHabit({required String title, required String description}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    final newHabit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      targetDaysPerWeek: _targetDays,
      participants: [currentUserId], 
    );
    
    for (final friendUid in _selectedFriends) {
      await SocialService().sendHabitInvite(habitId: newHabit.id, toUserId: friendUid);
    }

    return newHabit;
  }
}
