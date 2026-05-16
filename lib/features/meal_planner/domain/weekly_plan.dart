import 'package:cloud_firestore/cloud_firestore.dart';

class MealIngredient {
  final String name;
  final double? quantity;
  final String? unit;

  const MealIngredient({required this.name, this.quantity, this.unit});

  factory MealIngredient.fromJson(Map<String, dynamic> json) => MealIngredient(
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
      };

  /// "200 g făină" / "2 buc ouă" / "făină" (când nu există cantitate)
  String get display {
    final qtyStr = quantity == null
        ? ''
        : (quantity == quantity!.truncateToDouble()
            ? quantity!.toInt().toString()
            : quantity.toString());
    return [qtyStr, unit ?? '', name]
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
  }
}

class MealRecipe {
  final String name;
  final List<String> ingredientsAvailable;
  final List<String> ingredientsMissing;

  /// Ingrediente structurate (cantitate + unitate). Gol pentru planurile vechi.
  final List<MealIngredient> ingredients;

  /// Pașii de preparare. Gol pentru planurile vechi.
  final String instructions;

  const MealRecipe({
    required this.name,
    required this.ingredientsAvailable,
    required this.ingredientsMissing,
    this.ingredients = const [],
    this.instructions = '',
  });

  factory MealRecipe.fromJson(Map<String, dynamic> json) => MealRecipe(
        name: json['name'] as String? ?? '',
        ingredientsAvailable:
            (json['ingredients_available'] as List?)?.cast<String>() ?? [],
        ingredientsMissing:
            (json['ingredients_missing'] as List?)?.cast<String>() ?? [],
        ingredients: (json['ingredients'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(MealIngredient.fromJson)
                .toList() ??
            [],
        instructions: json['instructions'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'ingredients_available': ingredientsAvailable,
        'ingredients_missing': ingredientsMissing,
        if (ingredients.isNotEmpty)
          'ingredients': ingredients.map((i) => i.toJson()).toList(),
        if (instructions.isNotEmpty) 'instructions': instructions,
      };
}

class MealDay {
  final String day;
  final List<MealRecipe> meals;

  const MealDay({required this.day, required this.meals});

  factory MealDay.fromJson(Map<String, dynamic> json) => MealDay(
        day: json['day'] as String? ?? '',
        meals: (json['meals'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(MealRecipe.fromJson)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'meals': meals.map((m) => m.toJson()).toList(),
      };
}

class WeeklyPlan {
  final String weekId;
  final DateTime generatedAt;
  final List<MealDay> days;

  const WeeklyPlan({
    required this.weekId,
    required this.generatedAt,
    required this.days,
  });

  factory WeeklyPlan.fromFirestore(Map<String, dynamic> data) => WeeklyPlan(
        weekId: data['weekId'] as String? ?? '',
        generatedAt:
            (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        days: (data['days'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(MealDay.fromJson)
                .toList() ??
            [],
      );
}
