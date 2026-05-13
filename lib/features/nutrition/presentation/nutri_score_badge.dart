import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class NutriScoreBadge extends StatelessWidget {
  final String? score;
  const NutriScoreBadge({super.key, this.score});

  @override
  Widget build(BuildContext context) {
    final s = score ?? 'N/A';
    final color = switch (s) {
      'A' => AppColors.nutriA,
      'B' => AppColors.nutriB,
      'C' => AppColors.nutriC,
      'D' => AppColors.nutriD,
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        s,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          height: 1.2,
        ),
      ),
    );
  }
}
