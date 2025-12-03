import 'package:firebase_auth/firebase_auth.dart';


class AuthService {
  static Future<UserCredential> loginWithEmailAndPassword(
      String email,
      String password
      ) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  static String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Login failed: ${e.message ?? 'Unknown error.'}';
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  static Stream<User?> get authStateChanges {
    return FirebaseAuth.instance.authStateChanges();
  }

  static User? get currentUser {
    return FirebaseAuth.instance.currentUser;
  }
}