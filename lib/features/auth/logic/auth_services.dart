import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle({String? serverClientId}) async {
    try {
      final effectiveServerClientId =
          serverClientId ??
          dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
          dotenv.env['FIREBASE_WEB_CLIENT_ID'];

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: effectiveServerClientId,
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'username': user.displayName ?? 'User',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ApiException: 10') || msg.contains(': 10')) {
        throw 'Google Sign-In configuration error (ApiException: 10): Debug SHA-1 is not registered in Firebase Console, or Google Sign-In is not enabled.';
      }
      throw 'Google Sign-In failed: $e';
    }
  }

  // Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign up with email, password, and username
  Future<void> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      // Create user with email and password
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update displayName in Firebase Auth
      await userCredential.user!.updateDisplayName(username);
      // Refresh user to ensure displayName is updated
      await userCredential.user!.reload();

      // Store username in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'Failed to save user data: $e';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'The email is already in use.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get username (from displayName or Firestore fallback)
  Future<String> getUsername() async {
    final user = _auth.currentUser;
    if (user == null) return 'User';

    // Try displayName first
    await user.reload(); // Refresh user to get latest data
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }

    // Fallback to Firestore
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final username = doc.data()?['username'] as String?;
        if (username != null && username.isNotEmpty) {
          // Update displayName if found in Firestore
          await user.updateDisplayName(username);
          await user.reload();
          return username;
        }
      }
    } catch (e) {
      debugPrint('Error fetching username from Firestore: $e');
    }

    return 'User'; // Default fallback
  }

  // Get user profile photo (from photoURL or Firestore fallback)
  Future<String?> getPhotoUrl() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      return user.photoURL;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final photoUrl = doc.data()?['photoUrl'] as String?;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          await user.updatePhotoURL(photoUrl);
          return photoUrl;
        }
      }
    } catch (e) {
      debugPrint('Error fetching photoUrl from Firestore: $e');
    }

    return null;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
