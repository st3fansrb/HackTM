import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/nutrition/presentation/nutri_score_badge.dart';
import '../../../shared/widgets/ripeness_slider.dart';
import '../data/fresh_produce_data.dart';
import '../domain/food_item.dart';

const _kCategoryEmoji = {
  // new IDs
  'lactate_oua':    '🥛',
  'carne_mezeluri': '🥩',
  'peste':          '🐟',
  'fructe_legume':  '🍎',
  'panificatie':    '🍞',
  'cereale_paste':  '🌾',
  'conserve':       '🫙',
  'snacks':         '🍫',
  'bauturi':        '🥤',
  'condimente':     '🧂',
  'congelate':      '🧊',
  'preparate':      '🍲',
  'altele':         '📦',
  // legacy IDs (migration fallback)
  'dairy':          '🥛',
  'meat':           '🥩',
  'vegetables':     '🥦',
  'fruits':         '🍎',
  'grains':         '🌾',
  'other':          '📦',
};

const _kCategoryLabel = {
  'lactate_oua':    'Lactate',
  'carne_mezeluri': 'Carne',
  'peste':          'Pește',
  'fructe_legume':  'Fructe & Legume',
  'panificatie':    'Panificație',
  'cereale_paste':  'Cereale',
  'conserve':       'Conserve',
  'snacks':         'Snacks',
  'bauturi':        'Băuturi',
  'condimente':     'Condimente',
  'congelate':      'Congelate',
  'preparate':      'Preparate',
  'altele':         'Altele',
  'dairy':          'Lactate',
  'meat':           'Carne',
  'vegetables':     'Legume',
  'fruits':         'Fructe',
  'grains':         'Cereale',
  'other':          'Altele',
};

class ItemCard extends StatelessWidget {
  final FoodItem item;
  final Future<bool> Function() onDelete;

  const ItemCard({super.key, required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
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
      child: Card(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Emoji + optional ripeness dot
              Stack(
                clipBehavior: Clip.none,
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
                        _kCategoryEmoji[item.category] ?? '📦',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  if (item.isFreshItem)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: _RipenessDot(item: item),
                    ),
                ],
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
                      '${_formatQty(item.quantity)} ${item.unit} • ${_kCategoryLabel[item.category] ?? 'Altele'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!item.isFreshItem) NutriScoreBadge(score: item.nutriScore),
                  const SizedBox(height: 6),
                  _ExpiryBadge(item: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) =>
      qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty.toStringAsFixed(1);
}

class _RipenessDot extends StatelessWidget {
  final FoodItem item;
  const _RipenessDot({required this.item});

  @override
  Widget build(BuildContext context) {
    double currentRipeness = item.initialRipeness?.toDouble() ?? 2.0;
    if (item.baseShelfLifeDays != null && item.initialRipeness != null) {
      final entry = lookupFreshProduce(item.name);
      currentRipeness = calcCurrentRipeness(
        initialRipeness: item.initialRipeness!,
        baseShelfLifeDays: item.baseShelfLifeDays!,
        addedAt: item.addedAt,
        storageLocation: item.storageLocation,
        entry: entry,
      );
    }
    final color = ripenessColor(currentRipeness);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  final FoodItem item;
  const _ExpiryBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.expirySkipped) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '—',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }

    final days = item.daysUntilExpiry;
    final String label;
    final Color bgColor;
    final Color textColor;

    if (days < 0) {
      label = item.isFreshItem ? 'Alterat' : 'Expirat';
      bgColor = AppColors.expiryRed.withValues(alpha: 0.1);
      textColor = AppColors.expiryRed;
    } else if (days == 0) {
      label = 'Azi';
      bgColor = AppColors.expiryRed.withValues(alpha: 0.1);
      textColor = AppColors.expiryRed;
    } else if (days <= 3) {
      label = '$days ${days == 1 ? "zi" : "zile"}';
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
