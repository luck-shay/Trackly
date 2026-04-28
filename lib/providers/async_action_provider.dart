import 'package:flutter/foundation.dart';

class AsyncActionProvider extends ChangeNotifier {
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errorStates = {};

  bool isLoading(String actionId) => _loadingStates[actionId] ?? false;
  String? getError(String actionId) => _errorStates[actionId];

  void setLoading(String actionId, bool loading) {
    _loadingStates[actionId] = loading;
    notifyListeners();
  }

  void setError(String actionId, String? error) {
    _errorStates[actionId] = error;
    notifyListeners();
  }

  void reset(String actionId) {
    _loadingStates.remove(actionId);
    _errorStates.remove(actionId);
    notifyListeners();
  }

  void resetAll() {
    _loadingStates.clear();
    _errorStates.clear();
    notifyListeners();
  }
}
