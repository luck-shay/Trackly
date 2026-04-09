import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Stream of auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Use Firebase Popup which preserves custom button UI on Web
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        await syncUserToFirestore(userCredential.user);
        return userCredential;
      } else {
        // Trigger the Google Authentication flow
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
        
        // Obtain the auth details
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // Create a new credential
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase Auth
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        await syncUserToFirestore(userCredential.user);
        return userCredential;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out of Google: $e');
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
      // Update existing profile fields that might change
      await docRef.update({
        'email': user.email ?? '',
        'displayName': user.displayName ?? 'Anonymous User',
        'photoUrl': user.photoURL,
      });
    }
  }
}
