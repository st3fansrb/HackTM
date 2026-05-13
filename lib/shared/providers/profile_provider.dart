import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/user_profile.dart';
import 'auth_provider.dart';

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) =>
              snap.exists ? UserProfile.fromFirestore(snap) : null);
    },
    loading: () => Stream.value(null),
    error: (err, _) => Stream.value(null),
  );
});
