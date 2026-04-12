import 'dart:async';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/database_service.dart';

class HabitsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  StreamSubscription<List<Habit>>? _subscription;
  
  List<Habit> _habits = [];
  bool _isLoading = true;
  String? _error;

  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get userId => _db.userId;

  HabitsProvider() {
    _initStream();
  }

  void _initStream() {
    _subscription = _db.streamHabits().listen(
      (data) {
        _habits = data;
        _habits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _error = err.toString();
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  Future<void> toggleHabitCompletion(Habit habit) async {
    DateTime now = DateTime.now();
    bool foundToday = false;
    final uid = _db.userId;
    
    // Copy completions to mutate
    final newCompletions = Map<String, List<DateTime>>.from(habit.completions);
    
    if (!newCompletions.containsKey(uid)) {
      newCompletions[uid] = [];
    }
    
    final userCompletions = List<DateTime>.from(newCompletions[uid]!);
    
    for (int i = 0; i < userCompletions.length; i++) {
        var date = userCompletions[i];
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          userCompletions.removeAt(i);
          foundToday = true;
          break;
        }
    }
    
    if (!foundToday) {
      userCompletions.add(now);
    }

    newCompletions[uid] = userCompletions;
    final updatedHabit = habit.copyWith(completions: newCompletions);

    // Optimistic update
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index != -1) {
      _habits[index] = updatedHabit;
      notifyListeners();
    }

    await _db.saveHabit(updatedHabit);
  }

  Future<void> deleteHabit(String habitId) async {
    // Optimistic delete
    _habits.removeWhere((h) => h.id == habitId);
    notifyListeners();
    
    await _db.deleteHabit(habitId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
