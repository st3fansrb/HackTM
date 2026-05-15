import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/preferences_provider.dart';
import '../../../shared/widgets/frigo_header.dart';
import '../domain/user_preferences.dart';

const _allergyOptions = [
  'Lactate', 'Gluten', 'Ouă', 'Nuci', 'Pește', 'Soia', 'Fructe de mare',
];

const _dietaryOptions = [
  'Vegetarian', 'Vegan', 'Fără porc', 'Fără carne roșie', 'Post ortodox',
];

const _cuisineOptions = [
  'Românească', 'Mediteraneană', 'Asiatică', 'Italiană', 'Mexicană', 'Franceză',
];

class PreferencesScreen extends ConsumerStatefulWidget {
  final bool showOnboardingBanner;
  const PreferencesScreen({super.key, this.showOnboardingBanner = false});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  List<String> _allergies = [];
  List<String> _dietary = [];
  List<String> _disliked = [];
  List<String> _cuisines = [];
  bool _saving = false;
  bool _loaded = false;

  final _dislikedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromProvider());
  }

  void _syncFromProvider() {
    final prefs = ref.read(userPreferencesProvider).valueOrNull;
    if (prefs != null && !_loaded) {
      setState(() {
        _allergies = List.from(prefs.allergies);
        _dietary = List.from(prefs.dietaryRestrictions);
        _disliked = List.from(prefs.dislikedIngredients);
        _cuisines = List.from(prefs.preferredCuisines);
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _dislikedController.dispose();
    super.dispose();
  }

  void _toggle(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  void _addDisliked() {
    final val = _dislikedController.text.trim();
    if (val.isEmpty || _disliked.contains(val)) return;
    setState(() => _disliked.add(val));
    _dislikedController.clear();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = UserPreferences(
        allergies: _allergies,
        dietaryRestrictions: _dietary,
        dislikedIngredients: _disliked,
        preferredCuisines: _cuisines,
        completedOnboarding: true,
      );
      await ref.read(preferencesNotifierProvider.notifier).savePreferences(prefs);
      if (!mounted) return;
      if (widget.showOnboardingBanner) {
        context.go('/pantry');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferințe salvate!')),
        );
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eroare la salvare. Încearcă din nou.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userPreferencesProvider, (_, next) {
      next.whenData((prefs) {
        if (!_loaded) {
          setState(() {
            _allergies = List.from(prefs.allergies);
            _dietary = List.from(prefs.dietaryRestrictions);
            _disliked = List.from(prefs.dislikedIngredients);
            _cuisines = List.from(prefs.preferredCuisines);
            _loaded = true;
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: FrigoHeader(title: 'Preferințe alimentare'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showOnboardingBanner) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkEmerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.darkEmerald.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Spune-ne despre tine pentru recomandări personalizate',
                  style: TextStyle(
                    color: AppColors.darkEmerald,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _Section(
              title: 'Alergii',
              child: _ChipGroup(
                options: _allergyOptions,
                selected: _allergies,
                onToggle: (v) => _toggle(_allergies, v),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Restricții dietetice',
              child: _ChipGroup(
                options: _dietaryOptions,
                selected: _dietary,
                onToggle: (v) => _toggle(_dietary, v),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Ingrediente evitate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dislikedController,
                          decoration: InputDecoration(
                            hintText: 'Adaugă ingredient...',
                            hintStyle: const TextStyle(
                                color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          onSubmitted: (_) => _addDisliked(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addDisliked,
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.primary),
                        iconSize: 32,
                      ),
                    ],
                  ),
                  if (_disliked.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _disliked
                          .map((item) => Chip(
                                label: Text(item),
                                onDeleted: () =>
                                    setState(() => _disliked.remove(item)),
                                backgroundColor:
                                    AppColors.expiredRed.withValues(alpha: 0.1),
                                side: BorderSide(
                                    color: AppColors.expiredRed
                                        .withValues(alpha: 0.4)),
                                labelStyle: const TextStyle(
                                    color: AppColors.expiredRed, fontSize: 13),
                                deleteIconColor: AppColors.expiredRed,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Bucătării preferate',
              child: _ChipGroup(
                options: _cuisineOptions,
                selected: _cuisines,
                onToggle: (v) => _toggle(_cuisines, v),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkEmerald,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Salvează preferințele',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final void Function(String) onToggle;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => onToggle(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected
                  ? AppColors.darkEmerald
                  : Colors.transparent,
              border: Border.all(
                color:
                    isSelected ? AppColors.darkEmerald : AppColors.divider,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
