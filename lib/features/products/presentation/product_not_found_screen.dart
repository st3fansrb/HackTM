import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class ProductNotFoundScreen extends StatelessWidget {
  final String? barcode;
  const ProductNotFoundScreen({super.key, this.barcode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Produs necunoscut'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/pantry'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text(
              'Produsul nu este încă în Frigo',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Poți adăuga detaliile manual sau te poți limita doar la data de expirare. Contribuția ta îi ajută și pe alți utilizatori!',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            if (barcode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Barcode: $barcode',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => context.push(
                '/pantry/add',
                extra: barcode != null
                    ? <String, dynamic>{'barcode': barcode}
                    : null,
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Completează detalii manual'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/pantry/add',
                extra: <String, dynamic>{
                  if (barcode != null) 'barcode': barcode,
                  'minimal': true,
                },
              ),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Adaugă doar data de expirare'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/pantry'),
              child: Text(
                'Renunță',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
