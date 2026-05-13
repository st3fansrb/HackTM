import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/recipes/domain/recipe.dart';
import '../../../shared/providers/chat_provider.dart';
import '../../../shared/providers/recipe_provider.dart';

class ParsedMessage extends ConsumerWidget {
  final String content;
  final bool isUser;

  const ParsedMessage({
    super.key,
    required this.content,
    required this.isUser,
  });

  List<String> _extractMissingItems(String text) {
    return text
        .split('\n')
        .where((line) => line.contains('🛒 Lipsește:'))
        .map((line) =>
            line.replaceFirst(RegExp(r'^.*🛒 Lipsește:\s*'), '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  List<TextSpan> _buildTextSpans(String text, Color textColor) {
    final parts = text.split(RegExp(r'\*\*(.+?)\*\*'));
    final boldMatches = RegExp(r'\*\*(.+?)\*\*').allMatches(text).toList();
    final spans = <TextSpan>[];
    int matchIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (matchIndex < boldMatches.length) {
        spans.add(TextSpan(
          text: boldMatches[matchIndex].group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
        matchIndex++;
      }
    }

    return spans;
  }

  bool _isShoppingPlan(String text) {
    final t = text.trim();
    return t.startsWith('{') && t.contains('"retete"');
  }

  bool _containsRecipe(String text) => text.contains('🍽️');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isUser && _isShoppingPlan(content)) {
      return _ShoppingPlanCard(content: content);
    }

    final missingItems = isUser ? <String>[] : _extractMissingItems(content);
    final hasRecipe = !isUser && _containsRecipe(content);
    final textColor = isUser ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isUser
              ? Text(
                  content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.45,
                  ),
                )
              : RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.45,
                    ),
                    children: _buildTextSpans(content, textColor),
                  ),
                ),
        ),
        if (missingItems.isNotEmpty) ...[
          const SizedBox(height: 6),
          _AddToListButton(itemNames: missingItems),
        ],
        if (hasRecipe) ...[
          const SizedBox(height: 6),
          _SaveRecipeButton(content: content),
        ],
      ],
    );
  }
}

class _ShoppingPlanCard extends ConsumerStatefulWidget {
  final String content;
  const _ShoppingPlanCard({required this.content});

  @override
  ConsumerState<_ShoppingPlanCard> createState() => _ShoppingPlanCardState();
}

class _ShoppingPlanCardState extends ConsumerState<_ShoppingPlanCard> {
  late final List<Map<String, dynamic>> _recipes;
  final Set<int> _selected = {};
  bool _added = false;

  @override
  void initState() {
    super.initState();
    try {
      final data = jsonDecode(widget.content.trim()) as Map<String, dynamic>;
      _recipes = (data['retete'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      _recipes = [];
    }
  }

  List<String> get _missingIngredients {
    final all = <String>{};
    for (final i in _selected) {
      if (i < _recipes.length) {
        final missing =
            (_recipes[i]['ingrediente_lipsa'] as List? ?? []).cast<String>();
        all.addAll(missing);
      }
    }
    return all.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_recipes.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pe baza pantry-ului tău îți sugerez:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_recipes.length, (i) {
            final recipe = _recipes[i];
            final name = recipe['nume'] as String? ?? '';
            final missing =
                (recipe['ingrediente_lipsa'] as List? ?? []).cast<String>();
            final isSelected = _selected.contains(i);

            return GestureDetector(
              onTap: _added
                  ? null
                  : () => setState(() {
                        if (isSelected) {
                          _selected.remove(i);
                        } else {
                          _selected.add(i);
                        }
                      }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      missing.isEmpty
                          ? '✓ complet din pantry'
                          : 'lipsesc: ${missing.join(', ')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: missing.isEmpty
                            ? const Color(0xFF27AE60)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selected.isEmpty || _added)
                  ? null
                  : () async {
                      final items = _missingIngredients;
                      await ref
                          .read(chatProvider.notifier)
                          .addMissingToShoppingList(items);
                      setState(() => _added = true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${items.length} ingrediente adăugate în lista de cumpărături'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.textSecondary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _added
                    ? 'Adăugate în listă ✓'
                    : 'Adaugă ingredientele lipsă →',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddToListButton extends ConsumerStatefulWidget {
  final List<String> itemNames;
  const _AddToListButton({required this.itemNames});

  @override
  ConsumerState<_AddToListButton> createState() => _AddToListButtonState();
}

class _AddToListButtonState extends ConsumerState<_AddToListButton> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _added
          ? null
          : () async {
              await ref
                  .read(chatProvider.notifier)
                  .addMissingToShoppingList(widget.itemNames);
              setState(() => _added = true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${widget.itemNames.length} produse adăugate în lista de cumpărături'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
      icon: Icon(
        _added ? Icons.check_circle_outline : Icons.shopping_cart_outlined,
        size: 18,
      ),
      label: Text(_added ? 'Adăugate în listă' : 'Adaugă în listă'),
      style: TextButton.styleFrom(
        foregroundColor: _added ? AppColors.textSecondary : AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ─── Save Recipe Button ───────────────────────────────────────────────────────

class _SaveRecipeButton extends ConsumerStatefulWidget {
  final String content;
  const _SaveRecipeButton({required this.content});

  @override
  ConsumerState<_SaveRecipeButton> createState() => _SaveRecipeButtonState();
}

class _SaveRecipeButtonState extends ConsumerState<_SaveRecipeButton> {
  bool _saved = false;

  Recipe _parseRecipe(String text) {
    final lines = text.split('\n');

    String name = '';
    int prepTime = 30;
    int servings = 4;
    final ingredients = <RecipeIngredient>[];
    final steps = <String>[];

    bool inIngredients = false;
    bool inSteps = false;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.contains('🍽️') && name.isEmpty) {
        name = line.replaceAll('🍽️', '').trim();
        inIngredients = false;
        inSteps = false;
        continue;
      }

      if (line.contains('⏱️') || line.contains('Timp:')) {
        final timeMatch = RegExp(r'(\d+)\s*minut').firstMatch(line);
        if (timeMatch != null) prepTime = int.tryParse(timeMatch.group(1)!) ?? 30;
        final portiiMatch = RegExp(r'Porții:\s*(\d+)').firstMatch(line);
        if (portiiMatch != null) servings = int.tryParse(portiiMatch.group(1)!) ?? 4;
        inIngredients = false;
        inSteps = false;
        continue;
      }

      if (line.contains('📋')) {
        inIngredients = true;
        inSteps = false;
        continue;
      }

      if (line.contains('👨‍🍳')) {
        inIngredients = false;
        inSteps = true;
        continue;
      }

      if (inIngredients && line.startsWith('-')) {
        final body = line.replaceFirst(RegExp(r'^-\s*'), '');
        final match = RegExp(r'^(\d+(?:[.,]\d+)?)\s+(\S+)\s+(.+)$').firstMatch(body);
        if (match != null) {
          final qty = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1.0;
          ingredients.add(RecipeIngredient(
            name: match.group(3)!.trim(),
            quantity: qty,
            unit: match.group(2)!.trim(),
          ));
        } else {
          ingredients.add(RecipeIngredient(name: body, quantity: 1, unit: 'buc'));
        }
        continue;
      }

      if (inSteps) {
        final stepMatch = RegExp(r'^\d+\.\s*(.+)$').firstMatch(line);
        if (stepMatch != null) steps.add(stepMatch.group(1)!.trim());
      }
    }

    return Recipe(
      id: '',
      name: name.isNotEmpty ? name : 'Rețetă AI',
      ingredients: ingredients,
      steps: steps,
      prepTime: prepTime,
      servings: servings,
      dietaryTags: const [],
      savedAt: DateTime.now(),
      source: 'ai',
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _saved
          ? null
          : () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              try {
                final recipe = _parseRecipe(widget.content);
                await ref.read(recipeRepositoryProvider).addRecipe(uid, recipe);
                setState(() => _saved = true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Rețetă salvată! Vezi în tab Rețete 🍽️'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Eroare la salvarea rețetei')),
                  );
                }
              }
            },
      icon: Icon(
        _saved ? Icons.check_circle_outline : Icons.save_outlined,
        size: 18,
      ),
      label: Text(_saved ? '✓ Salvată' : '💾 Salvează rețeta'),
      style: TextButton.styleFrom(
        foregroundColor: _saved ? AppColors.textSecondary : AppColors.darkTeal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
