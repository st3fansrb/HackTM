import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/pantry_provider.dart';
import '../../../shared/widgets/frigo_header.dart';
import '../domain/food_item.dart';
import 'item_card.dart';

const _categoryOrder = <String, int>{
  'lactate_oua':    0,
  'carne_mezeluri': 1,
  'peste':          2,
  'fructe_legume':  3,
  'panificatie':    4,
  'cereale_paste':  5,
  'conserve':       6,
  'snacks':         7,
  'bauturi':        8,
  'condimente':     9,
  'congelate':      10,
  'preparate':      11,
  'altele':         12,
};

const _categoryInfo = <String, (String, String)>{
  'lactate_oua':    ('🥛', 'Lactate & Ouă'),
  'carne_mezeluri': ('🥩', 'Carne & Mezeluri'),
  'peste':          ('🐟', 'Pește & Fructe de mare'),
  'fructe_legume':  ('🍎', 'Fructe & Legume proaspete'),
  'panificatie':    ('🍞', 'Panificație'),
  'cereale_paste':  ('🌾', 'Cereale, Paste & Leguminoase'),
  'conserve':       ('🫙', 'Conserve & Murături'),
  'snacks':         ('🍫', 'Snacks & Dulciuri'),
  'bauturi':        ('🥤', 'Băuturi'),
  'condimente':     ('🧂', 'Condimente, Sosuri & Uleiuri'),
  'congelate':      ('🧊', 'Congelate'),
  'preparate':      ('🍲', 'Preparate & Mâncăruri gătite'),
  'altele':         ('📦', 'Altele'),
};

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _scrollController = ScrollController();
  final _firstExpiredKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showExpiryBottomSheet(BuildContext context, List<FoodItem> items) {
    final atRisk = items
        .where((i) => !i.expirySkipped && i.daysUntilExpiry <= 7)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpiryBottomSheet(items: atRisk),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantryAsync = ref.watch(pantryProvider);

    return Scaffold(
      appBar: FrigoHeader(title: 'Frigider', showLogo: true),
      body: pantryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text('Nu s-au putut încărca produsele',
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(onAdd: () => context.push('/pantry/add'));
          }

          final expiredCount =
              items.where((i) => i.daysUntilExpiry < 0).length;
          final expiringSoonCount = items
              .where((i) =>
                  i.daysUntilExpiry >= 0 && i.daysUntilExpiry <= 7)
              .length;
          final urgentCount = items
              .where((i) =>
                  i.daysUntilExpiry >= 0 && i.daysUntilExpiry <= 2)
              .length;

          final groupedWidgets = _buildGroupedWidgets(items);

          return Column(
            children: [
              _StatsBar(
                total: items.length,
                expiredCount: expiredCount,
                expiringSoonCount: expiringSoonCount,
              ),
              if (expiredCount > 0)
                _ExpiryBanner(
                  isExpired: true,
                  count: expiredCount,
                  onTap: () => _showExpiryBottomSheet(context, items),
                )
              else if (urgentCount > 0)
                _ExpiryBanner(
                  isExpired: false,
                  count: urgentCount,
                  onTap: () => _showExpiryBottomSheet(context, items),
                ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100),
                  children: groupedWidgets,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _PantryFabs(),
    );
  }

  List<Widget> _buildGroupedWidgets(List<FoodItem> items) {
    final grouped = <String, List<FoodItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) =>
          (_categoryOrder[a] ?? 99).compareTo(_categoryOrder[b] ?? 99));

    for (final list in grouped.values) {
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    }

    bool firstExpiredAssigned = false;
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
        final isFirstExpired =
            !firstExpiredAssigned && item.daysUntilExpiry < 0;
        if (isFirstExpired) firstExpiredAssigned = true;

        widgets.add(KeyedSubtree(
          key: isFirstExpired ? _firstExpiredKey : null,
          child: ItemCard(
            item: item,
            onDelete: () => _handleDelete(item),
          ),
        ));
      }
    }

    return widgets;
  }

  Future<bool> _handleDelete(FoodItem item) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    bool wasConsumed = true;

    if (item.daysUntilExpiry < 0) {
      wasConsumed = false;
    } else if (item.daysUntilExpiry == 0) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Ce s-a întâmplat cu produsul?'),
          content: Text('${item.name} expiră azi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('✅ Consumat'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.expiredRed,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('🗑️ Aruncat'),
            ),
          ],
        ),
      );
      if (result == null) return false;
      wasConsumed = result;
    }

    await ref
        .read(pantryRepositoryProvider)
        .deleteItemWithTracking(uid, item, wasConsumed);
    return true;
  }
}

// ─── Expiry banner ────────────────────────────────────────────────────────────

class _ExpiryBanner extends StatelessWidget {
  final bool isExpired;
  final int count;
  final VoidCallback onTap;

  const _ExpiryBanner({
    required this.isExpired,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isExpired ? AppColors.expiredRed : AppColors.useSoonYellow;
    final bgColor = isExpired
        ? AppColors.expiredRed.withValues(alpha: 0.1)
        : AppColors.useSoonYellow.withValues(alpha: 0.12);
    final label = isExpired
        ? '⚠️ $count produs${count == 1 ? '' : 'e'} expirat${count == 1 ? '' : 'e'} — verifică frigiderul'
        : '⏰ $count produs${count == 1 ? '' : 'e'} expiră în curând';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isExpired
                          ? AppColors.expiredRed
                          : const Color(0xFFa07030),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18,
                color: isExpired
                    ? AppColors.expiredRed
                    : const Color(0xFFa07030)),
          ],
        ),
      ),
    );
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

// ─── Dual FABs (scanner primary + add secondary) ─────────────────────────────

class _PantryFabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: FloatingActionButton.small(
            heroTag: 'fabAdd',
            onPressed: () => context.push('/pantry/add'),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.darkTeal,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.darkTeal, width: 1.5),
            ),
            child: const Icon(Icons.add, size: 22),
          ),
        ),
        const SizedBox(height: 12),
        _ScannerFab(onPressed: () => context.push('/pantry/scanner')),
      ],
    );
  }
}

class _ScannerFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _ScannerFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.jungle, AppColors.darkEmerald],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkEmerald.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: const Center(
            child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total;
  final int expiredCount;
  final int expiringSoonCount;

  const _StatsBar({
    required this.total,
    required this.expiredCount,
    required this.expiringSoonCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatChip(
            label: '$total produse',
            icon: Icons.kitchen_outlined,
            color: AppColors.primary,
          ),
          const Spacer(),
          if (expiredCount > 0)
            _StatChip(
              label: '$expiredCount expirate',
              icon: Icons.warning_amber_outlined,
              color: AppColors.expiredRed,
            ),
          if (expiredCount > 0 && expiringSoonCount > 0)
            const SizedBox(width: 8),
          if (expiringSoonCount > 0)
            _StatChip(
              label: '$expiringSoonCount scadente',
              icon: Icons.schedule_outlined,
              color: AppColors.useSoonYellow,
            ),
          if (expiredCount == 0 && expiringSoonCount == 0)
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.freshGreen),
                const SizedBox(width: 4),
                Text('Totul e fresh!',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.freshGreen,
                        fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ─── Expiry bottom sheet ──────────────────────────────────────────────────────

class _ExpiryBottomSheet extends StatelessWidget {
  final List<FoodItem> items;
  const _ExpiryBottomSheet({required this.items});

  String _label(int days) {
    if (days < 0) {
      final d = -days;
      return 'expirat de $d ${d == 1 ? 'zi' : 'zile'}';
    }
    if (days == 0) return 'expiră azi';
    if (days == 1) return 'expiră mâine';
    return 'expiră în $days zile';
  }

  Color _color(int days) {
    if (days < 2) return AppColors.expiredRed;
    if (days < 5) return AppColors.useSoonYellow;
    return const Color(0xFFa07030);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Produse la risc',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.expiredRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: AppColors.expiredRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final days = item.daysUntilExpiry;
                  final color = _color(days);
                  final bgColor = days < 2
                      ? AppColors.expiredRed.withValues(alpha: 0.06)
                      : days < 5
                          ? AppColors.useSoonYellow.withValues(alpha: 0.08)
                          : Colors.transparent;

                  return ColoredBox(
                    color: bgColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            _label(days),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧊', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(
              'Frigiderul e gol!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adaugă primul produs pentru a\nîncepe să gestionezi alimentele.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adaugă produs'),
            ),
          ],
        ),
      ),
    );
  }
}
