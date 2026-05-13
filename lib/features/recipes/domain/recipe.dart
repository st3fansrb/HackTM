import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'buc',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };

  RecipeIngredient copyWith({
    String? name,
    double? quantity,
    String? unit,
  }) =>
      RecipeIngredient(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
      );
}

class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final int prepTime;
  final int servings;
  final List<String> dietaryTags;
  final DateTime savedAt;
  final String source;
  final bool isFavorite;

  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.prepTime,
    this.servings = 4,
    required this.dietaryTags,
    required this.savedAt,
    required this.source,
    this.isFavorite = false,
  });

  factory Recipe.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Recipe(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ingredients: ((data['ingredients'] as List?) ?? [])
          .map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
          .toList(),
      steps: List<String>.from((data['steps'] as List?) ?? []),
      prepTime: data['prepTime'] as int? ?? 0,
      servings: data['servings'] as int? ?? 4,
      dietaryTags: List<String>.from((data['dietaryTags'] as List?) ?? []),
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? 'manual',
      isFavorite: data['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
        'steps': steps,
        'prepTime': prepTime,
        'servings': servings,
        'dietaryTags': dietaryTags,
        'savedAt': FieldValue.serverTimestamp(),
        'source': source,
        'isFavorite': isFavorite,
      };

  Recipe copyWith({
    String? id,
    String? name,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    int? prepTime,
    int? servings,
    List<String>? dietaryTags,
    DateTime? savedAt,
    String? source,
    bool? isFavorite,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        prepTime: prepTime ?? this.prepTime,
        servings: servings ?? this.servings,
        dietaryTags: dietaryTags ?? this.dietaryTags,
        savedAt: savedAt ?? this.savedAt,
        source: source ?? this.source,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}
