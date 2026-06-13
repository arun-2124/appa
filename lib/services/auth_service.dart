import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  // Sign up
  static Future<void> signUp(String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = AppUser(
      uid: credential.user!.uid,
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  // Sign in
  static Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  static Future<AppUser?> getCurrentUser() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    return AppUser.fromMap(doc.data()!);
  }

  // Listen to auth changes
  static Stream<User?> authStateChanges() => _auth.authStateChanges();
}