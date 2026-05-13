import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/shopping_list/data/shopping_list_repository.dart';
import '../../features/shopping_list/domain/shopping_item.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (_) => ShoppingListRepository(),
);

final shoppingListProvider = StreamProvider<List<ShoppingItem>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref
      .watch(shoppingListRepositoryProvider)
      .watchShoppingList(user.uid);
});
