import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_platform_stub.dart'
    if (dart.library.html) 'auth_platform_web.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<UserCredential> signInWithEmail(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    if (kIsWeb) {
      try {
        await _auth
            .setPersistence(rememberMe ? Persistence.LOCAL : Persistence.SESSION)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Non-critical: proceed with sign-in using default persistence
      }
    }
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential?> signInWithGoogle({bool rememberMe = true}) async {
    if (kIsWeb) {
      // Fire-and-forget — do NOT await before signInWithPopup.
      // iOS Safari blocks window.open() after any await (user gesture context lost).
      _auth
          .setPersistence(rememberMe ? Persistence.LOCAL : Persistence.SESSION)
          .timeout(const Duration(seconds: 2))
          .catchError((_) {});

      if (isIosPwaStandalone()) {
        // signInWithPopup is blocked by WKWebView in iOS standalone PWA mode.
        // Use redirect instead — getRedirectResult() in main.dart captures the result on reload.
        await _auth.signInWithRedirect(GoogleAuthProvider());
        return null; // never reached — page navigates away
      }

      return _auth.signInWithPopup(GoogleAuthProvider());
    }
    return _auth.signInWithProvider(GoogleAuthProvider());
  }

  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final doc = await _db.doc('users/$userId').get();
      return doc.exists && doc.data()?['householdSize'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveUserProfile({
    required String userId,
    required String email,
    required String displayName,
    required int householdSize,
    required List<String> dietaryPreferences,
    String dietType = 'omnivor',
    List<String> allergies = const [],
    Map<String, bool>? notifications,
    List<String> ownedCondiments = const [],
  }) =>
      _db.doc('users/$userId').set({
        'email': email,
        'displayName': displayName,
        'householdSize': householdSize,
        'dietaryPreferences': dietaryPreferences,
        'dietType': dietType,
        'allergies': allergies,
        'notifications': notifications ??
            {
              'expiry_alerts': true,
              'daily_suggestions': true,
              'weekly_summary': false,
            },
        'ownedCondiments': ownedCondiments,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> signOut() => _auth.signOut();
}
