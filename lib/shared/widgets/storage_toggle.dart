import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

const _kStorageOptions = [
  ('temperatura_camerei', 'Cameră', Icons.home_outlined),
  ('frigider', 'Frigider', Icons.ac_unit_outlined),
  ('congelator', 'Congelator', Icons.kitchen_outlined),
];

class StorageToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String>? onChanged;

  const StorageToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Row(
      children: _kStorageOptions.map((opt) {
        final (id, label, icon) = opt;
        final selected = value == id;
        return Expanded(
          child: GestureDetector(
            onTap: locked ? null : () => onChanged!(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : locked
                        ? AppColors.background
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.divider,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? Colors.white
                        : locked
                            ? Colors.grey[400]
                            : AppColors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : locked
                              ? Colors.grey[400]
                              : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
