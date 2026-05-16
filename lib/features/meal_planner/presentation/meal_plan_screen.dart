import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/meal_plan_provider.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/widgets/frigo_header.dart';
import '../domain/weekly_plan.dart';
import 'week_planner_sheet.dart';

const _dayNames = [
  'Luni',
  'Marți',
  'Miercuri',
  'Joi',
  'Vineri',
  'Sâmbătă',
  'Duminică',
];

class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  String get _todayName => _dayNames[DateTime.now().weekday - 1];

  void _showPlannerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => const WeekPlannerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);

    return planAsync.when(
      loading: () => Scaffold(
        appBar: FrigoHeader(title: '📅 Planul săptămânii'),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: FrigoHeader(title: '📅 Planul săptămânii'),
        body: const Center(child: Text('Eroare la încărcarea planului.')),
      ),
      data: (plan) => Scaffold(
        appBar: FrigoHeader(
          title: '📅 Planul săptămânii',
          subtitle: plan == null
              ? null
              : 'Generat pentru ${plan.days.length} zile',
          actions: plan != null
              ? [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Regenerează',
                    onPressed: () => _showPlannerSheet(context),
                  ),
                ]
              : null,
        ),
        body: plan == null
            ? _EmptyState(onGenerate: () => _showPlannerSheet(context))
            : _PlanBody(plan: plan, todayName: _todayName),
        floatingActionButton: plan == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showPlannerSheet(context),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.calendar_month),
                label: const Text(
                  'Plan nou',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
      ),
    );
  }
}

// ─── Plan body ────────────────────────────────────────────────────────────────

class _PlanBody extends StatelessWidget {
  final WeeklyPlan plan;
  final String todayName;

  const _PlanBody({required this.plan, required this.todayName});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: plan.days.length,
      itemBuilder: (_, i) {
        final day = plan.days[i];
        final isToday = day.day == todayName;
        return _DayCard(day: day, isToday: isToday, dayIndex: i);
      },
    );
  }
}

// ─── Day card ─────────────────────────────────────────────────────────────────

class _DayCard extends ConsumerStatefulWidget {
  final MealDay day;
  final bool isToday;
  final int dayIndex;

  const _DayCard({
    required this.day,
    required this.isToday,
    required this.dayIndex,
  });

  @override
  ConsumerState<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<_DayCard> {
  bool _regenerating = false;

  MealDay get day => widget.day;
  bool get isToday => widget.isToday;

  Future<void> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Înlocuiește rețeta'),
        content: Text(
          'Înlocuiești rețeta de ${day.day}? AI-ul va sugera o alternativă.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Înlocuiește',
              style: TextStyle(color: AppColors.darkEmerald),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _regenerating = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final pantry = ref.read(pantryProvider).valueOrNull ?? [];
      final profile = ref.read(profileProvider).valueOrNull;

      await regenerateSingleMeal(
        uid: uid,
        weekId: currentWeekId(),
        dayIndex: widget.dayIndex,
        pantryItems: pantry,
        profile: profile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rețetă înlocuită!'),
            backgroundColor: AppColors.darkEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la regenerare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Column(
              children: [
                // day header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.background,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color:
                            isToday ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        day.day,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color:
                              isToday ? AppColors.primary : AppColors.text,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AZI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      _regenerating
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh_outlined,
                                  size: 20),
                              color: AppColors.textMuted,
                              tooltip: 'Înlocuiește rețeta',
                              onPressed: _confirmRegenerate,
                            ),
                    ],
                  ),
                ),
                // meals
                ...day.meals.asMap().entries.map((e) {
                  final index = e.key;
                  final meal = e.value;
                  return _MealTile(
                    meal: meal,
                    mealIndex: index,
                    mealsCount: day.meals.length,
                  );
                }),
              ],
            ),
            if (_regenerating)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.surface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal tile (tappable → detail) ────────────────────────────────────────────

class _MealTile extends StatelessWidget {
  final MealRecipe meal;
  final int mealIndex;
  final int mealsCount;

  const _MealTile({
    required this.meal,
    required this.mealIndex,
    required this.mealsCount,
  });

  String get _mealLabel {
    if (mealsCount == 1) return 'Masă principală';
    if (mealsCount == 2) return mealIndex == 0 ? 'Prânz' : 'Cină';
    const labels = ['Mic dejun', 'Prânz', 'Cină'];
    return mealIndex < labels.length ? labels[mealIndex] : 'Masă';
  }

  @override
  Widget build(BuildContext context) {
    final missing = meal.ingredientsMissing;

    return InkWell(
      onTap: () => context.push('/meal-plan/recipe', extra: meal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mealLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    meal.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🛒 Lipsă: ${missing.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.useSoonYellow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Embeddable content (fără Scaffold, pentru tab în RecipesScreen) ─────────

class MealPlanContent extends ConsumerWidget {
  const MealPlanContent({super.key});

  String get _todayName => _dayNames[DateTime.now().weekday - 1];

  void _showPlannerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => const WeekPlannerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weeklyPlanProvider);
    return planAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) =>
          const Center(child: Text('Eroare la încărcarea planului.')),
      data: (plan) => Stack(
        children: [
          plan == null
              ? _EmptyState(onGenerate: () => _showPlannerSheet(context))
              : _PlanBody(plan: plan, todayName: _todayName),
          if (plan != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _showPlannerSheet(context),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.calendar_month),
                label: const Text(
                  'Plan nou',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyState({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(
              'Niciun plan pentru\naceastă săptămână',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Generează un plan bazat pe\nprodusele din frigider.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text(
                'Generează plan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
