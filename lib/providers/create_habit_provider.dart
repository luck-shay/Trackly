import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import '../services/social_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_constants.dart';
import '../services/subscription_exceptions.dart';
import '../services/subscription_service.dart';

class CreateHabitProvider extends ChangeNotifier {
  int _targetDays = 7;
  final List<String> _selectedFriends = [];
  HabitSpaceType _spaceType = HabitSpaceType.individual;
  bool _isQuantified = false;
  String _quantUnit = 'km';
  double _quantMax = 10;
  GroupTaskMode _groupTaskMode = GroupTaskMode.shared;
  bool _requiresPhotoValidation = false;
  String? _reminderTime;
  final List<int> _reminderWeekdays = <int>[];
  bool _isEditMode = false;
  String? _editingHabitId;
  final SubscriptionService _subscriptionService = SubscriptionService();


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
  String? get reminderTime => _reminderTime;
  List<int> get reminderWeekdays => List<int>.unmodifiable(_reminderWeekdays);
  bool get isEditMode => _isEditMode;

  double get quantSliderMin => _quantConfig(_quantUnit).min;
  double get quantSliderMax => _quantConfig(_quantUnit).max;
  double get quantSliderStep => _quantConfig(_quantUnit).step;
  int get quantSliderDivisions =>
      ((quantSliderMax - quantSliderMin) / quantSliderStep).round();
  int get quantValueDecimals => quantSliderStep < 1 ? 1 : 0;

  void setTargetDays(int days) {
    _targetDays = days;
    _syncReminderWeekdaysToTarget();
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

  
  void setReminderTime(String? time) {
    _reminderTime = time;
    if (time == null || time.trim().isEmpty) {
      _reminderWeekdays.clear();
    } else {
      _syncReminderWeekdaysToTarget();
    }
    notifyListeners();
  }

  void toggleReminderWeekday(int weekday) {
    if (!Habit.weekdaysMondayFirst.contains(weekday)) {
      return;
    }

    if (_targetDays >= 7) {
      _reminderWeekdays
        ..clear()
        ..addAll(Habit.weekdaysMondayFirst);
      notifyListeners();
      return;
    }

    if (_reminderWeekdays.contains(weekday)) {
      _reminderWeekdays.remove(weekday);
    } else if (_reminderWeekdays.length < _targetDays) {
      _reminderWeekdays.add(weekday);
    } else {
      return;
    }

    _reminderWeekdays.sort();
    notifyListeners();
  }

  void initializeForEdit(Habit habit) {
    _isEditMode = true;
    _editingHabitId = habit.id;
    _targetDays = habit.targetDaysPerWeek;
    _spaceType = habit.spaceType;
    _isQuantified = habit.isQuantified;
    _quantUnit = habit.quantUnit;
    _quantMax = habit.quantMax;
    _groupTaskMode = habit.groupTaskMode;
    _requiresPhotoValidation = false;
    _reminderTime = habit.reminderTime;
    _reminderWeekdays
      ..clear()
      ..addAll(habit.effectiveReminderWeekdays);
    _selectedFriends.clear();
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

    Habit savedHabit;

    if (_isEditMode && _editingHabitId != null) {
      final existing = await databaseService.getHabitById(_editingHabitId!);
      if (existing == null) {
        throw StateError('Habit not found. Please refresh and try again.');
      }

      savedHabit = existing.copyWith(
        title: title,
        description: description,
        targetDaysPerWeek: _targetDays,
        isQuantified: _isQuantified,
        quantUnit: _quantUnit,
        quantMax: _quantMax,
        groupTaskMode: existing.spaceType == HabitSpaceType.group
            ? _groupTaskMode
            : existing.groupTaskMode,
        groupName: existing.spaceType == HabitSpaceType.group
            ? groupName
            : existing.groupName,
        requiresPhotoValidation: false,
        reminderTime: _reminderTime,
        reminderWeekdays: _resolvedReminderWeekdays(),
      );

      await databaseService.saveHabit(savedHabit);
      unawaited(
        NotificationService().refreshReminderSchedule(
          reason: 'edit_habit_saved',
          force: true,
        ).catchError((error) {
          if (kDebugMode) {
            debugPrint(
              'CreateHabitProvider: Reminder refresh failed after edit: $error',
            );
          }
        }),
      );
    } else {
      if (_spaceType == HabitSpaceType.sharedTask) {
        final hasAccess = await _subscriptionService.hasPremiumAccess(
          currentUserId,
        );
        if (!hasAccess) {
          final sharedCount = await _subscriptionService
              .sharedTaskParticipationCount(currentUserId);
          if (sharedCount >= kFreeSharedTaskLimit) {
            throw const UpgradeRequiredException(
              'Free tier allows up to 3 shared tasks. Upgrade to Trackly Pro.',
            );
          }
        }
      }

      savedHabit = Habit(
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
        requiresPhotoValidation: false,
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
        reminderTime: _reminderTime,
        reminderWeekdays: _resolvedReminderWeekdays(),
      );

      // Save to Database so it automatically streams to Dashboard via HabitsProvider
      await databaseService.saveHabit(savedHabit);
      unawaited(
        NotificationService().refreshReminderSchedule(
          reason: 'new_habit_saved',
          force: true,
        ).catchError((error) {
          if (kDebugMode) {
            debugPrint(
              'CreateHabitProvider: Reminder refresh failed after create: $error',
            );
          }
        }),
      );

      for (final friendUid in _selectedFriends) {
        if (_spaceType == HabitSpaceType.group) {
          await SocialService().sendGroupInvite(
            groupId: savedHabit.id,
            groupName: savedHabit.groupName ?? savedHabit.title,
            toUserId: friendUid,
          );
        } else if (_spaceType == HabitSpaceType.sharedTask) {
          await SocialService().sendHabitInvite(
            habitId: savedHabit.id,
            toUserId: friendUid,
          );
        }
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
    _reminderTime = null;
    _reminderWeekdays.clear();
    _isEditMode = false;
    _editingHabitId = null;
    notifyListeners();

    return savedHabit;
  }

  List<int> _resolvedReminderWeekdays() {
    if ((_reminderTime ?? '').trim().isEmpty) {
      return const <int>[];
    }

    if (_targetDays >= 7) {
      return List<int>.from(Habit.weekdaysMondayFirst);
    }

    if (_reminderWeekdays.length != _targetDays) {
      throw StateError(
        'Choose exactly $_targetDays reminder days for this habit.',
      );
    }

    final sorted = List<int>.from(_reminderWeekdays)..sort();
    return sorted;
  }

  void _syncReminderWeekdaysToTarget() {
    if ((_reminderTime ?? '').trim().isEmpty) {
      return;
    }

    if (_targetDays >= 7) {
      _reminderWeekdays
        ..clear()
        ..addAll(Habit.weekdaysMondayFirst);
      return;
    }

    _reminderWeekdays.removeWhere(
      (day) => !Habit.weekdaysMondayFirst.contains(day),
    );
    _reminderWeekdays.sort();

    while (_reminderWeekdays.length > _targetDays) {
      _reminderWeekdays.removeLast();
    }

    for (final day in Habit.weekdaysMondayFirst) {
      if (_reminderWeekdays.length >= _targetDays) {
        break;
      }
      if (!_reminderWeekdays.contains(day)) {
        _reminderWeekdays.add(day);
      }
    }

    _reminderWeekdays.sort();
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
      return const _QuantUnitConfig(min: 0.5, max: 24, step: .5);
    case 'km':
      return const _QuantUnitConfig(min: 0.5, max: 50, step: 1);
    case 'reps':
      return const _QuantUnitConfig(min: 1, max: 500, step: 1);
    case 'pages':
      return const _QuantUnitConfig(min: 1, max: 100, step: 1);
    case 'steps':
      return const _QuantUnitConfig(min: 500, max: 20000, step: 500);
    default:
      return const _QuantUnitConfig(min: 1, max: 1000, step: 1);
  }
}
