import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;
  final SubscriptionService _subscriptionService = SubscriptionService();

  // Firebase Web OAuth client ID (from google-services.json, client_type: 3).
  // Required by google_sign_in on Android to issue the token used by Firebase Auth.
  static const String _googleServerClientId =
      '852142844109-k39c43icuhgd4nqheh3j33rird17a2bu.apps.googleusercontent.com';

  // Stream of auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_isGoogleSignInInitialized) return;

    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    _isGoogleSignInInitialized = true;
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Use Firebase Popup which preserves custom button UI on Web
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );
        await syncUserToFirestore(userCredential.user);
        if (userCredential.user != null) {
          await _syncSubscriptionIdentity(userCredential.user!.uid);
        }
        return userCredential;
      } else {
        await _ensureGoogleSignInInitialized();

        // Trigger the Google Authentication flow
        final GoogleSignInAccount googleUser = await _googleSignIn
            .authenticate();

        // Obtain the auth details
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // Create a new credential
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase Auth
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );
        await syncUserToFirestore(userCredential.user);
        if (userCredential.user != null) {
          await _syncSubscriptionIdentity(userCredential.user!.uid);
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (!kIsWeb && uid != null && uid.isNotEmpty) {
      await NotificationService().detachCurrentDeviceTokenFromUser(uid);
    }

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out of Google: $e');
    }
    try {
      await _subscriptionService.logOut();
    } catch (e) {
      debugPrint('Error logging out RevenueCat user: $e');
    }
    await _auth.signOut();
  }

  Future<void> syncUserToFirestore(User? user) async {
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final docRef = db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final profile = UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Anonymous User',
      photoUrl: user.photoURL,
    );

    if (!doc.exists) {
      await docRef.set(profile.toMap());
    } else {
      // Update auth-linked fields, but preserve user-edited displayName.
      final existing = doc.data() ?? <String, dynamic>{};
      final currentDisplayName =
          (existing['displayName'] as String?)?.trim() ?? '';
      final currentPhotoUrl = (existing['photoUrl'] as String?)?.trim() ?? '';
      final updates = <String, dynamic>{'email': profile.email};

      // Keep a customized profile picture if the user has already set one.
      if (currentPhotoUrl.isEmpty) {
        updates['photoUrl'] = profile.photoUrl;
      }

      if (currentDisplayName.isEmpty) {
        updates['displayName'] = profile.displayName;
      }

      await docRef.set(updates, SetOptions(merge: true));
    }

    if (!kIsWeb) {
      await NotificationService().saveTokenToDatabase();
    }
  }

  Future<void> _syncSubscriptionIdentity(String userId) async {
    try {
      await _subscriptionService.logIn(userId);
    } catch (error) {
      debugPrint('RevenueCat login skipped: $error');
    }
  }
}
