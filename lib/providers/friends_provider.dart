import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';

class FriendsProvider extends ChangeNotifier {
  final SocialService _social = SocialService();
  static const int minSearchCharacters = 2;
  Timer? _searchDebounce;
  int _searchRun = 0;

  List<UserProfile> _searchResults = [];
  Map<String, FriendRelationshipStatus> _relationshipStatuses = {};
  final Set<String> _busyUserIds = {};
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  List<UserProfile> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get hasSearched => _hasSearched;
  String get lastQuery => _lastQuery;

  bool get hasActiveQuery => _lastQuery.trim().isNotEmpty;

  String get resultTitle => 'Search Results';

  FriendRelationshipStatus statusFor(String userId) {
    return _relationshipStatuses[userId] ?? FriendRelationshipStatus.none;
  }

  bool isBusy(String userId) => _busyUserIds.contains(userId);

  void queueSearch(String query) {
    _lastQuery = query;
    final normalizedLength = _normalizedSearchLength(query);
    _hasSearched = normalizedLength >= minSearchCharacters;
    _searchDebounce?.cancel();

    if (normalizedLength < minSearchCharacters) {
      _isSearching = false;
      _searchResults = [];
      _relationshipStatuses = {};
      notifyListeners();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      searchUsers(query);
    });
    notifyListeners();
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _isSearching = false;
    _searchResults = [];
    _relationshipStatuses = {};
    _hasSearched = false;
    _lastQuery = '';
    notifyListeners();
  }

  Future<void> searchUsers(String query) async {
    final run = ++_searchRun;
    final trimmedQuery = query.trim();
    _lastQuery = query;

    if (_normalizedSearchLength(query) < minSearchCharacters) {
      _isSearching = false;
      _hasSearched = false;
      _searchResults = [];
      _relationshipStatuses = {};
      notifyListeners();
      return;
    }

    _isSearching = true;
    _hasSearched = trimmedQuery.isNotEmpty;
    notifyListeners();

    try {
      final users = await _social.searchUsers(trimmedQuery);
      if (run != _searchRun) return;

      final statuses = await _social.relationshipStatusesFor(
        users.map((user) => user.uid),
      );
      if (run != _searchRun) return;

      _searchResults = users;
      _relationshipStatuses = statuses;
    } finally {
      if (run == _searchRun) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<FriendRequestResult> sendFriendRequest(UserProfile user) async {
    if (_busyUserIds.contains(user.uid)) {
      return FriendRequestResult.unavailable;
    }

    _busyUserIds.add(user.uid);
    notifyListeners();

    try {
      final result = await _social.sendFriendRequest(user.uid);
      _relationshipStatuses[user.uid] = switch (result) {
        FriendRequestResult.sent => FriendRelationshipStatus.outgoingPending,
        FriendRequestResult.acceptedIncoming => FriendRelationshipStatus.friend,
        FriendRequestResult.alreadyFriends => FriendRelationshipStatus.friend,
        FriendRequestResult.alreadyPending =>
          FriendRelationshipStatus.outgoingPending,
        FriendRequestResult.unavailable =>
          _relationshipStatuses[user.uid] ?? FriendRelationshipStatus.none,
      };
      return result;
    } finally {
      _busyUserIds.remove(user.uid);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  int _normalizedSearchLength(String query) {
    final value = query.trim();
    final withoutAt = value.startsWith('@') ? value.substring(1) : value;
    return withoutAt.length;
  }
}
