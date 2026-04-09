import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
      'friends': FieldValue.arrayUnion([fromUserId])
    });

    // 3. Add my userId to fromUser's friends list
    final otherRef = _db.collection('users').doc(fromUserId);
    batch.update(otherRef, {
      'friends': FieldValue.arrayUnion([userId])
    });

    await batch.commit();
  }

  // Decline a friend request
  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'declined'
    });
  }

  // Get friends profiles
  Stream<List<UserProfile>> streamFriends() {
    if (userId.isEmpty) return Stream.value([]);
    
    return _db.collection('users').doc(userId).snapshots().asyncMap((doc) async {
      if (!doc.exists || doc.data() == null) return [];
      
      final profile = UserProfile.fromMap(doc.data()!);
      if (profile.friends.isEmpty) return [];

      // Fetch profiles of friends
      final friendsDocs = await _db
          .collection('users')
          .where('uid', whereIn: profile.friends)
          .get();

      return friendsDocs.docs
          .map((d) => UserProfile.fromMap(d.data()))
          .toList();
    });
  }
}
