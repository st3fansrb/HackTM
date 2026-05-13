import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/condiments_picker.dart';
import '../data/auth_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

@immutable
class _OnboardingState {
  final bool isLoading;
  final String? error;
  final int householdSize;
  final Set<String> selectedPrefs;

  const _OnboardingState({
    this.isLoading = false,
    this.error,
    this.householdSize = 2,
    this.selectedPrefs = const {},
  });

  _OnboardingState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? householdSize,
    Set<String>? selectedPrefs,
  }) =>
      _OnboardingState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        householdSize: householdSize ?? this.householdSize,
        selectedPrefs: selectedPrefs ?? this.selectedPrefs,
      );
}

class _OnboardingNotifier extends StateNotifier<_OnboardingState> {
  _OnboardingNotifier(this._repo) : super(const _OnboardingState());
  final AuthRepository _repo;

  void setSize(int size) => state = state.copyWith(householdSize: size, clearError: true);

  void togglePref(String id) {
    final prefs = {...state.selectedPrefs};
    prefs.contains(id) ? prefs.remove(id) : prefs.add(id);
    state = state.copyWith(selectedPrefs: prefs);
  }

  Future<bool> save({List<String> condiments = const []}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dietType = state.selectedPrefs.contains('vegan')
          ? 'vegan'
          : state.selectedPrefs.contains('vegetarian')
              ? 'vegetarian'
              : 'omnivor';
      await _repo.saveUserProfile(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        householdSize: state.householdSize,
        dietaryPreferences: state.selectedPrefs.toList(),
        dietType: dietType,
        ownedCondiments: condiments,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Nu am putut salva profilul. Încearcă din nou.',
      );
      return false;
    }
  }
}

final _onboardingProvider =
    StateNotifierProvider.autoDispose<_OnboardingNotifier, _OnboardingState>(
  (ref) => _OnboardingNotifier(ref.watch(authRepositoryProvider)),
);

// ─── Screen ──────────────────────────────────────────────────────────────────

const _dietaryOptions = [
  ('vegetarian', 'Vegetarian', '🥗'),
  ('vegan', 'Vegan', '🌱'),
  ('fara_gluten', 'Fără gluten', '🌾'),
  ('fara_lactoza', 'Fără lactoză', '🥛'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  List<String> _selectedCondiments = [];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_onboardingProvider);
    final notifier = ref.read(_onboardingProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const Text('🏠',
                                  style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 12),
                              Text(
                                'Bine ai venit la Frigo!',
                                style: theme.textTheme.headlineMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Câteva informații pentru a personaliza\nexperiența ta',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Household size
                        Text(
                          'Câți oameni sunt în gospodărie?',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (i) => _SizeChip(
                              number: i + 1,
                              selected: state.householdSize == i + 1,
                              onTap: () => notifier.setSize(i + 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Dietary preferences
                        Text(
                          'Preferințe alimentare',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Opțional — te ajutăm să găsești rețete potrivite',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(
                          _dietaryOptions.length,
                          (i) {
                            final (id, label, emoji) = _dietaryOptions[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PrefTile(
                                id: id,
                                label: label,
                                emoji: emoji,
                                selected: state.selectedPrefs.contains(id),
                                onTap: () => notifier.togglePref(id),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 36),

                        // Condiments
                        Text(
                          'Ce condimente ai deja acasă?',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Le vom exclude automat din lista de cumpărături',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        CondimentsPicker(
                          selected: _selectedCondiments,
                          onChanged: (val) =>
                              setState(() => _selectedCondiments = val),
                        ),

                        if (state.error != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBox(state.error!),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // CTA button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              final ok = await notifier.save(
                                condiments: _selectedCondiments,
                              );
                              if (ok && context.mounted) {
                                context.go('/pantry');
                              }
                            },
                      child: state.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Salvează și continuă →',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoading) const ModalBarrier(color: Colors.black12),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SizeChip extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha:0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final String id;
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _PrefTile({
    required this.id,
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 2 : 1,
        ),
        color: selected
            ? AppColors.primary.withValues(alpha:0.06)
            : AppColors.surface,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  key: ValueKey(selected),
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expiredRed.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expiredRed.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.expiredRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.expiredRed),
            ),
          ),
        ],
      ),
    );
  }
}
