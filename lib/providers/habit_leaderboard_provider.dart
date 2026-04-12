import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';

class HabitLeaderboardProvider extends ChangeNotifier {
  final Habit habit;
  final SocialService _social = SocialService();
  
  List<UserProfile> _participants = [];
  bool _isLoading = true;
  String? _error;

  HabitLeaderboardProvider(this.habit) {
    _fetchParticipants();
  }

  List<UserProfile> get participants => _participants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _fetchParticipants() async {
    try {
      List<UserProfile> list = [];
      for (String uid in habit.participants) {
        final profile = await _social.getUserProfile(uid);
        if (profile != null) {
          list.add(profile);
        }
      }
      
      // Sort descending by current streak
      list.sort((a, b) {
        final streakA = habit.currentStreakFor(a.uid);
        final streakB = habit.currentStreakFor(b.uid);
        if (streakA == streakB) {
          return a.displayName.compareTo(b.displayName);
        }
        return streakB.compareTo(streakA);
      });

      _participants = list;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
