import 'package:cloud_firestore/cloud_firestore.dart';

class MealRecipe {
  final String name;
  final List<String> ingredientsAvailable;
  final List<String> ingredientsMissing;

  const MealRecipe({
    required this.name,
    required this.ingredientsAvailable,
    required this.ingredientsMissing,
  });

  factory MealRecipe.fromJson(Map<String, dynamic> json) => MealRecipe(
        name: json['name'] as String? ?? '',
        ingredientsAvailable:
            (json['ingredients_available'] as List?)?.cast<String>() ?? [],
        ingredientsMissing:
            (json['ingredients_missing'] as List?)?.cast<String>() ?? [],
      );
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
