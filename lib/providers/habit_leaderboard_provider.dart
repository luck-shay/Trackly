import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';

class HabitLeaderboardProvider extends ChangeNotifier {
  Habit _habit;
  final SocialService _social = SocialService();

  List<UserProfile> _participants = [];
  bool _isLoading = true;
  String? _error;
  List<String> _participantIds = const [];

  HabitLeaderboardProvider(Habit habit) : _habit = habit {
    _participantIds = List<String>.from(habit.participants)..sort();
    _fetchParticipants();
  }

  Habit get habit => _habit;
  List<UserProfile> get participants => _participants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> syncWithHabit(Habit nextHabit) async {
    _habit = nextHabit;
    final nextParticipantIds = List<String>.from(nextHabit.participants)..sort();
    final membershipChanged =
        _participantIds.length != nextParticipantIds.length ||
        !_participantIds.asMap().entries.every(
          (entry) => entry.value == nextParticipantIds[entry.key],
        );

    if (membershipChanged) {
      _participantIds = nextParticipantIds;
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _fetchParticipants();
      return;
    }

    _sortParticipants();
    notifyListeners();
  }

  Future<void> _fetchParticipants() async {
    try {
      final list = <UserProfile>[];
      for (final uid in _habit.participants) {
        final profile = await _social.getUserProfile(uid);
        if (profile != null) {
          list.add(profile);
        }
      }

      _participants = list;
      _sortParticipants();
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortParticipants() {
    _participants.sort((a, b) {
      final consistencyA = _rollingConsistencyScore(a.uid);
      final consistencyB = _rollingConsistencyScore(b.uid);
      if (consistencyA != consistencyB) {
        return consistencyB.compareTo(consistencyA);
      }
      final streakA = _habit.currentStreakFor(a.uid);
      final streakB = _habit.currentStreakFor(b.uid);
      if (streakA == streakB) {
        return a.displayName.compareTo(b.displayName);
      }
      return streakB.compareTo(streakA);
    });
  }

  int _rollingConsistencyScore(String uid) {
    final today = DateTime.now();
    var score = 0.0;
    const lookbackDays = 14;
    for (var offset = 0; offset < lookbackDays; offset++) {
      final day = today.subtract(Duration(days: offset));
      score += _habit.completionProgressFor(uid, day);
    }
    return (score * 100).round();
  }
}
