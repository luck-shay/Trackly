import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/group_invite.dart';
import '../models/habit.dart';
import '../services/group_service.dart';
import 'subscription_constants.dart';
import 'subscription_exceptions.dart';
import 'subscription_service.dart';

const int _minUserSearchCharacters = 2;

enum FriendRequestResult {
  sent,
  alreadyFriends,
  alreadyPending,
  acceptedIncoming,
  unavailable,
}

enum FriendRelationshipStatus { none, friend, outgoingPending, incomingPending }

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  UserProfile _profileFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? <String, dynamic>{});
    data['uid'] = (data['uid'] as String?)?.trim().isNotEmpty == true
        ? data['uid']
        : doc.id;
    return UserProfile.fromMap(data);
  }

  Iterable<List<T>> _chunk<T>(List<T> values, int size) sync* {
    for (var index = 0; index < values.length; index += size) {
      final end = (index + size).clamp(0, values.length);
      yield values.sublist(index, end);
    }
  }

  // Search users by exact email
  Future<List<UserProfile>> searchUsersByEmail(String email) async {
    if (email.isEmpty) return [];
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .get();

    return snapshot.docs
        .map(_profileFromDoc)
        .where((user) => user.uid != userId) // exclude self
        .toList();
  }

  Future<List<UserProfile>> searchUsers(String query, {int limit = 12}) async {
    final cleanQuery = _cleanSearchQuery(query);
    if (cleanQuery.length < _minUserSearchCharacters) {
      return [];
    }

    final resultsById = <String, UserProfile>{};

    final usernameSnapshot = await _db
        .collection('users')
        .orderBy('username')
        .startAt([cleanQuery])
        .endAt(['$cleanQuery\uf8ff'])
        .limit(limit)
        .get();

    for (final doc in usernameSnapshot.docs) {
      final user = _profileFromDoc(doc);
      if (user.uid != userId) {
        resultsById[user.uid] = user;
      }
    }

    if (query.trim().contains('@') && resultsById.length < limit) {
      final emailSnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: query.trim().toLowerCase())
          .limit(1)
          .get();

      for (final doc in emailSnapshot.docs) {
        final user = _profileFromDoc(doc);
        if (user.uid != userId) {
          resultsById[user.uid] = user;
        }
      }
    }

    final users = resultsById.values.toList();
    users.sort((a, b) {
      final aUsername = (a.username ?? '').toLowerCase();
      final bUsername = (b.username ?? '').toLowerCase();
      final aStarts = aUsername.startsWith(cleanQuery);
      final bStarts = bUsername.startsWith(cleanQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return _searchLabel(a).compareTo(_searchLabel(b));
    });
    return users.take(limit).toList();
  }

  Future<List<UserProfile>> searchUsersByUsername(String username) {
    return searchUsers(username);
  }

  Future<Map<String, FriendRelationshipStatus>> relationshipStatusesFor(
    Iterable<String> userIds,
  ) async {
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != userId)
        .toSet();
    if (userId.isEmpty || ids.isEmpty) return {};

    final statuses = {for (final id in ids) id: FriendRelationshipStatus.none};

    final myProfile = await getUserProfile(userId);
    for (final friendId in myProfile?.friends ?? const <String>[]) {
      if (statuses.containsKey(friendId)) {
        statuses[friendId] = FriendRelationshipStatus.friend;
      }
    }

    final outgoing = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in outgoing.docs) {
      final toUserId = (doc.data()['to'] as String? ?? '').trim();
      if (statuses[toUserId] == FriendRelationshipStatus.none) {
        statuses[toUserId] = FriendRelationshipStatus.outgoingPending;
      }
    }

    final incoming = await _db
        .collection('friendRequests')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in incoming.docs) {
      final fromUserId = (doc.data()['from'] as String? ?? '').trim();
      if (statuses[fromUserId] == FriendRelationshipStatus.none) {
        statuses[fromUserId] = FriendRelationshipStatus.incomingPending;
      }
    }

    return statuses;
  }

  // Check if a username is available
  Future<bool> isUsernameAvailable(String username) async {
    if (userId.isEmpty || username.isEmpty) return false;
    final cleanUsername = username.startsWith('@')
        ? username.substring(1).toLowerCase()
        : username.toLowerCase();

    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .get();

    if (snapshot.docs.isEmpty) return true;
    if (snapshot.docs.length == 1 && snapshot.docs.first.id == userId) {
      return true;
    }
    return false;
  }

  // Update Profile
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? photoUrl,
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to update your profile.');
    }

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (username != null) {
      updates['username'] = username.startsWith('@')
          ? username.substring(1).toLowerCase()
          : username.toLowerCase();
    }

    if (updates.isNotEmpty) {
      await _db.collection('users').doc(userId).update(updates);
    }
  }

  // Get a specific user profile
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return _profileFromDoc(doc);
    }
    return null;
  }

  // Stream of pending friend requests FOR the current user
  Stream<QuerySnapshot> streamIncomingFriendRequests() {
    return _db
        .collection('friendRequests')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Send friend request
  Future<FriendRequestResult> sendFriendRequest(String toUserId) async {
    if (userId.isEmpty || toUserId.isEmpty || toUserId == userId) {
      return FriendRequestResult.unavailable;
    }

    // Check if already friends
    final myProfile = await getUserProfile(userId);
    if (myProfile != null && myProfile.friends.contains(toUserId)) {
      return FriendRequestResult.alreadyFriends;
    }

    // Check if request already exists
    final existing = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: userId)
        .where('to', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return FriendRequestResult.alreadyPending;

    final reverseExisting = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: toUserId)
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reverseExisting.docs.isNotEmpty) {
      await acceptFriendRequest(reverseExisting.docs.first.id, toUserId);
      return FriendRequestResult.acceptedIncoming;
    }

    await _db.collection('friendRequests').add({
      'from': userId,
      'to': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return FriendRequestResult.sent;
  }

  String _cleanSearchQuery(String query) {
    final value = query.trim().toLowerCase();
    return value.startsWith('@') ? value.substring(1) : value;
  }

  String _searchLabel(UserProfile user) {
    final username = user.username?.trim().toLowerCase() ?? '';
    if (username.isNotEmpty) return username;
    final name = user.displayName.trim().toLowerCase();
    if (name.isNotEmpty) return name;
    return user.email.trim().toLowerCase();
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    if (userId.isEmpty) return;

    final reqRef = _db.collection('friendRequests').doc(requestId);
    final myRef = _db.collection('users').doc(userId);
    final otherRef = _db.collection('users').doc(fromUserId);

    await _db.runTransaction((transaction) async {
      final requestDoc = await transaction.get(reqRef);
      if (!requestDoc.exists || requestDoc.data() == null) {
        throw StateError('Friend request no longer exists.');
      }

      final request = requestDoc.data()!;
      if (request['to'] != userId ||
          request['from'] != fromUserId ||
          request['status'] != 'pending') {
        throw StateError('Friend request is no longer pending.');
      }

      transaction.update(reqRef, {'status': 'accepted'});
      transaction.set(myRef, {
        'friends': FieldValue.arrayUnion([fromUserId]),
      }, SetOptions(merge: true));
      transaction.update(otherRef, {
        'friends': FieldValue.arrayUnion([userId]),
      });
    });
  }

  // Decline a friend request
  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  // Get friends profiles
  Stream<List<UserProfile>> streamFriends() {
    if (userId.isEmpty) return Stream.value([]);

    return _db.collection('users').doc(userId).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists || doc.data() == null) return [];

      final profile = UserProfile.fromMap(doc.data()!);
      if (profile.friends.isEmpty) return [];

      final profiles = <UserProfile>[];
      for (final ids in _chunk(profile.friends, 10)) {
        final friendsDocs = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: ids)
            .get();
        profiles.addAll(friendsDocs.docs.map(_profileFromDoc));
      }

      profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
      return profiles;
    });
  }

  // Remove an existing friend connection from both user profiles.
  Future<void> removeFriend(String friendUserId) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to remove a friend.');
    }
    if (friendUserId.isEmpty || friendUserId == userId) {
      return;
    }

    final myRef = _db.collection('users').doc(userId);
    final friendRef = _db.collection('users').doc(friendUserId);

    await _db.runTransaction((transaction) async {
      final myDoc = await transaction.get(myRef);
      final friendDoc = await transaction.get(friendRef);
      if (!myDoc.exists || !friendDoc.exists) {
        throw StateError('Friend profile no longer exists.');
      }

      final myFriends = List<String>.from(
        (myDoc.data()?['friends'] as List?) ?? const <String>[],
      );
      final friendFriends = List<String>.from(
        (friendDoc.data()?['friends'] as List?) ?? const <String>[],
      );

      if (!myFriends.contains(friendUserId) &&
          !friendFriends.contains(userId)) {
        return;
      }

      transaction.update(myRef, {
        'friends': FieldValue.arrayRemove([friendUserId]),
      });
      transaction.update(friendRef, {
        'friends': FieldValue.arrayRemove([userId]),
      });
    });
  }

  // ---------------- HABIT INVITES ----------------

  // Stream of pending habit invites FOR the current user
  Stream<QuerySnapshot> streamHabitInvites() {
    return _db
        .collection('habitInvites')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Send a habit invite
  Future<void> sendHabitInvite({
    required String habitId,
    required String toUserId,
  }) async {
    if (userId.isEmpty || toUserId.isEmpty) return;

    final habitDoc = await _db.collection('habits').doc(habitId).get();
    if (habitDoc.exists) {
      final participants = List<String>.from(
        (habitDoc.data()?['participants'] as List?) ?? const <String>[],
      );
      if (participants.length >= kSharedTaskMaxMembers) {
        throw StateError('Shared task already has the maximum of 3 members.');
      }
    }

    final existing = await _db
        .collection('habitInvites')
        .where('from', isEqualTo: userId)
        .where('to', isEqualTo: toUserId)
        .where('habitId', isEqualTo: habitId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return;

    await _db.collection('habitInvites').add({
      'from': userId,
      'to': toUserId,
      'habitId': habitId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept Habit Invite
  Future<void> acceptHabitInvite(String inviteId, String habitId) async {
    if (userId.isEmpty) return;

    final hasAccess = await _subscriptionService.hasPremiumAccess(userId);
    if (!hasAccess) {
      final sharedCount = await _subscriptionService
          .sharedTaskParticipationCount(userId);
      if (sharedCount >= kFreeSharedTaskLimit) {
        throw const UpgradeRequiredException(
          'Free tier allows up to 3 shared tasks. Upgrade to Trackly Pro.',
        );
      }
    }

    final habitDoc = await _db.collection('habits').doc(habitId).get();
    if (habitDoc.exists) {
      final participants = List<String>.from(
        (habitDoc.data()?['participants'] as List?) ?? const <String>[],
      );
      if (!participants.contains(userId) &&
          participants.length >= kSharedTaskMaxMembers) {
        throw StateError('Shared task is full (max 3 members).');
      }
    }

    final batch = _db.batch();

    // 1. Mark invite as accepted
    final reqRef = _db.collection('habitInvites').doc(inviteId);
    batch.update(reqRef, {'status': 'accepted'});

    // 2. Add current user to habit participants and upgrade to shared task
    final habitRef = _db.collection('habits').doc(habitId);
    batch.update(habitRef, {
      'participants': FieldValue.arrayUnion([userId]),
      'spaceType': 'sharedTask',
    });

    await batch.commit();
  }

  // Decline Habit Invite
  Future<void> declineHabitInvite(String inviteId) async {
    await _db.collection('habitInvites').doc(inviteId).update({
      'status': 'declined',
    });
  }

  // ---------------- GROUP INVITES ----------------

  Stream<QuerySnapshot> streamGroupInvites() {
    return _db
        .collection('groupInvites')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot> streamChallengeInvites() {
    return _db
        .collection('challengeInvites')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptChallengeInvite({
    required String inviteId,
    required String groupId,
    required String challengeId,
  }) async {
    await GroupService().acceptChallengeInvite(
      inviteId: inviteId,
      groupId: groupId,
      challengeId: challengeId,
    );
  }

  Future<void> declineChallengeInvite(String inviteId) async {
    await GroupService().declineChallengeInvite(inviteId);
  }

  Future<void> sendGroupInvite({
    required String groupId,
    String? groupName,
    required String toUserId,
  }) async {
    if (userId.isEmpty || toUserId.isEmpty || groupId.isEmpty) return;

    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (groupDoc.exists) {
      final memberIds = List<String>.from(
        (groupDoc.data()?['memberIds'] as List?) ?? const <String>[],
      );
      if (memberIds.contains(toUserId)) {
        return;
      }
    }

    final existing = await _db
        .collection('groupInvites')
        .where('from', isEqualTo: userId)
        .where('to', isEqualTo: toUserId)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return;

    final invite = GroupInvite(
      id: '',
      groupId: groupId,
      groupName: groupName,
      fromUserId: userId,
      toUserId: toUserId,
      createdAt: DateTime.now(),
    );

    await _db.collection('groupInvites').add(invite.toMap());
  }

  Future<void> acceptGroupInvite(String inviteId, String groupId) async {
    if (userId.isEmpty) return;

    final info = await _subscriptionService.getCustomerInfo();
    final hasAccess = await _subscriptionService.canAccessPremiumFeatures(
      userId: userId,
      customerInfo: info,
    );
    if (!hasAccess) {
      throw const UpgradeRequiredException(
        'Trackly Pro is required to join groups.',
      );
    }

    final groupRef = _db.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();
    final batch = _db.batch();

    final inviteRef = _db.collection('groupInvites').doc(inviteId);
    batch.update(inviteRef, {'status': 'accepted'});

    if (groupDoc.exists) {
      batch.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([userId]),
      });
    } else {
      // Backward compatibility: older builds stored groups in habits.
      final legacyGroupRef = _db.collection('habits').doc(groupId);
      batch.update(legacyGroupRef, {
        'participants': FieldValue.arrayUnion([userId]),
      });
    }

    await batch.commit();

    if (groupDoc.exists) {
      try {
        await groupRef.update({
          'leftMemberIds': FieldValue.arrayRemove([userId]),
        });
      } catch (_) {
        // Best effort cleanup for users rejoining a previously left group.
      }
      try {
        await GroupService().clearHiddenGroup(groupId);
      } catch (_) {
        // Best effort cleanup for local leave tombstone.
      }
      await GroupService().syncTaskMirrorsForGroup(groupId);
    }
  }

  Future<void> declineGroupInvite(String inviteId) async {
    await _db.collection('groupInvites').doc(inviteId).update({
      'status': 'declined',
    });
  }

  Future<void> notifyHabitParticipantLeft({
    required Habit habit,
    required String departingUserId,
    required List<String> remainingParticipantIds,
  }) async {
    if (remainingParticipantIds.isEmpty) {
      return;
    }

    final departingProfile = await getUserProfile(departingUserId);
    final departingName = departingProfile?.displayName ?? 'A participant';
    final habitLabel = habit.isGroup
        ? ((habit.groupName ?? '').trim().isEmpty
              ? habit.title
              : habit.groupName!.trim())
        : habit.title;

    final noticeMessage =
        '$departingName left "$habitLabel". The habit is still active for you.';

    final batch = _db.batch();
    for (final participantId in remainingParticipantIds) {
      final noticeRef = _db.collection('habitNotices').doc();
      batch.set(noticeRef, {
        'type': 'participantLeft',
        'to': participantId,
        'from': departingUserId,
        'habitId': habit.id,
        'habitTitle': habit.title,
        'groupName': habit.groupName,
        'message': noticeMessage,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
