import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

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
        return userCredential;
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out of Google: $e');
    }
    await _auth.signOut();
  }

  Future<void> syncUserToFirestore(User? user) async {
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final docRef = db.collection('users').doc(user.uid);

    final doc = await docRef.get();
    if (!doc.exists) {
      // Create new profile
      final profile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Anonymous User',
        photoUrl: user.photoURL,
      );
      await docRef.set(profile.toMap());
    } else {
      // Update auth-linked fields, but preserve user-edited displayName.
      final existing = doc.data() ?? <String, dynamic>{};
      final currentDisplayName =
          (existing['displayName'] as String?)?.trim() ?? '';
      final updates = <String, dynamic>{
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
      };

      if (currentDisplayName.isEmpty) {
        updates['displayName'] = user.displayName ?? 'Anonymous User';
      }

      await docRef.update(updates);
    }
    
    if (!kIsWeb) {
      await NotificationService().saveTokenToDatabase();
    }
  }
}
