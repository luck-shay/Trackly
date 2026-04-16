import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/group_invite.dart';
import '../models/habit.dart';

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
        .map((doc) => UserProfile.fromMap(doc.data()))
        .where((user) => user.uid != userId) // exclude self
        .toList();
  }

  // Search users by username (exact match, lowercase)
  Future<List<UserProfile>> searchUsersByUsername(String username) async {
    if (username.isEmpty) return [];

    // Strip the @ if user typed it
    final cleanUsername = username.startsWith('@')
        ? username.substring(1)
        : username;

    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: cleanUsername.toLowerCase())
        .get();

    return snapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data()))
        .where((user) => user.uid != userId)
        .toList();
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
  Future<void> updateProfile({String? displayName, String? username, String? photoUrl}) async {
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
      return UserProfile.fromMap(doc.data()!);
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
  Future<void> sendFriendRequest(String toUserId) async {
    if (userId.isEmpty || toUserId.isEmpty) return;
    if (toUserId == userId) return;

    // Check if already friends
    final myProfile = await getUserProfile(userId);
    if (myProfile != null && myProfile.friends.contains(toUserId)) {
      return;
    }

    // Check if request already exists
    final existing = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: userId)
        .where('to', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return;

    final reverseExisting = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: toUserId)
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reverseExisting.docs.isNotEmpty) return;

    await _db.collection('friendRequests').add({
      'from': userId,
      'to': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    if (userId.isEmpty) return;

    final batch = _db.batch();

    // 1. Mark request as accepted
    final reqRef = _db.collection('friendRequests').doc(requestId);
    batch.update(reqRef, {'status': 'accepted'});

    // 2. Add fromUserId to my friends list
    final myRef = _db.collection('users').doc(userId);
    batch.update(myRef, {
      'friends': FieldValue.arrayUnion([fromUserId]),
    });

    // 3. Add my userId to fromUser's friends list
    final otherRef = _db.collection('users').doc(fromUserId);
    batch.update(otherRef, {
      'friends': FieldValue.arrayUnion([userId]),
    });

    await batch.commit();
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
            .where('uid', whereIn: ids)
            .get();
        profiles.addAll(
          friendsDocs.docs.map((d) => UserProfile.fromMap(d.data())),
        );
      }

      profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
      return profiles;
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

    final batch = _db.batch();

    // 1. Mark invite as accepted
    final reqRef = _db.collection('habitInvites').doc(inviteId);
    batch.update(reqRef, {'status': 'accepted'});

    // 2. Add current user to habit participants
    final habitRef = _db.collection('habits').doc(habitId);
    batch.update(habitRef, {
      'participants': FieldValue.arrayUnion([userId]),
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

  Future<void> sendGroupInvite({
    required String groupId,
    String? groupName,
    required String toUserId,
  }) async {
    if (userId.isEmpty || toUserId.isEmpty || groupId.isEmpty) return;

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

    final batch = _db.batch();

    final inviteRef = _db.collection('groupInvites').doc(inviteId);
    batch.update(inviteRef, {'status': 'accepted'});

    final groupRef = _db.collection('habits').doc(groupId);
    batch.update(groupRef, {
      'participants': FieldValue.arrayUnion([userId]),
    });

    await batch.commit();
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
