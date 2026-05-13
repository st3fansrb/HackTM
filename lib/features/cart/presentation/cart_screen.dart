import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/nutrition/domain/nutri_score.dart';
import '../../../features/nutrition/presentation/nutri_score_badge.dart';
import '../../../features/pantry/domain/food_item.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/providers/shopping_list_provider.dart';
import '../../../shared/widgets/expiry_selector.dart';
import '../../../shared/widgets/frigo_header.dart';
import '../../shopping_list/domain/shopping_item.dart';
import '../domain/cart_item.dart';

// ─── Category helpers ─────────────────────────────────────────────────────────

const _categoryEmoji = {
  'dairy':   '🥛',
  'meat':    '🥩',
  'produce': '🥦',
  'canned':  '🥫',
  'other':   '📦',
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return cartAsync.when(
      loading: () => Scaffold(
        appBar: FrigoHeader(title: '🛒 Coș'),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: FrigoHeader(title: '🛒 Coș'),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_outlined,
                  size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text('Nu s-a putut încărca coșul'),
            ],
          ),
        ),
      ),
      data: (items) => _CartBody(items: items),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _CartBody extends ConsumerWidget {
  final List<CartItem> items;
  const _CartBody({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = items.length;

    return Scaffold(
      appBar: FrigoHeader(
        title: '🛒 Coș',
        subtitle: n == 0 ? 'Coșul e gol' : '$n ${n == 1 ? 'produs' : 'produse'}',
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            tooltip: 'Listă cumpărături',
            onPressed: () => _showShoppingList(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _CartItemTile(
                      item: items[i],
                      onDelete: () => _removeItem(ref, items[i].id),
                      onTap: () => _editExpiry(ctx, ref, items[i]),
                    ),
                  ),
          ),
          _FinishBar(
            itemCount: n,
            onFinish: n == 0 ? null : () => _finalize(context, ref, items),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/cart/scanner'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showShoppingList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ShoppingListSheet(),
    );
  }

  void _removeItem(WidgetRef ref, String itemId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    ref.read(cartRepositoryProvider).removeItem(uid, itemId);
  }

  Future<void> _editExpiry(
      BuildContext context, WidgetRef ref, CartItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExpiryEditSheet(
        item: item,
        onSave: (date) async {
          final uid = FirebaseAuth.instance.currentUser!.uid;
          await ref
              .read(cartRepositoryProvider)
              .updateItem(uid, item.copyWith(expiryDate: date));
        },
      ),
    );
  }

  Future<void> _finalize(
      BuildContext context, WidgetRef ref, List<CartItem> items) async {
    final n = items.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finalizează cumpărăturile'),
        content: Text(
          'Adaugi $n ${n == 1 ? 'produs' : 'produse'} în Frigider?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirmă',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final pantryRepo = ref.read(pantryRepositoryProvider);
    final cartRepo = ref.read(cartRepositoryProvider);

    for (final cartItem in items) {
      final score =
          calculateNutriScore(cartItem.calories, cartItem.sugar, cartItem.fat);
      final foodItem = FoodItem(
        id: '',
        name: cartItem.name,
        category: cartItem.category,
        quantity: cartItem.quantity,
        unit: cartItem.unit,
        expiryDate: cartItem.expiryDate ??
            DateTime.now().add(const Duration(days: 7)),
        barcode: cartItem.barcode,
        calories: cartItem.calories,
        sugar: cartItem.sugar,
        fat: cartItem.fat,
        nutriScore: score == 'N/A' ? null : score,
        addedAt: DateTime.now(),
      );
      await pantryRepo.addItem(uid, foodItem);
    }

    await cartRepo.clearCart(uid);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$n ${n == 1 ? 'produs adăugat' : 'produse adăugate'} în Frigider ✓',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkEmerald,
      ),
    );
    context.go('/pantry');
  }
}

// ─── Cart item tile ───────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _CartItemTile({
    required this.item,
    required this.onDelete,
    required this.onTap,
  });

  int get _daysUntilExpiry {
    if (item.expiryDate == null) return 999;
    return item.expiryDate!.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final score = calculateNutriScore(item.calories, item.sugar, item.fat);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.expiredRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child:
            const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _categoryEmoji[item.category] ?? '📦',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatQty(item.quantity)} ${item.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (score != 'N/A') NutriScoreBadge(score: score),
                    const SizedBox(height: 6),
                    _ExpiryBadge(days: _daysUntilExpiry),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();
}

// ─── Expiry badge ─────────────────────────────────────────────────────────────

class _ExpiryBadge extends StatelessWidget {
  final int days;
  const _ExpiryBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days == 999) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Fără dată',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      );
    }

    final String label;
    final Color bgColor;
    final Color textColor;

    if (days <= 0) {
      label = days < 0 ? 'Expirat' : 'Azi';
      bgColor = AppColors.expiryRed.withValues(alpha: 0.1);
      textColor = AppColors.expiryRed;
    } else if (days <= 3) {
      label = '$days ${days == 1 ? 'zi' : 'zile'}';
      bgColor = AppColors.expiryFawn.withValues(alpha: 0.15);
      textColor = const Color(0xFFa07030);
    } else {
      label = '$days zile';
      bgColor = AppColors.expiryGreen.withValues(alpha: 0.1);
      textColor = AppColors.darkEmerald;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─── Expiry edit bottom sheet ─────────────────────────────────────────────────

class _ExpiryEditSheet extends StatefulWidget {
  final CartItem item;
  final Future<void> Function(DateTime) onSave;

  const _ExpiryEditSheet({required this.item, required this.onSave});

  @override
  State<_ExpiryEditSheet> createState() => _ExpiryEditSheetState();
}

class _ExpiryEditSheetState extends State<_ExpiryEditSheet> {
  late DateTime? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.item.expiryDate;
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_selected!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Editează expirarea',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            widget.item.name,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ExpirySelector(
            category: widget.item.category,
            selected: _selected,
            onChanged: (d) => setState(() => _selected = d),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selected == null || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvează',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Finish bar ───────────────────────────────────────────────────────────────

class _FinishBar extends StatelessWidget {
  final int itemCount;
  final VoidCallback? onFinish;

  const _FinishBar({required this.itemCount, this.onFinish});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      color: AppColors.bg,
      padding: EdgeInsets.fromLTRB(16, 12, 80, 12 + bottomPad),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onFinish,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            itemCount == 0
                ? 'Finalizează cumpărăturile'
                : 'Finalizează cumpărăturile ($itemCount)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                itemCount == 0 ? AppColors.textMuted : AppColors.darkEmerald,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.textMuted.withValues(alpha: 0.3),
            disabledForegroundColor: AppColors.textMuted,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ─── Shopping list bottom sheet ───────────────────────────────────────────────

class _ShoppingListSheet extends ConsumerWidget {
  const _ShoppingListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingListProvider);
    final maxH = MediaQuery.of(context).size.height * 0.82;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Text('📋', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  'Lista de cumpărături',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // list content
          Flexible(
            child: itemsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'Nu s-a putut încărca lista.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🛍️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Lista e goală',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Întreabă AI-ul ce îți lipsește\nla rețetele tale.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final aiItems = items
                    .where((i) => i.source == 'ai' || i.source == 'meal_plan')
                    .toList();
                final manualItems =
                    items.where((i) => i.source == 'manual').toList();

                return ListView(
                  padding: EdgeInsets.only(top: 8, bottom: 24 + bottomPad),
                  shrinkWrap: true,
                  children: [
                    if (aiItems.isNotEmpty) ...[
                      _SheetSectionHeader(
                          label: 'Recomandate de AI',
                          icon: Icons.auto_awesome),
                      ...aiItems.map((i) => _SheetItemTile(item: i)),
                    ],
                    if (manualItems.isNotEmpty) ...[
                      _SheetSectionHeader(
                          label: 'Adăugate manual',
                          icon: Icons.edit_outlined),
                      ...manualItems.map((i) => _SheetItemTile(item: i)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SheetSectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

class _SheetItemTile extends ConsumerWidget {
  final ShoppingItem item;
  const _SheetItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final repo = ref.read(shoppingListRepositoryProvider);

    return Dismissible(
      key: Key('sheet-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        if (user == null) return;
        try {
          await repo.deleteItem(user.uid, item.id);
        } catch (_) {}
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.expiredRed,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      child: InkWell(
        onTap: () async {
          if (user == null) return;
          try {
            await repo.toggleItem(user.uid, item.id, !item.checked);
          } catch (_) {}
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: item.checked
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.checked
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                ),
              ),
              if (item.source != 'manual')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 10, color: AppColors.accent),
                      SizedBox(width: 3),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

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
            const Text('🛒', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(
              'Coșul e gol',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scanează produsele cumpărate\npentru a le adăuga rapid.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
