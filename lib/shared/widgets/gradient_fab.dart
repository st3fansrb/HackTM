import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GradientFab extends StatelessWidget {
  final VoidCallback onPressed;

  const GradientFab({super.key, required this.onPressed});

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
            child: Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
