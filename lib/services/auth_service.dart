// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
//
// class AuthService {
//   final _auth = FirebaseAuth.instance;
//
//   Future<UserCredential> signInWithEmail(String email, String password) async {
//     return _auth.signInWithEmailAndPassword(email: email, password: password);
//   }
//
//   Future<UserCredential> signUpWithEmail(String email, String password) async {
//     return _auth.createUserWithEmailAndPassword(email: email, password: password);
//   }
//
//   Future<UserCredential> signInWithGoogle() async {
//     final googleUser = await GoogleSignIn().signIn();
//     if (googleUser == null) throw Exception('Sign in aborted');
//
//     final googleAuth = await googleUser.authentication;
//     final credential = GoogleAuthProvider.credential(
//       accessToken: googleAuth.accessToken,
//       idToken: googleAuth.idToken,
//     );
//     return _auth.signInWithCredential(credential);
//   }
//
//   Future<void> signOut() async {
//     await _auth.signOut();
//     try { await GoogleSignIn().signOut(); } catch (_) {}
//   }
// }

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Future<UserCredential> signUpWithEmail(String email, String password) {
  //   return _auth.createUserWithEmailAndPassword(email: email, password: password);
  // }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Re-authenticate (with current password) and set a new password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'Not signed in.');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}