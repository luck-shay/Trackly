import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';

class FriendsProvider extends ChangeNotifier {
  final SocialService _social = SocialService();

  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  List<UserProfile> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get hasSearched => _hasSearched;
  String get lastQuery => _lastQuery;

  void clearSearch() {
    _isSearching = false;
    _searchResults = [];
    _hasSearched = false;
    _lastQuery = '';
    notifyListeners();
  }

  Future<void> searchUsers(String query) async {
    _lastQuery = query.trim();
    if (_lastQuery.isEmpty) {
      clearSearch();
      return;
    }

    _isSearching = true;
    _hasSearched = true;
    notifyListeners();

    try {
      _searchResults = await _social.searchUsersByUsername(_lastQuery);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}
