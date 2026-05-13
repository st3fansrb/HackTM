import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ExpirySelector extends StatelessWidget {
  final String category;
  final DateTime? selected;
  final void Function(DateTime) onChanged;

  const ExpirySelector({
    super.key,
    required this.category,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (category) {
      case 'dairy':
        return _ChipRow(
          options: const [3, 5, 7, 14],
          selected: selected,
          onChanged: onChanged,
          defaultDays: 7,
        );
      case 'meat':
      case 'fish':
        return _ChipRow(
          options: const [1, 2, 3, 5],
          selected: selected,
          onChanged: onChanged,
          defaultDays: 3,
        );
      case 'produce':
        return _ProduceSlider(selected: selected, onChanged: onChanged);
      case 'canned':
      case 'beverages':
      case 'cereals':
        return _LongShelfRow(selected: selected, onChanged: onChanged);
      default:
        return _ChipRow(
          options: const [3, 7, 14, 30],
          selected: selected,
          onChanged: onChanged,
          defaultDays: null,
        );
    }
  }
}

// ─── Chip row ────────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  final List<int> options;
  final DateTime? selected;
  final void Function(DateTime) onChanged;
  final int? defaultDays;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.defaultDays,
  });

  bool _isSelected(int days) {
    if (selected == null) return false;
    final target = _dateFromNow(days);
    return selected!.year == target.year &&
        selected!.month == target.month &&
        selected!.day == target.day;
  }

  bool _isCustomSelected() {
    if (selected == null) return false;
    return !options.any((d) => _isSelected(d));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final days in options)
          _Chip(
            label: _chipLabel(days),
            isSelected: _isSelected(days),
            onTap: () => onChanged(_dateFromNow(days)),
          ),
        _Chip(
          label: 'Altă dată',
          isSelected: _isCustomSelected(),
          onTap: () => _pickDate(context),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? _dateFromNow(defaultDays ?? 7),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) onChanged(picked);
  }
}

// ─── Produce slider ───────────────────────────────────────────────────────────

class _ProduceSlider extends StatelessWidget {
  final DateTime? selected;
  final void Function(DateTime) onChanged;

  static const _steps = [
    (emoji: '🟥', label: 'Foarte copt', days: 1),
    (emoji: '🟧', label: 'Copt', days: 3),
    (emoji: '🟨', label: 'Semi-copt', days: 6),
    (emoji: '🟩', label: 'Verde', days: 12),
  ];

  const _ProduceSlider({required this.selected, required this.onChanged});

  int _currentIndex() {
    if (selected == null) return 1;
    final daysLeft = selected!.difference(DateTime.now()).inDays;
    int best = 1;
    int bestDiff = 999;
    for (int i = 0; i < _steps.length; i++) {
      final diff = (_steps[i].days - daysLeft).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex();
    final step = _steps[idx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.darkTeal,
            inactiveTrackColor: AppColors.darkTeal.withValues(alpha: 0.15),
            thumbColor: AppColors.darkTeal,
            overlayColor: AppColors.darkTeal.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: idx.toDouble(),
            min: 0,
            max: (_steps.length - 1).toDouble(),
            divisions: _steps.length - 1,
            onChanged: (v) => onChanged(_dateFromNow(_steps[v.round()].days)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${step.emoji} ${step.label} · ~${step.days} ${step.days == 1 ? 'zi' : 'zile'}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Long shelf (canned / beverages / cereals) ────────────────────────────────

class _LongShelfRow extends StatelessWidget {
  final DateTime? selected;
  final void Function(DateTime) onChanged;

  const _LongShelfRow({required this.selected, required this.onChanged});

  String _label() {
    if (selected == null) return 'Estimat: 1 an · Editează';
    final days = selected!.difference(DateTime.now()).inDays;
    if (days >= 360) return 'Estimat: 1 an · Editează';
    return 'Estimat: $days zile · Editează';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickDate(context),
      child: Text(
        _label(),
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─── Chip widget ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkTeal.withValues(alpha: 0.08)
              : AppColors.bg,
          border: Border.all(
            color: isSelected
                ? AppColors.darkTeal
                : AppColors.darkTeal.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? AppColors.darkTeal : AppColors.textMuted,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

DateTime _dateFromNow(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

String _chipLabel(int days) {
  if (days == 1) return '1 zi';
  return '$days zile';
}
