import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/meal_plan_provider.dart';
import '../data/groq_service.dart';
import '../domain/weekly_plan.dart';

class MealRecipeDetailScreen extends ConsumerStatefulWidget {
  final MealRecipe recipe;

  const MealRecipeDetailScreen({super.key, required this.recipe});

  @override
  ConsumerState<MealRecipeDetailScreen> createState() =>
      _MealRecipeDetailScreenState();
}

class _MealRecipeDetailScreenState
    extends ConsumerState<MealRecipeDetailScreen> {
  bool _cooking = false;
  bool _cooked = false;

  String? _generatedInstructions;
  bool _generatingInstructions = false;
  bool _instructionsError = false;

  MealRecipe get recipe => widget.recipe;

  /// Numele ingredientelor (fără cantități) pentru promptul de generare.
  List<String> get _ingredientNames {
    if (recipe.ingredients.isNotEmpty) {
      return recipe.ingredients.map((i) => i.name).toList();
    }
    return [...recipe.ingredientsAvailable, ...recipe.ingredientsMissing];
  }

  Future<void> _generateInstructions() async {
    setState(() {
      _generatingInstructions = true;
      _instructionsError = false;
    });
    try {
      final text = await GroqService()
          .generateInstructions(recipe.name, _ingredientNames);
      if (!mounted) return;
      setState(() => _generatedInstructions = text.trim());
    } catch (_) {
      if (!mounted) return;
      setState(() => _instructionsError = true);
    } finally {
      if (mounted) setState(() => _generatingInstructions = false);
    }
  }

  /// Liniile afișate la "Ingrediente". Folosește ingredientele structurate dacă
  /// există, altfel cade înapoi pe listele disponibile/lipsă (planuri vechi).
  List<String> get _ingredientLines {
    if (recipe.ingredients.isNotEmpty) {
      return recipe.ingredients.map((i) => i.display).toList();
    }
    return [...recipe.ingredientsAvailable, ...recipe.ingredientsMissing];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _ingredientLines;

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero placeholder
                  Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.darkEmerald, AppColors.jungle],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant,
                          size: 64, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  // Ingrediente
                  const _SectionTitle(
                    title: 'Ingrediente',
                    icon: Icons.kitchen_outlined,
                  ),
                  const SizedBox(height: 10),
                  if (lines.isEmpty)
                    const Text(
                      'Fără ingrediente listate.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    ...lines.map((l) => _Bullet(text: l)),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),
                  // Mod de preparare
                  const _SectionTitle(
                    title: 'Mod de preparare',
                    icon: Icons.format_list_numbered_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildInstructions(context),
                ],
              ),
            ),
          ),
          _BottomBar(
            cooking: _cooking,
            cooked: _cooked,
            onCook: _onCooked,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    final existing = recipe.instructions.trim();
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.6,
          color: AppColors.text,
        );

    if (existing.isNotEmpty) {
      return Text(existing, style: textStyle);
    }
    if (_generatedInstructions != null) {
      return Text(_generatedInstructions!, style: textStyle);
    }
    if (_generatingInstructions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.darkEmerald,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Generez instrucțiunile...',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_instructionsError) ...[
          const Text(
            'Nu am putut genera instrucțiunile. Încearcă din nou.',
            style: TextStyle(color: AppColors.expiredRed),
          ),
          const SizedBox(height: 10),
        ],
        ElevatedButton.icon(
          onPressed: _generateInstructions,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generează instrucțiuni'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkEmerald,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _onCooked() async {
    setState(() => _cooking = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final db = FirebaseFirestore.instance;
      final weekId = currentWeekId();

      final ingredientsPayload = recipe.ingredients.isNotEmpty
          ? recipe.ingredients.map((i) => i.toJson()).toList()
          : [...recipe.ingredientsAvailable, ...recipe.ingredientsMissing]
              .map((n) => {'name': n})
              .toList();

      await db.collection('users/$uid/cooking_history').add({
        'recipeName': recipe.name,
        'cookedAt': FieldValue.serverTimestamp(),
        'ingredients': ingredientsPayload,
        'weekId': weekId,
      });

      await db.doc('users/$uid').set(
        {'totalMealsCoooked': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _cooked = true);
      await _showSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cooking = false);
    }
  }

  Future<void> _showSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration,
                size: 64, color: AppColors.darkEmerald),
            const SizedBox(height: 16),
            const Text(
              'Poftă bună! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ai gătit ${recipe.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (context.mounted) context.pop();
              },
              child: const Text(
                'Închide',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool cooking;
  final bool cooked;
  final VoidCallback onCook;

  const _BottomBar({
    required this.cooking,
    required this.cooked,
    required this.onCook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: (cooking || cooked) ? null : onCook,
          icon: cooking
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Icon(cooked ? Icons.check : Icons.local_fire_department),
          label: Text(
            cooked ? 'Gătit ✓' : 'Am gătit! 🍳',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkEmerald,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.darkEmerald.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
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

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.jungle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
