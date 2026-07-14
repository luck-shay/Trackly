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
    final email = (user.email ?? '').toLowerCase();
    final displayName = user.displayName ?? 'Anonymous User';
    final photoUrl = user.photoURL;

    if (!doc.exists) {
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        displayName: displayName,
        username: await _resolveInitialUsername(user),
        photoUrl: photoUrl,
      );
      await docRef.set(profile.toMap());
    } else {
      // Update auth-linked fields, but preserve user-edited displayName.
      final existing = doc.data() ?? <String, dynamic>{};
      final currentDisplayName =
          (existing['displayName'] as String?)?.trim() ?? '';
      final currentPhotoUrl = (existing['photoUrl'] as String?)?.trim() ?? '';
      final currentFriends = existing['friends'];
      final updates = <String, dynamic>{'uid': user.uid, 'email': email};

      // Keep a customized profile picture if the user has already set one.
      if (currentPhotoUrl.isEmpty) {
        updates['photoUrl'] = photoUrl;
      }

      if (currentDisplayName.isEmpty) {
        updates['displayName'] = displayName;
      }

      if (currentFriends is! List) {
        updates['friends'] = <String>[];
      }

      // Username is intentionally only generated when the profile document is
      // first created. Later logins must never replace a custom username.
      await docRef.set(updates, SetOptions(merge: true));
    }

    if (!kIsWeb) {
      await NotificationService().saveTokenToDatabase();
    }
  }

  Future<void> completeOnboarding(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'onboardingCompleted': true});
  }

  Future<void> _syncSubscriptionIdentity(String userId) async {
    try {
      await _subscriptionService.logIn(userId);
    } catch (error) {
      debugPrint('RevenueCat login skipped: $error');
    }
  }

  Future<String?> _resolveInitialUsername(User user) async {
    final base = _sanitizeUsernameBase(
      _localPartFromEmail(user.email),
    ).ifEmpty(_sanitizeUsernameBase(user.displayName)).ifEmpty('user');

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: base)
        .get();

    final isAvailable =
        snapshot.docs.isEmpty ||
        (snapshot.docs.length == 1 && snapshot.docs.first.id == user.uid);
    if (isAvailable) return base;

    return '$base-${_shortUidSuffix(user.uid)}';
  }

  String _localPartFromEmail(String? email) {
    final value = (email ?? '').trim();
    if (value.isEmpty || !value.contains('@')) return '';
    return value.split('@').first;
  }

  String _sanitizeUsernameBase(String? value) {
    final cleaned = (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    if (cleaned.length <= 20) return cleaned;
    return cleaned.substring(0, 20);
  }

  String _shortUidSuffix(String uid) {
    if (uid.isEmpty) return '000000';
    return uid.length <= 6 ? uid : uid.substring(uid.length - 6);
  }
}

extension _StringFallback on String {
  String ifEmpty(String? fallback) {
    if (trim().isNotEmpty) return this;
    return (fallback ?? '').trim();
  }
}
