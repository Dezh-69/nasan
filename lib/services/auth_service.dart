import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Register with username (stored as email: username@nasan.local), password, and optional phone number
  Future<UserCredential> register(String username, String password, String displayName, {String? phoneNumber}) async {
    final email = '${username.toLowerCase().trim()}@nasan.local';
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.updateDisplayName(displayName);

    // Get FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();

    // Create user document in Firestore
    await _firestore.collection('users').doc(credential.user!.uid).set({
      'displayName': displayName,
      'username': username.toLowerCase().trim(),
      'phoneNumber': phoneNumber?.trim(), // Added phone number
      'fcmToken': fcmToken,
      'familyGroupIds': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  /// Login with username and password
  Future<UserCredential> login(String username, String password) async {
    final email = '${username.toLowerCase().trim()}@nasan.local';
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update FCM token on login
    final fcmToken = await FirebaseMessaging.instance.getToken();
    await _firestore.collection('users').doc(credential.user!.uid).update({
      'fcmToken': fcmToken,
    });

    return credential;
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Update FCM token (call this when token refreshes)
  Future<void> updateFcmToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
      });
    }
  }
}
