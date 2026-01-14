import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserModel?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        return await getUserData(credential.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserModel?> signUp(String email, String password, String displayName) async {
    User? firebaseUser;
    
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      firebaseUser = credential.user;
    } catch (e) {
      if (_auth.currentUser != null) {
        firebaseUser = _auth.currentUser;
      } else {
        if (e is FirebaseAuthException) throw _handleAuthException(e);

        // idc anymore
        if (e.toString().contains("PigeonUserDetails") && _auth.currentUser != null) {
           firebaseUser = _auth.currentUser;
        } else {
           rethrow;
        }
      }
    }
      
    if (firebaseUser != null) {
      try {
        final user = UserModel(
          uid: firebaseUser.uid,
          email: email,
          displayName: displayName,
          createdAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(user.uid).set(user.toJson());
        
        // Try updating display name, ignore if it fails
        try {
          await firebaseUser.updateDisplayName(displayName);
        } catch (_) {}
        
        return user;
      } catch (e) {
         return UserModel(
            uid: firebaseUser.uid,
            email: email,
            displayName: displayName,
            createdAt: DateTime.now(),
         );
      }
    }
    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toJson());
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
