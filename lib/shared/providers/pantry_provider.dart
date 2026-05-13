import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/pantry/data/pantry_repository.dart';
import '../../features/pantry/data/seed_demo_data.dart';
import '../../features/pantry/domain/food_item.dart';

final pantryRepositoryProvider = Provider<PantryRepository>(
  (_) => PantryRepository(),
);

final pantryProvider = StreamProvider<List<FoodItem>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  seedDemoData(user.uid);
  return ref.watch(pantryRepositoryProvider).watchPantry(user.uid);
});
