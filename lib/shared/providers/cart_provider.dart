import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/cart/data/cart_repository.dart';
import '../../features/cart/domain/cart_item.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (_) => CartRepository(),
);

final cartProvider = StreamProvider<List<CartItem>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.watch(cartRepositoryProvider).watchCart(user.uid);
});
