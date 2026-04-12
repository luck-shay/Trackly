import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../services/social_service.dart';
import '../services/database_service.dart';

class CreateHabitProvider extends ChangeNotifier {
  int _targetDays = 7;
  final List<String> _selectedFriends = [];

  // Placeholder cycling logic
  int _placeholderIndex = 0;
  Timer? _timer;
  final List<String> _placeholders = [
    'e.g. Morning Run',
    'e.g. Drink 2L Water',
    'e.g. Read 15 Pages',
    'e.g. Meditate for 10 min',
    'e.g. Walk the Dog'
  ];

  CreateHabitProvider() {
    _startPlaceholderTimer();
  }

  void _startPlaceholderTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
      notifyListeners();
    });
  }

  String get currentPlaceholder => _placeholders[_placeholderIndex];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    
    // Save to Database so it automatically streams to Dashboard via HabitsProvider
    await DatabaseService().saveHabit(newHabit);

    for (final friendUid in _selectedFriends) {
      await SocialService().sendHabitInvite(habitId: newHabit.id, toUserId: friendUid);
    }

    // Clean up state for the next time the screen is opened
    _targetDays = 7;
    _selectedFriends.clear();
    notifyListeners();

    return newHabit;
  }
}
