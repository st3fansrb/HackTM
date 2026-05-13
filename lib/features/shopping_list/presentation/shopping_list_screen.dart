import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/shopping_list_provider.dart';
import '../../../shared/widgets/frigo_header.dart';
import '../../../shared/widgets/gradient_fab.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_item.dart';

const _categoryOrder = <String, int>{
  'meat': 0,
  'dairy': 1,
  'fruits': 2,
  'vegetables': 3,
  'grains': 4,
  'other': 5,
};

const _categoryInfo = <String, (String, String)>{
  'meat': ('🥩', 'Carne'),
  'dairy': ('🥛', 'Lactate'),
  'fruits': ('🍎', 'Fructe'),
  'vegetables': ('🥦', 'Legume'),
  'grains': ('🍞', 'Panificație'),
  'other': ('📦', 'Altele'),
};

const _categoryOptions = [
  ('other', '📦 Altele'),
  ('dairy', '🥛 Lactate'),
  ('meat', '🥩 Carne'),
  ('vegetables', '🥦 Legume'),
  ('fruits', '🍎 Fructe'),
  ('grains', '🍞 Panificație'),
];

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FrigoHeader(
        title: 'Cumpărături',
        subtitle: itemsAsync.maybeWhen(
          data: (items) {
            final n = items.where((i) => !i.checked).length;
            return n > 0 ? '$n rămase' : null;
          },
          orElse: () => null,
        ),
        actions: itemsAsync.maybeWhen(
          data: (items) => items.isNotEmpty
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: Colors.white70),
                    tooltip: 'Golește lista',
                    onPressed: () => _confirmClearAll(context, ref),
                  ),
                ]
              : null,
          orElse: () => null,
        ),
      ),
      floatingActionButton: GradientFab(
        onPressed: () => _showAddDialog(context, ref),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.expiredRed, size: 48),
              const SizedBox(height: 12),
              Text('Eroare la încărcare',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(shoppingListProvider),
                child: const Text('Încearcă din nou'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            children: _buildGroupedList(context, ref, items),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingItem> items,
  ) {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) =>
          (_categoryOrder[a] ?? 99).compareTo(_categoryOrder[b] ?? 99));

    // Within each category: unchecked first, checked last
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.checked == b.checked) return 0;
        return a.checked ? 1 : -1;
      });
    }

    final widgets = <Widget>[];

    for (final category in sortedCategories) {
      final categoryItems = grouped[category]!;
      final info = _categoryInfo[category] ?? ('📦', category);

      widgets.add(_CategoryHeader(
        emoji: info.$1,
        label: info.$2,
        count: categoryItems.length,
      ));

      for (final item in categoryItems) {
        widgets.add(_ShoppingItemTile(item: item));
      }
    }

    return widgets;
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Golești lista?'),
        content: const Text('Ștergi toate itemele din listă?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expiredRed,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge tot'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(shoppingListRepositoryProvider).clearAll(user.uid);
    } catch (_) {}
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final repo = ref.read(shoppingListRepositoryProvider);
    final controller = TextEditingController();
    String selectedCategory = 'other';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Adaugă produs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'ex: Lapte, Ouă, Pâine...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => _submitItem(
                    v, selectedCategory, user.uid, repo, ctx),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categorie',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _categoryOptions
                    .map((opt) => DropdownMenuItem(
                          value: opt.$1,
                          child: Text(opt.$2),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => selectedCategory = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            ElevatedButton(
              onPressed: () => _submitItem(
                  controller.text, selectedCategory, user.uid, repo, ctx),
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Future<void> _submitItem(
    String name,
    String category,
    String uid,
    ShoppingListRepository repo,
    BuildContext ctx,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await repo.addItem(
        uid,
        ShoppingItem(
          id: '',
          name: trimmed,
          checked: false,
          source: 'manual',
          category: category,
          addedAt: DateTime.now(),
        ),
      );
    } catch (_) {}
    if (ctx.mounted) Navigator.pop(ctx);
  }
}

// ─── Category header ──────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;

  const _CategoryHeader({
    required this.emoji,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTeal,
                ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.darkTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shopping item tile ───────────────────────────────────────────────────────

class _ShoppingItemTile extends ConsumerWidget {
  final ShoppingItem item;
  const _ShoppingItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final repo = ref.read(shoppingListRepositoryProvider);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        if (user == null) return;
        try {
          await repo.deleteItem(user.uid, item.id);
        } catch (_) {}
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.expiredRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child:
            const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (user == null) return;
            try {
              await repo.toggleItem(user.uid, item.id, !item.checked);
            } catch (_) {}
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Checkbox(
                  value: item.checked,
                  onChanged: (v) async {
                    if (user == null || v == null) return;
                    try {
                      await repo.toggleItem(user.uid, item.id, v);
                    } catch (_) {}
                  },
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  decoration: item.checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.checked
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                      ),
                      if (item.quantity != null && item.unit != null)
                        Text(
                          '${_fmt(item.quantity!)} ${item.unit}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (item.source != 'manual') const _AiBadge(),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 11, color: AppColors.accent),
          SizedBox(width: 3),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Lista e goală',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Adaugă produse manual sau întreabă\nAI-ul ce îți lipsește la rețete.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
