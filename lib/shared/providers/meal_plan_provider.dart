import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/user_profile.dart';
import '../../features/meal_planner/data/groq_service.dart';
import '../../features/meal_planner/data/preferences_extractor.dart';
import '../../features/meal_planner/domain/weekly_plan.dart';
import '../../features/pantry/domain/food_item.dart';

String currentWeekId() {
  final now = DateTime.now();
  final thursday = now.add(Duration(days: 4 - now.weekday));
  final firstDayOfYear = DateTime(thursday.year, 1, 1);
  final weekNum =
      ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
  return 'week_${thursday.year}_${weekNum.toString().padLeft(2, '0')}';
}

final weeklyPlanProvider = StreamProvider<WeeklyPlan?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  final weekId = currentWeekId();
  return FirebaseFirestore.instance
      .doc('users/${user.uid}/weekly_plans/$weekId')
      .snapshots()
      .map((snap) => snap.exists && snap.data() != null
          ? WeeklyPlan.fromFirestore(snap.data()!)
          : null);
});

bool _matches(String a, String b) {
  final x = a.toLowerCase().trim();
  final y = b.toLowerCase().trim();
  if (x.isEmpty || y.isEmpty) return false;
  return x.contains(y) || y.contains(x);
}

/// Înlocuiește rețeta unei singure zile din planul săptămânii cu o alternativă
/// generată de AI. Rescrie tot array-ul `days` cu ziua modificată, păstrând
/// celelalte zile neatinse.
Future<void> regenerateSingleMeal({
  required String uid,
  required String weekId,
  required int dayIndex,
  required List<FoodItem> pantryItems,
  UserProfile? profile,
}) async {
  final docRef =
      FirebaseFirestore.instance.doc('users/$uid/weekly_plans/$weekId');
  final snap = await docRef.get();
  final data = snap.data();
  if (data == null) throw Exception('Planul nu există.');

  final days = (data['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  if (dayIndex < 0 || dayIndex >= days.length) {
    throw Exception('Zi invalidă.');
  }

  final dayName = days[dayIndex]['day'] as String? ?? '';

  // Numele rețetelor existente în tot planul — pentru a evita repetarea.
  final existingNames = <String>[];
  for (final day in days) {
    for (final meal in (day['meals'] as List?) ?? []) {
      final n = (meal as Map)['name'] as String?;
      if (n != null && n.isNotEmpty) existingNames.add(n);
    }
  }

  final prefs = await _loadPrefs(uid);

  final raw = await GroqService().regenerateSingleMeal(
    pantryItems,
    dayName: dayName,
    existingRecipeNames: existingNames,
    profile: profile,
    prefs: prefs,
  );

  final parsed = jsonDecode(_stripFences(raw)) as Map<String, dynamic>;
  final name = parsed['name'] as String? ?? '';
  if (name.isEmpty) throw Exception('Răspuns AI invalid.');

  final ingredients = (parsed['ingredients'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      [];
  final instructions = parsed['instructions'] as String? ?? '';

  // Împarte ingredientele în disponibile / de cumpărat față de pantry.
  final owned = profile?.ownedCondiments ?? [];
  final available = <String>[];
  final missing = <String>[];
  for (final ing in ingredients) {
    final mi = MealIngredient.fromJson(ing);
    final ingName = mi.name.trim();
    if (ingName.isEmpty) continue;
    final label = mi.display;
    final inPantry = pantryItems.any((p) => _matches(p.name, ingName));
    final isOwned = owned.any((c) => _matches(c, ingName));
    if (inPantry || isOwned) {
      available.add(label);
    } else {
      missing.add(label);
    }
  }

  days[dayIndex] = {
    'day': dayName,
    'meals': [
      {
        'name': name,
        'ingredients': ingredients,
        'instructions': instructions,
        'ingredients_available': available,
        'ingredients_missing': missing,
      },
    ],
  };

  await docRef.update({'days': days});
}

Future<ExtractedPreferences> _loadPrefs(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
    final prefsData = doc.data()?['preferences'] as Map<String, dynamic>?;
    if (prefsData == null) return ExtractedPreferences.empty();
    return ExtractedPreferences.fromJson(prefsData);
  } catch (_) {
    return ExtractedPreferences.empty();
  }
}

String _stripFences(String raw) {
  var s = raw.trim();
  if (s.startsWith('```')) {
    s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
    if (s.endsWith('```')) s = s.substring(0, s.length - 3);
  }
  return s.trim();
}
