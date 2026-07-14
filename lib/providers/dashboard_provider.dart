import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DashboardFilter {
  all,
  challenges,
  group,
  individual,
  shared,
  incomplete,
  completed,
}

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({required String userId}) : _userId = userId;

  final String _userId;

  bool _isLoadingPreferences = true;
  DashboardFilter _selectedFilter = DashboardFilter.all;
  List<String> _groupOrderIds = <String>[];
  List<String> _personalOrderIds = <String>[];

  bool get isLoadingPreferences => _isLoadingPreferences;
  DashboardFilter get selectedFilter => _selectedFilter;
  List<String> get groupOrderIds => List<String>.unmodifiable(_groupOrderIds);
  List<String> get personalOrderIds =>
      List<String>.unmodifiable(_personalOrderIds);

  String get _groupsOrderKey => 'dashboard_groups_order_$_userId';
  String get _personalOrderKey => 'dashboard_personal_order_$_userId';

  Future<void> loadPreferences() async {
    if (_userId.isEmpty) {
      if (_isLoadingPreferences) {
        _isLoadingPreferences = false;
        notifyListeners();
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextGroupOrderIds = prefs.getStringList(_groupsOrderKey) ?? <String>[];
    final nextPersonalOrderIds =
        prefs.getStringList(_personalOrderKey) ?? <String>[];

    final didChange =
        !listEquals(_groupOrderIds, nextGroupOrderIds) ||
        !listEquals(_personalOrderIds, nextPersonalOrderIds) ||
        _isLoadingPreferences;

    _groupOrderIds = nextGroupOrderIds;
    _personalOrderIds = nextPersonalOrderIds;
    _isLoadingPreferences = false;

    if (didChange) {
      notifyListeners();
    }
  }

  void setSelectedFilter(DashboardFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }
    _selectedFilter = filter;
    notifyListeners();
  }

  void ensureSelectedFilter(Set<DashboardFilter> availableFilters) {
    if (availableFilters.contains(_selectedFilter)) {
      return;
    }
    setSelectedFilter(DashboardFilter.all);
  }

  Future<void> setGroupOrderFromIds(List<String> ids) async {
    if (listEquals(_groupOrderIds, ids)) {
      return;
    }
    _groupOrderIds = List<String>.from(ids);
    notifyListeners();
    await _saveOrderPrefs(groupOrder: _groupOrderIds);
  }

  Future<void> setPersonalOrderFromIds(List<String> ids) async {
    if (listEquals(_personalOrderIds, ids)) {
      return;
    }
    _personalOrderIds = List<String>.from(ids);
    notifyListeners();
    await _saveOrderPrefs(personalOrder: _personalOrderIds);
  }

  Future<void> reorderGroupIds(
    List<String> orderedIds,
    int oldIndex,
    int newIndex,
  ) async {
    await setGroupOrderFromIds(
      _reorderedIds(orderedIds, oldIndex: oldIndex, newIndex: newIndex),
    );
  }

  Future<void> reorderPersonalIds(
    List<String> orderedIds,
    int oldIndex,
    int newIndex,
  ) async {
    await setPersonalOrderFromIds(
      _reorderedIds(orderedIds, oldIndex: oldIndex, newIndex: newIndex),
    );
  }

  Future<void> _saveOrderPrefs({
    List<String>? groupOrder,
    List<String>? personalOrder,
  }) async {
    if (_userId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (groupOrder != null) {
      await prefs.setStringList(_groupsOrderKey, groupOrder);
    }
    if (personalOrder != null) {
      await prefs.setStringList(_personalOrderKey, personalOrder);
    }
  }

  List<String> _reorderedIds(
    List<String> orderedIds, {
    required int oldIndex,
    required int newIndex,
  }) {
    final next = List<String>.from(orderedIds);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    return next;
  }
}
