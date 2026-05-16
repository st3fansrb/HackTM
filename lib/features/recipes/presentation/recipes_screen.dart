import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/meal_planner/presentation/meal_plan_screen.dart';
import '../../../features/pantry/domain/food_item.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/recipe_provider.dart';
import '../data/demo_recipes.dart';
import '../domain/recipe.dart';

// 0 = Toate | 1 = Favorite | 2 = Posibile azi | 3 = Din AI
final _recipeFilterProvider = StateProvider<int>((_) => 0);
final _searchProvider = StateProvider.autoDispose<String>((_) => '');
final _editModeProvider = StateProvider.autoDispose<bool>((_) => false);
final _selectedIdsProvider =
    StateProvider.autoDispose<Set<String>>((_) => {});

bool _canCookToday(Recipe recipe, List<FoodItem> pantry) {
  if (recipe.ingredients.isEmpty) return false;
  return recipe.ingredients.every((ingredient) {
    final name = ingredient.name.toLowerCase().trim();
    return pantry.any((item) {
      final pantryName = item.name.toLowerCase().trim();
      return pantryName.contains(name) || name.contains(pantryName);
    });
  });
}

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(selectedRecipesTabProvider);
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exitEditMode() {
    ref.read(_editModeProvider.notifier).state = false;
    ref.read(_selectedIdsProvider.notifier).state = {};
  }

  Future<void> _confirmBulkDelete(
      BuildContext context, Set<String> ids) async {
    final count = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ștergi $count ${count == 1 ? 'rețetă' : 'rețete'}?'),
        content: const Text('Această acțiune nu poate fi anulată.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Șterge',
                style: TextStyle(color: AppColors.expiredRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final repo = ref.read(recipeRepositoryProvider);
    for (final id in ids) {
      try {
        await repo.deleteRecipe(uid, id);
      } catch (_) {}
    }
    _exitEditMode();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeProvider);
    final editMode = ref.watch(_editModeProvider);
    final selectedIds = ref.watch(_selectedIdsProvider);
    final currentTab = _tabController.index;

    ref.listen<int>(selectedRecipesTabProvider, (_, next) {
      if (_tabController.index != next) _tabController.animateTo(next);
    });

    final subtitleText = recipesAsync.maybeWhen(
      data: (list) => '${list.length} rețete salvate',
      orElse: () => 'Se încarcă...',
    );

    final Widget titleWidget;
    if (editMode && currentTab == 0) {
      titleWidget = Text(
        '${selectedIds.length} selectate',
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white),
      );
    } else if (currentTab == 0) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍽️ Rețete',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Colors.white)),
          Text(subtitleText,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
        ],
      );
    } else {
      titleWidget = const Text('📅 Planul săptămânii',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white));
    }

    final List<Widget> appBarActions;
    if (editMode && currentTab == 0) {
      appBarActions = [
        if (selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Șterge selectate',
            onPressed: () => _confirmBulkDelete(context, selectedIds),
          ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Ieși din editare',
          onPressed: _exitEditMode,
        ),
      ];
    } else if (currentTab == 0) {
      appBarActions = [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: 'Mod editare',
          onPressed: () =>
              ref.read(_editModeProvider.notifier).state = true,
        ),
      ];
    } else {
      appBarActions = [];
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.darkTeal, AppColors.darkEmerald],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: titleWidget,
        actions: appBarActions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.darkEmerald,
              labelColor: AppColors.darkEmerald,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(
                  icon: Icon(Icons.menu_book_outlined),
                  text: 'Rețete',
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_outlined),
                  text: 'Plan',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RecipesTab(),
          MealPlanContent(),
        ],
      ),
    );
  }
}

// ─── Recipes Tab ──────────────────────────────────────────────────────────────

class _RecipesTab extends ConsumerStatefulWidget {
  const _RecipesTab();

  @override
  ConsumerState<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<_RecipesTab> {
  bool _seeded = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _autoSeed(List<Recipe> recipes) async {
    if (_seeded || recipes.isNotEmpty) return;
    _seeded = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final repo = ref.read(recipeRepositoryProvider);
    for (final recipe in kDemoRecipes) {
      try {
        await repo.addRecipe(uid, recipe);
      } catch (_) {}
    }
  }

  void _toggleSelect(String id) {
    final current = Set<String>.from(ref.read(_selectedIdsProvider));
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    ref.read(_selectedIdsProvider.notifier).state = current;
  }

  Future<void> _swipeDelete(BuildContext context, Recipe recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final repo = ref.read(recipeRepositoryProvider);
    try {
      await repo.deleteRecipe(uid, recipe.id);
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Rețetă ștearsă'),
        backgroundColor: AppColors.darkTeal,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Anulează',
          textColor: AppColors.fawn,
          onPressed: () async {
            try {
              await repo.addRecipe(uid, recipe);
            } catch (_) {}
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeProvider);
    final pantry = ref.watch(pantryProvider).valueOrNull ?? [];
    final filter = ref.watch(_recipeFilterProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final searchText = ref.watch(_searchProvider);
    final editMode = ref.watch(_editModeProvider);
    final selectedIds = ref.watch(_selectedIdsProvider);

    ref.listen<AsyncValue<List<Recipe>>>(recipeProvider, (_, next) {
      next.whenData(_autoSeed);
    });

    return recipesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Nu s-au putut încărca rețetele',
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
      data: (recipes) {
        var filtered = switch (filter) {
          0 => recipes,
          1 => recipes.where((r) => r.isFavorite).toList(),
          2 => recipes.where((r) => _canCookToday(r, pantry)).toList(),
          3 => recipes.where((r) => r.source == 'ai').toList(),
          _ => recipes,
        };

        bool profileFilterActive = false;
        if (profile != null) {
          final diet = profile.dietType.toLowerCase();
          if (diet == 'vegetarian' || diet == 'vegan') {
            profileFilterActive = true;
            filtered = filtered.where((r) {
              final tags = r.dietaryTags.map((t) => t.toLowerCase());
              return !tags
                  .any((t) => t.contains('carne') || t.contains('peste'));
            }).toList();
          }
          final hasGluten =
              profile.allergies.any((a) => a.toLowerCase() == 'gluten');
          if (hasGluten) {
            profileFilterActive = true;
            filtered = filtered.where((r) {
              final tags = r.dietaryTags.map((t) => t.toLowerCase());
              return tags.any((t) =>
                  t.contains('fara_gluten') || t.contains('fără gluten'));
            }).toList();
          }
        }

        if (searchText.isNotEmpty) {
          final q = searchText.toLowerCase();
          filtered =
              filtered.where((r) => r.name.toLowerCase().contains(q)).toList();
        }

        return Column(
          children: [
            _FilterRow(selected: filter, ref: ref),
            if (!editMode)
              _SearchField(
                controller: _searchController,
                ref: ref,
                searchText: searchText,
              ),
            if (profileFilterActive && profile != null)
              _ProfileFilterBanner(dietType: profile.dietType),
            if (filtered.isEmpty)
              const Expanded(child: _EmptyState())
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final recipe = filtered[i];
                    final isSelected = selectedIds.contains(recipe.id);
                    return Dismissible(
                      key: ValueKey(recipe.id),
                      direction: editMode
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      background: const SizedBox.shrink(),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.expiredRed,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 28),
                      ),
                      onDismissed: (_) => _swipeDelete(ctx, recipe),
                      child: RecipeCard(
                        recipe: recipe,
                        isEditMode: editMode,
                        isSelected: isSelected,
                        onToggleSelect: () => _toggleSelect(recipe.id),
                        onCook: () => ctx.push('/recipes/${recipe.id}'),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Search Field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final WidgetRef ref;
  final String searchText;

  const _SearchField({
    required this.controller,
    required this.ref,
    required this.searchText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Caută rețetă...',
          hintStyle:
              const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          suffixIcon: searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    controller.clear();
                    ref.read(_searchProvider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.bg,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkTeal),
          ),
        ),
      ),
    );
  }
}

// ─── Filter Row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final int selected;
  final WidgetRef ref;

  const _FilterRow({required this.selected, required this.ref});

  @override
  Widget build(BuildContext context) {
    const options = ['🍽️ Toate', '❤️ Favorite', '✅ Posibile azi', '✨ Din AI'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(options.length, (i) {
            final isSelected = selected == i;
            return Padding(
              padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              child: ChoiceChip(
                label: Text(
                  options[i],
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) =>
                    ref.read(_recipeFilterProvider.notifier).state = i,
                selectedColor: AppColors.darkTeal,
                backgroundColor: AppColors.bg,
                side: BorderSide(
                  color: isSelected ? AppColors.darkTeal : AppColors.divider,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── RecipeCard ───────────────────────────────────────────────────────────────

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onCook;
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onCook,
    this.isEditMode = false,
    this.isSelected = false,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppColors.darkTeal.withValues(alpha: 0.08) : null,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.darkTeal, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: isEditMode ? onToggleSelect : onCook,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEditMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelect(),
                      activeColor: AppColors.darkTeal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (recipe.source == 'ai') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.jungle.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppColors.jungle.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              '✨ AI',
                              style: TextStyle(
                                color: AppColors.darkEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (!isEditMode) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textMuted, size: 20),
                        ],
                      ],
                    ),
                    if (recipe.dietaryTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: recipe.dietaryTags
                            .map((t) => _DietTag(tag: t))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${recipe.prepTime} min',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(width: 14),
                        const Icon(Icons.restaurant_menu_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${recipe.ingredients.length} ingrediente',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(width: 14),
                        const Icon(Icons.people_outline,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${recipe.servings} porții',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Diet Tag chip ────────────────────────────────────────────────────────────

class _DietTag extends StatelessWidget {
  final String tag;
  const _DietTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.fawnLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.fawn.withValues(alpha: 0.4)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: AppColors.darkTeal,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Profile Filter Banner ────────────────────────────────────────────────────

class _ProfileFilterBanner extends StatelessWidget {
  final String dietType;
  const _ProfileFilterBanner({required this.dietType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.fawnLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          const Icon(Icons.tune_outlined, size: 14, color: AppColors.darkTeal),
          const SizedBox(width: 6),
          Text(
            'Filtrăm după preferințele tale • $dietType',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkTeal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(
              'Nicio rețetă salvată încă',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Întreabă Frigo AI să-ți sugereze ceva!',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
