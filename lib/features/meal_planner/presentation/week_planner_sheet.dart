import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/recipe_provider.dart';
import '../../../features/shopping_list/data/shopping_list_repository.dart';
import '../../../features/shopping_list/domain/shopping_item.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../data/groq_service.dart';
import '../data/preferences_extractor.dart';

/// Respinge textul explicativ scăpat neparsat din răspunsul AI, ca să nu
/// ajungă în lista de cumpărături (ex: "avocado sau alte ingrediente,
/// dacă doriți...").
bool isMeaningfulIngredient(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s.length > 50) return false;

  final lower = s.toLowerCase();
  const banned = [
    'dacă doriți', 'daca doriti', 'dacă doresti', 'daca doresti',
    'dacă vreți', 'daca vreti', 'puteți', 'puteti', 'pentru a ',
    'arome', 'aromă', 'aroma', 'texturi', 'textură', 'textura',
    'opțional', 'optional', 'sau alte', 'după gust', 'dupa gust', 'etc',
  ];
  for (final b in banned) {
    if (lower.contains(b)) return false;
  }

  // virgulă urmată de spațiu și conjuncție = frază, nu ingredient
  if (RegExp(r',\s+(dacă|daca|sau|și|si)\b').hasMatch(lower)) return false;

  // frază descriptivă lungă care nu începe cu o cantitate
  final startsWithDigit = RegExp(r'^\d').hasMatch(s);
  final wordCount = s.split(RegExp(r'\s+')).length;
  if (!startsWithDigit && wordCount > 6) return false;

  return true;
}

class WeekPlannerSheet extends ConsumerStatefulWidget {
  const WeekPlannerSheet({super.key});

  @override
  ConsumerState<WeekPlannerSheet> createState() => _WeekPlannerSheetState();
}

class _WeekPlannerSheetState extends ConsumerState<WeekPlannerSheet> {
  int _days = 7;
  int _mealsPerDay = 2;
  final _cravingController = TextEditingController();
  bool _isLoading = false;
  bool _planSaved = false;
  Map<String, dynamic>? _plan;
  String? _error;
  bool _addingToList = false;

  @override
  void dispose() {
    _cravingController.dispose();
    super.dispose();
  }

  Future<ExtractedPreferences> _loadPrefs() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return ExtractedPreferences.empty();
      final doc =
          await FirebaseFirestore.instance.doc('users/$userId').get();
      if (!doc.exists) return ExtractedPreferences.empty();
      final prefsData =
          doc.data()?['preferences'] as Map<String, dynamic>?;
      if (prefsData == null) return ExtractedPreferences.empty();
      return ExtractedPreferences.fromJson(prefsData);
    } catch (_) {
      return ExtractedPreferences.empty();
    }
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final pantryItems = ref.read(pantryProvider).valueOrNull ?? [];
      final profile = ref.read(profileProvider).valueOrNull;
      final prefs = await _loadPrefs();
      final raw = await GroqService().generateWeeklyPlan(
        pantryItems,
        days: _days,
        mealsPerDay: _mealsPerDay,
        craving: _cravingController.text.trim().isEmpty
            ? null
            : _cravingController.text.trim(),
        profile: profile,
        prefs: prefs,
      );
      final parsed = jsonDecode(raw.trim()) as Map<String, dynamic>;
      if (parsed['plan'] == null) throw Exception('Missing plan key');
      await _savePlanToFirestore(parsed['plan'] as List);
      setState(() {
        _plan = parsed;
        _planSaved = true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Eroare la generare. Încearcă din nou.';
        _isLoading = false;
      });
    }
  }

  Future<void> _savePlanToFirestore(List planList) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final thursday = now.add(Duration(days: 4 - now.weekday));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final weekNum =
        ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
    final weekId =
        'week_${thursday.year}_${weekNum.toString().padLeft(2, '0')}';
    try {
      await FirebaseFirestore.instance
          .doc('users/${user.uid}/weekly_plans/$weekId')
          .set({
        'generatedAt': FieldValue.serverTimestamp(),
        'weekId': weekId,
        'days': planList,
      });
    } catch (_) {}
  }

  Future<void> _addMissingToList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _addingToList = true);

    final repo = ShoppingListRepository();
    final days = (_plan!['plan'] as List).cast<Map<String, dynamic>>();
    final seen = <String>{};
    final toAdd = <String>[];

    for (final day in days) {
      for (final meal
          in (day['meals'] as List).cast<Map<String, dynamic>>()) {
        final missing = meal['ingredients_missing'];
        if (missing is! List) continue;
        for (final ing in missing.cast<String>()) {
          final name = ing.trim();
          if (!isMeaningfulIngredient(name)) continue;
          if (!seen.add(name.toLowerCase())) continue;
          toAdd.add(name);
        }
      }
    }

    for (final name in toAdd) {
      try {
        await repo.addItem(
          user.uid,
          ShoppingItem(
            id: '',
            name: name,
            checked: false,
            source: 'meal_plan',
            addedAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _addingToList = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _isLoading
          ? _buildLoading()
          : _planSaved
              ? _buildSuccess()
              : _plan != null
                  ? _buildResults()
                  : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    final missingCount = _countMissingIngredients();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        32,
        40,
        32,
        40 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.darkEmerald,
            size: 72,
          ),
          const SizedBox(height: 20),
          const Text(
            'Planul a fost generat!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Planul pentru $_days ${_days == 1 ? 'zi' : 'zile'} a fost salvat.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (missingCount > 0) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _addingToList ? null : _addMissingToList,
                icon: _addingToList
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.shopping_cart_outlined),
                label: Text(
                  'Adaugă $missingCount ingrediente lipsă în coș',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _addingToList
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Închide',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text(
                    'Vezi planul',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkEmerald,
                    side: const BorderSide(
                        color: AppColors.darkEmerald, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _addingToList
                      ? null
                      : () {
                          ref.read(selectedRecipesTabProvider.notifier).state =
                              1;
                          Navigator.of(context).pop();
                          context.go('/recipes');
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _countMissingIngredients() {
    if (_plan == null) return 0;
    final days = (_plan!['plan'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final seen = <String>{};
    for (final day in days) {
      final meals = (day['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final meal in meals) {
        final missing = meal['ingredients_missing'];
        if (missing is! List) continue;
        for (final ing in missing.cast<String>()) {
          final name = ing.trim();
          if (!isMeaningfulIngredient(name)) continue;
          seen.add(name.toLowerCase());
        }
      }
    }
    return seen.length;
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '📅 Planifică săptămâna',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'Număr de zile',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _ToggleGroup(
            options: const [3, 5, 7],
            labels: const ['3 zile', '5 zile', '7 zile'],
            selected: _days,
            onSelected: (v) => setState(() => _days = v),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mese pe zi',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _ToggleGroup(
            options: const [1, 2, 3],
            labels: const ['1 masă', '2 mese', '3 mese'],
            selected: _mealsPerDay,
            onSelected: (v) => setState(() => _mealsPerDay = v),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ce ai poftă? (opțional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cravingController,
            decoration: InputDecoration(
              hintText: 'ex: ceva rapid, paste, fără carne...',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                  color: AppColors.expiredRed, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Generează',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Frigo AI generează planul...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final days =
        (_plan!['plan'] as List).cast<Map<String, dynamic>>();
    final allMissing = <String>{};
    for (final day in days) {
      for (final meal
          in (day['meals'] as List).cast<Map<String, dynamic>>()) {
        final m = meal['ingredients_missing'];
        if (m is List) {
          allMissing.addAll(m.cast<String>().where(isMeaningfulIngredient));
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Planul tău pentru $_days ${_days == 1 ? 'zi' : 'zile'}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: days.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) {
              final day = days[i];
              final meals = (day['meals'] as List)
                  .cast<Map<String, dynamic>>();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📅 ${day['day']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    ...meals.map((meal) {
                      final available =
                          (meal['ingredients_available'] as List?)
                                  ?.cast<String>() ??
                              [];
                      final missing =
                          (meal['ingredients_missing'] as List?)
                                  ?.cast<String>()
                                  .where(isMeaningfulIngredient)
                                  .toList() ??
                              [];
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: 8, left: 8),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🍽️ ${meal['name']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            if (available.isNotEmpty)
                              Text(
                                '✓ ${available.join(', ')}',
                                style: const TextStyle(
                                    color: AppColors.freshGreen,
                                    fontSize: 12),
                              ),
                            if (missing.isNotEmpty)
                              Text(
                                '🛒 Lipsă: ${missing.join(', ')}',
                                style: const TextStyle(
                                    color: AppColors.useSoonYellow,
                                    fontSize: 12),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        if (allMissing.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _addingToList ? null : _addMissingToList,
                icon: _addingToList
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.shopping_cart_outlined),
                label: Text(
                  'Adaugă ${allMissing.length} ingrediente lipsă în coș',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        if (allMissing.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: const Text(
              '✓ Toate ingredientele sunt disponibile în pantry!',
              style: TextStyle(
                  color: AppColors.freshGreen,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _ToggleGroup extends StatelessWidget {
  final List<int> options;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const _ToggleGroup({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == selected;
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelected(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
