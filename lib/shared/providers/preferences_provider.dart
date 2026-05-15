import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/user_preferences.dart';
import 'auth_provider.dart';

final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const UserPreferences.empty());
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) {
        if (!snap.exists) return const UserPreferences.empty();
        final data = snap.data()?['manualPrefs'] as Map<String, dynamic>?;
        return data != null
            ? UserPreferences.fromJson(data)
            : const UserPreferences.empty();
      });
    },
    loading: () => Stream.value(const UserPreferences.empty()),
    error: (e, s) => Stream.value(const UserPreferences.empty()),
  );
});

class PreferencesNotifier extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const UserPreferences.empty();
    final doc =
        await FirebaseFirestore.instance.doc('users/$uid').get();
    final data = doc.data()?['manualPrefs'] as Map<String, dynamic>?;
    return data != null
        ? UserPreferences.fromJson(data)
        : const UserPreferences.empty();
  }

  Future<void> savePreferences(UserPreferences prefs) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    state = AsyncData(prefs);
    await FirebaseFirestore.instance.doc('users/$uid').set(
      {'manualPrefs': prefs.toJson()},
      SetOptions(merge: true),
    );
  }
}

final preferencesNotifierProvider =
    AsyncNotifierProvider<PreferencesNotifier, UserPreferences>(
  PreferencesNotifier.new,
);
