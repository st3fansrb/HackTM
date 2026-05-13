import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

const kAllCondiments = [
  'Sare', 'Piper', 'Ulei floarea soarelui', 'Ulei de măsline',
  'Zahăr', 'Oțet', 'Bicarbonat', 'Drojdie',
  'Boia dulce', 'Boia iute', 'Oregano', 'Busuioc',
  'Cimbru', 'Usturoi praf', 'Ceapă praf', 'Scorțișoară',
];

class CondimentsPicker extends StatelessWidget {
  final List<String> selected;
  final void Function(List<String>) onChanged;

  const CondimentsPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAllCondiments.map((condiment) {
        final isSelected = selected.contains(condiment);
        return GestureDetector(
          onTap: () {
            final updated = List<String>.from(selected);
            if (isSelected) {
              updated.remove(condiment);
            } else {
              updated.add(condiment);
            }
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.darkTeal.withValues(alpha: 0.08)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.darkTeal
                    : AppColors.darkTeal.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check, size: 14, color: AppColors.jungle),
                  const SizedBox(width: 4),
                ],
                Text(
                  condiment,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.darkTeal
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
