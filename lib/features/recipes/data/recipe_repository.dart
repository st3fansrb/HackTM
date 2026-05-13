import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/recipe.dart';

class RecipeRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users/$uid/recipes');

  Stream<List<Recipe>> watchRecipes(String uid) => _col(uid)
      .orderBy('savedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Recipe.fromFirestore(d)).toList());

  Future<void> addRecipe(String uid, Recipe recipe) async {
    final col = _col(uid);
    try {
      final dup = await col.where('name', isEqualTo: recipe.name).limit(1).get();
      if (dup.docs.isNotEmpty) return;
    } catch (_) {}
    await col.add(recipe.toFirestore());
  }

  Future<void> deleteRecipe(String uid, String recipeId) =>
      _col(uid).doc(recipeId).delete();

  Future<void> toggleFavorite(String uid, String recipeId, bool value) =>
      _col(uid).doc(recipeId).update({'isFavorite': value});

  Future<void> saveCookedRecipe(String uid, Recipe recipe) =>
      _db.collection('users/$uid/cookedRecipes').add({
        'recipeId': recipe.id,
        'recipeName': recipe.name,
        'cookedAt': FieldValue.serverTimestamp(),
        'ingredients': recipe.ingredients.map((i) => i.toMap()).toList(),
      });
}
