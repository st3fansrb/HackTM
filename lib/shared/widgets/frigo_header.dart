import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';

class FrigoHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showLogo;

  static const _baseHeight    = 76.0;
  static const _subtitleExtra = 26.0;
  static const _bottomExtra   = 52.0;

  const FrigoHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.showLogo = false,
  });

  @override
  Size get preferredSize {
    double h = _baseHeight;
    if (subtitle != null) h += _subtitleExtra;
    if (bottom != null) h += _bottomExtra;
    return Size.fromHeight(h);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        height: preferredSize.height + topPad,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.darkTeal, AppColors.darkEmerald],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cerc decorativ top-right
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Conținut
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: showLogo
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showLogo)
                              Image.asset(
                                'assets/logo+name.png',
                                height: 36,
                                fit: BoxFit.contain,
                              )
                            else
                              Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (actions != null) ...actions!,
                    ],
                  ),
                  if (bottom != null) ...[
                    const SizedBox(height: 12),
                    bottom!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
