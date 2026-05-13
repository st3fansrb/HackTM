import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/shopping_list/data/shopping_list_repository.dart';
import '../../../features/shopping_list/domain/shopping_item.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../data/groq_service.dart';
import '../data/preferences_extractor.dart';

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
      setState(() {
        _plan = parsed;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Eroare la generare. Încearcă din nou.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addMissingToList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _addingToList = true);
    final repo = ShoppingListRepository();
    final days =
        (_plan!['plan'] as List).cast<Map<String, dynamic>>();
    final missing = <String>{};
    for (final day in days) {
      for (final meal
          in (day['meals'] as List).cast<Map<String, dynamic>>()) {
        final m = meal['ingredients_missing'];
        if (m is List) missing.addAll(m.cast<String>());
      }
    }
    for (final name in missing) {
      try {
        await repo.addItem(
          user.uid,
          ShoppingItem(
            id: '',
            name: name.trim(),
            checked: false,
            source: 'meal_plan',
            addedAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
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
          : _plan != null
              ? _buildResults()
              : _buildForm(),
    );
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
        if (m is List) allMissing.addAll(m.cast<String>());
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
                                  ?.cast<String>() ??
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
