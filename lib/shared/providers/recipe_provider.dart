import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/recipes/data/recipe_repository.dart';
import '../../features/recipes/domain/recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (_) => RecipeRepository(),
);

final recipeProvider = StreamProvider<List<Recipe>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.watch(recipeRepositoryProvider).watchRecipes(user.uid);
});
