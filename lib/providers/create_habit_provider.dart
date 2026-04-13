import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../services/social_service.dart';
import '../services/database_service.dart';

class CreateHabitProvider extends ChangeNotifier {
  int _targetDays = 7;
  final List<String> _selectedFriends = [];
  HabitSpaceType _spaceType = HabitSpaceType.individual;
  bool _isQuantified = false;
  String _quantUnit = 'km';
  double _quantMax = 10;
  GroupTaskMode _groupTaskMode = GroupTaskMode.shared;
  bool _requiresPhotoValidation = false;

  // Placeholder cycling logic
  int _placeholderIndex = 0;
  Timer? _timer;
  final List<String> _placeholders = [
    'e.g. Morning Run',
    'e.g. Drink 2L Water',
    'e.g. Read 15 Pages',
    'e.g. Meditate for 10 min',
    'e.g. Walk the Dog',
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
  HabitSpaceType get spaceType => _spaceType;
  bool get isQuantified => _isQuantified;
  String get quantUnit => _quantUnit;
  double get quantMax => _quantMax;
  GroupTaskMode get groupTaskMode => _groupTaskMode;
  bool get requiresPhotoValidation => _requiresPhotoValidation;
  double get quantSliderMin => _quantConfig(_quantUnit).min;
  double get quantSliderMax => _quantConfig(_quantUnit).max;
  double get quantSliderStep => _quantConfig(_quantUnit).step;
  int get quantSliderDivisions =>
      ((quantSliderMax - quantSliderMin) / quantSliderStep).round();
  int get quantValueDecimals => quantSliderStep < 1 ? 1 : 0;

  void setTargetDays(int days) {
    _targetDays = days;
    notifyListeners();
  }

  void setSpaceType(HabitSpaceType type) {
    if (_spaceType == type) {
      return;
    }

    _spaceType = type;

    if (_spaceType == HabitSpaceType.individual) {
      _selectedFriends.clear();
    }

    notifyListeners();
  }

  void setQuantified(bool value) {
    if (_isQuantified == value) {
      return;
    }
    _isQuantified = value;
    notifyListeners();
  }

  void setQuantUnit(String unit) {
    if (_quantUnit == unit) {
      return;
    }
    _quantUnit = unit;
    final config = _quantConfig(unit);
    _quantMax = _quantMax.clamp(config.min, config.max).toDouble();
    notifyListeners();
  }

  void setQuantMax(double value) {
    final config = _quantConfig(_quantUnit);
    final normalized = value.clamp(config.min, config.max).toDouble();
    if (_quantMax == normalized) {
      return;
    }
    _quantMax = normalized;
    notifyListeners();
  }

  void setGroupTaskMode(GroupTaskMode mode) {
    if (_groupTaskMode == mode) {
      return;
    }
    _groupTaskMode = mode;
    notifyListeners();
  }

  void setRequiresPhotoValidation(bool value) {
    if (_requiresPhotoValidation == value) {
      return;
    }
    _requiresPhotoValidation = value;
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

  Future<Habit> saveHabit({
    required String title,
    required String description,
    String? groupName,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('You must be signed in to create a habit.');
    }
    final databaseService = DatabaseService();

    final newHabit = Habit(
      id: databaseService.createHabitId(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      targetDaysPerWeek: _targetDays,
      participants: [currentUserId],
      spaceType: _spaceType,
      groupName: _spaceType == HabitSpaceType.group ? groupName : null,
      isQuantified: _isQuantified,
      quantUnit: _quantUnit,
      quantMin: 0,
      quantMax: _quantMax,
      groupTaskMode: _spaceType == HabitSpaceType.group
          ? _groupTaskMode
          : GroupTaskMode.shared,
      requiresPhotoValidation: _requiresPhotoValidation,
      memberTasks:
          _spaceType == HabitSpaceType.group &&
              _groupTaskMode == GroupTaskMode.memberDefined
          ? {currentUserId: title}
          : const {},
      memberIsQuantified:
          _spaceType == HabitSpaceType.group &&
              _groupTaskMode == GroupTaskMode.memberDefined
          ? {currentUserId: _isQuantified}
          : const {},
      memberQuantUnits:
          _spaceType == HabitSpaceType.group &&
              _groupTaskMode == GroupTaskMode.memberDefined
          ? {currentUserId: _quantUnit}
          : const {},
      memberQuantMax:
          _spaceType == HabitSpaceType.group &&
              _groupTaskMode == GroupTaskMode.memberDefined
          ? {currentUserId: _quantMax}
          : const {},
    );

    // Save to Database so it automatically streams to Dashboard via HabitsProvider
    await databaseService.saveHabit(newHabit);

    for (final friendUid in _selectedFriends) {
      if (_spaceType == HabitSpaceType.group) {
        await SocialService().sendGroupInvite(
          groupId: newHabit.id,
          groupName: newHabit.groupName ?? newHabit.title,
          toUserId: friendUid,
        );
      } else if (_spaceType == HabitSpaceType.sharedTask) {
        await SocialService().sendHabitInvite(
          habitId: newHabit.id,
          toUserId: friendUid,
        );
      }
    }

    // Clean up state for the next time the screen is opened
    _targetDays = 7;
    _selectedFriends.clear();
    _spaceType = HabitSpaceType.individual;
    _isQuantified = false;
    _quantUnit = 'km';
    _quantMax = 10;
    _groupTaskMode = GroupTaskMode.shared;
    _requiresPhotoValidation = false;
    notifyListeners();

    return newHabit;
  }
}

class _QuantUnitConfig {
  final double min;
  final double max;
  final double step;

  const _QuantUnitConfig({
    required this.min,
    required this.max,
    required this.step,
  });
}

_QuantUnitConfig _quantConfig(String unit) {
  switch (unit) {
    case 'hours':
      return const _QuantUnitConfig(min: 0.5, max: 24, step: 0.5);
    case 'km':
      return const _QuantUnitConfig(min: 0.5, max: 50, step: 0.5);
    case 'reps':
      return const _QuantUnitConfig(min: 1, max: 500, step: 1);
    case 'pages':
      return const _QuantUnitConfig(min: 1, max: 300, step: 1);
    case 'steps':
      return const _QuantUnitConfig(min: 500, max: 50000, step: 500);
    default:
      return const _QuantUnitConfig(min: 1, max: 200, step: 1);
  }
}
