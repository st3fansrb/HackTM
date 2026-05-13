import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/pantry/domain/food_item.dart';
import '../../../features/shopping_list/domain/shopping_item.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/recipe_provider.dart';
import '../../../shared/providers/shopping_list_provider.dart';
import '../domain/recipe.dart';

final _cookingLoadingProvider = StateProvider.autoDispose<bool>((_) => false);
final _cookedLoadingProvider = StateProvider.autoDispose<bool>((_) => false);
final _cookedDoneProvider = StateProvider.autoDispose<bool>((_) => false);


class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipeProvider).valueOrNull ?? [];
    final recipe = recipes.cast<Recipe?>().firstWhere(
          (r) => r?.id == recipeId,
          orElse: () => null,
        );

    if (recipe == null) {
      return Scaffold(
        appBar: _gradientAppBar(context, 'Rețetă', null, ref),
        body: const Center(
          child: Text('Rețeta nu a fost găsită.'),
        ),
      );
    }

    return Scaffold(
      appBar: _gradientAppBar(context, recipe.name, recipe, ref),
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags + meta
                  if (recipe.dietaryTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: recipe.dietaryTags
                          .map((t) => _DietTag(tag: t))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MetaRow(recipe: recipe),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  // Ingrediente
                  _SectionTitle(title: 'Ingrediente', icon: Icons.kitchen_outlined),
                  const SizedBox(height: 10),
                  ...recipe.ingredients.map((ing) => _IngredientRow(ingredient: ing)),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  // Pași
                  _SectionTitle(title: 'Mod de preparare', icon: Icons.format_list_numbered_outlined),
                  const SizedBox(height: 10),
                  ...recipe.steps.asMap().entries.map(
                        (e) => _StepRow(index: e.key + 1, step: e.value),
                      ),
                ],
              ),
            ),
          ),
          _BottomButtons(recipe: recipe),
        ],
      ),
    );
  }

  PreferredSizeWidget _gradientAppBar(
    BuildContext context,
    String title,
    Recipe? recipe,
    WidgetRef ref,
  ) {
    return AppBar(
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (recipe != null) ...[
          IconButton(
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? Colors.red.shade300 : Colors.white,
            ),
            tooltip: recipe.isFavorite
                ? 'Elimină din favorite'
                : 'Adaugă la favorite',
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              await ref
                  .read(recipeRepositoryProvider)
                  .toggleFavorite(uid, recipe.id, !recipe.isFavorite);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Șterge rețeta',
            onPressed: () => _confirmDelete(context, ref, recipe),
          ),
        ],
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Recipe recipe) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge rețeta?'),
        content: Text('„${recipe.name}" va fi eliminată definitiv.'),
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
    ).then((confirmed) async {
      if (confirmed != true) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await ref.read(recipeRepositoryProvider).deleteRecipe(uid, recipe.id);
      if (context.mounted) context.pop();
    });
  }
}

// ─── Cook Button (cu logica Gătește asta) ─────────────────────────────────────

class _CookButton extends ConsumerWidget {
  final Recipe recipe;
  const _CookButton({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(_cookingLoadingProvider);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _cook(context, ref),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.darkTeal.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Text(
                '🛒 Gătește asta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Future<void> _cook(BuildContext context, WidgetRef ref) async {
    ref.read(_cookingLoadingProvider.notifier).state = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final pantry = ref.read(pantryProvider).valueOrNull ?? [];
      final profile = ref.read(profileProvider).valueOrNull;
      final owned = profile?.ownedCondiments ?? [];
      final shoppingRepo = ref.read(shoppingListRepositoryProvider);

      final missing = <RecipeIngredient>[];
      for (final ingredient in recipe.ingredients) {
        final nameLower = ingredient.name.toLowerCase().trim();

        final isOwned = owned.any((c) =>
            c.toLowerCase().contains(nameLower) ||
            nameLower.contains(c.toLowerCase()));
        if (isOwned) continue;

        final inPantry = pantry.any((item) {
          final pantryName = item.name.toLowerCase().trim();
          return pantryName.contains(nameLower) ||
              nameLower.contains(pantryName);
        });
        if (inPantry) continue;

        missing.add(ingredient);
      }

      for (final ingredient in missing) {
        await shoppingRepo.addItem(
          uid,
          ShoppingItem(
            id: '',
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            checked: false,
            source: 'ai',
            addedAt: DateTime.now(),
          ),
        );
      }

      if (context.mounted) {
        final msg = missing.isEmpty
            ? 'Ai tot ce îți trebuie! Poftă bună 🎉'
            : '${missing.length} ingredient${missing.length == 1 ? '' : 'e'} '
                'adăugate în lista de cumpărături';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor:
                missing.isEmpty ? AppColors.darkEmerald : AppColors.darkTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      ref.read(_cookingLoadingProvider.notifier).state = false;
    }
  }
}

// ─── Bottom buttons container ─────────────────────────────────────────────────

class _BottomButtons extends StatelessWidget {
  final Recipe recipe;
  const _BottomButtons({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CookButton(recipe: recipe),
          const SizedBox(height: 10),
          _CookedButton(recipe: recipe),
        ],
      ),
    );
  }
}

// ─── Cooked button ────────────────────────────────────────────────────────────

class _CookedButton extends ConsumerWidget {
  final Recipe recipe;
  const _CookedButton({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = ref.watch(_cookedDoneProvider);
    final isLoading = ref.watch(_cookedLoadingProvider);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (isLoading || isDone) ? null : () => _confirmAndCook(context, ref),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.jungle,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDone
              ? Colors.grey.shade300
              : AppColors.jungle.withValues(alpha: 0.5),
          disabledForegroundColor: isDone
              ? Colors.grey.shade600
              : Colors.white.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                isDone ? 'Gătit azi ✓' : 'Am gătit ✓',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Future<void> _confirmAndCook(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ai gătit ${recipe.name}?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingrediente necesare:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...recipe.ingredients.map((ing) {
                  final qty = ing.quantity == ing.quantity.truncateToDouble()
                      ? ing.quantity.toInt().toString()
                      : ing.quantity.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $qty ${ing.unit} ${ing.name}'),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Confirmă',
              style: TextStyle(color: AppColors.darkEmerald),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ref.read(_cookedLoadingProvider.notifier).state = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final pantry = ref.read(pantryProvider).valueOrNull ?? [];
      final pantryRepo = ref.read(pantryRepositoryProvider);
      final shoppingRepo = ref.read(shoppingListRepositoryProvider);
      final lowItems = <MapEntry<FoodItem, double>>[];

      for (final ingredient in recipe.ingredients) {
        final nameLower = ingredient.name.toLowerCase().trim();

        FoodItem? pantryItem;
        for (final item in pantry) {
          final pantryName = item.name.toLowerCase().trim();
          if (pantryName.contains(nameLower) ||
              nameLower.contains(pantryName)) {
            pantryItem = item;
            break;
          }
        }
        if (pantryItem == null) continue;

        final newQty = pantryItem.quantity - ingredient.quantity;
        if (newQty <= 0.1) {
          await pantryRepo.deleteItemWithTracking(uid, pantryItem, true);
        } else {
          await pantryRepo.updateItemQuantity(uid, pantryItem.id, newQty);
          if (newQty < pantryItem.quantity * 0.2) {
            lowItems.add(MapEntry(pantryItem, newQty));
          }
        }
      }

      await ref
          .read(recipeRepositoryProvider)
          .saveCookedRecipe(uid, recipe);
      ref.read(_cookedDoneProvider.notifier).state = true;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Poftă bună! Pantry-ul a fost actualizat.'),
            backgroundColor: AppColors.darkEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );

        for (final entry in lowItems) {
          if (!context.mounted) break;
          final item = entry.key;
          final qty = entry.value;
          final qtyStr = qty == qty.truncateToDouble()
              ? qty.toInt().toString()
              : qty.toStringAsFixed(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ai mai puțin de $qtyStr ${item.unit} de ${item.name}'
                ' — adaugă în lista de cumpărături?',
              ),
              backgroundColor: AppColors.darkTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Adaugă',
                textColor: AppColors.fawn,
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  await shoppingRepo.addItem(
                    user.uid,
                    ShoppingItem(
                      id: '',
                      name: item.name,
                      unit: item.unit,
                      checked: false,
                      source: 'manual',
                      addedAt: DateTime.now(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      ref.read(_cookedLoadingProvider.notifier).state = false;
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final Recipe recipe;
  const _MetaRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetaChip(
          icon: Icons.timer_outlined,
          label: '${recipe.prepTime} min',
        ),
        const SizedBox(width: 10),
        _MetaChip(
          icon: Icons.restaurant_menu_outlined,
          label: '${recipe.ingredients.length} ingrediente',
        ),
        const SizedBox(width: 10),
        _MetaChip(
          icon: Icons.auto_awesome_outlined,
          label: recipe.source == 'ai' ? 'Generat AI' : 'Manual',
          highlight: recipe.source == 'ai',
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.jungle.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppColors.jungle.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: highlight ? AppColors.darkEmerald : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.darkEmerald : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.darkTeal),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  const _IngredientRow({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final qty = ingredient.quantity == ingredient.quantity.truncateToDouble()
        ? ingredient.quantity.toInt().toString()
        : ingredient.quantity.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.jungle,
            ),
          ),
          Expanded(
            child: Text(
              '$qty ${ingredient.unit} ${ingredient.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String step;

  const _StepRow({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 12, top: 1),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkTeal,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              step,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

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
