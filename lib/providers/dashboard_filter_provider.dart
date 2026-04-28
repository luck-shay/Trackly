import 'package:flutter/foundation.dart';
import '../screens/dashboard_screen.dart';

class DashboardFilterProvider extends ChangeNotifier {
  DashboardFilter _selectedFilter = DashboardFilter.all;
  List<String> _groupOrderIds = <String>[];
  List<String> _personalOrderIds = <String>[];
  Set<String> _completedHabitIdsForOrdering = <String>{};
  bool _hasCapturedInitialCompletionOrder = false;
  bool _isLoadingSectionPrefs = true;

  DashboardFilter get selectedFilter => _selectedFilter;
  List<String> get groupOrderIds => _groupOrderIds;
  List<String> get personalOrderIds => _personalOrderIds;
  Set<String> get completedHabitIdsForOrdering => _completedHabitIdsForOrdering;
  bool get hasCapturedInitialCompletionOrder => _hasCapturedInitialCompletionOrder;
  bool get isLoadingSectionPrefs => _isLoadingSectionPrefs;

  void setSelectedFilter(DashboardFilter filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  void setGroupOrderIds(List<String> ids) {
    _groupOrderIds = ids;
    notifyListeners();
  }

  void setPersonalOrderIds(List<String> ids) {
    _personalOrderIds = ids;
    notifyListeners();
  }

  void updateCompletedHabits(Set<String> completedIds) {
    if (!_hasCapturedInitialCompletionOrder ||
        !_sameHabitIdSet(_completedHabitIdsForOrdering, completedIds)) {
      _completedHabitIdsForOrdering
        ..clear()
        ..addAll(completedIds);
      _hasCapturedInitialCompletionOrder = true;
      notifyListeners();
    }
  }

  void setSectionPrefsLoading(bool loading) {
    if (_isLoadingSectionPrefs != loading) {
      _isLoadingSectionPrefs = loading;
      notifyListeners();
    }
  }

  bool _sameHabitIdSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }
}
