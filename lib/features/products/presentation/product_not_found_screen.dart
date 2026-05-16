import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../data/gemini_ocr_service.dart';
import '../data/image_picker_service.dart';

class ProductNotFoundScreen extends StatefulWidget {
  final String? barcode;
  const ProductNotFoundScreen({super.key, this.barcode});

  @override
  State<ProductNotFoundScreen> createState() => _ProductNotFoundScreenState();
}

class _ProductNotFoundScreenState extends State<ProductNotFoundScreen> {
  bool _ocrLoading = false;
  String _ocrStatus = 'Se deschide camera...';

  Future<void> _scanLabel() async {
    setState(() {
      _ocrLoading = true;
      _ocrStatus = 'Se deschide camera...';
    });

    try {
      final bytes = await pickCameraImage();
      if (!mounted) return;

      if (bytes == null) {
        setState(() => _ocrLoading = false);
        return;
      }

      setState(() => _ocrStatus = 'Analizez eticheta…');

      final data = await GeminiOcrService().extractFromImage(bytes);
      if (!mounted) return;

      setState(() => _ocrLoading = false);

      if (data == null) {
        _showOcrError();
        return;
      }

      final prefill = <String, dynamic>{
        if (widget.barcode != null) 'barcode': widget.barcode,
        if (data.name != null && data.name!.isNotEmpty) 'name': data.name,
        if (data.brand != null && data.brand!.isNotEmpty) 'brand': data.brand,
        if (data.quantity != null) 'quantity': data.quantity,
        if (data.unit != null) 'unit': data.unit,
        if (data.category != null) 'category': data.category,
        if (data.calories != null) 'calories': data.calories,
        if (data.sugar != null) 'sugar': data.sugar,
        if (data.fat != null) 'fat': data.fat,
      };

      context.push('/pantry/add', extra: prefill);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ocrLoading = false);
      _showOcrError();
    }
  }

  void _showOcrError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nu am putut citi eticheta, completează manual'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barcode = widget.barcode;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Produs necunoscut'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/pantry'),
        ),
      ),
      body: Stack(
        children: [
          Padding(
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
                  onPressed: _ocrLoading
                      ? null
                      : () => context.push(
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
                  onPressed: _ocrLoading ? null : _scanLabel,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotografiază eticheta'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _ocrLoading
                      ? null
                      : () => context.push(
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
                  onPressed:
                      _ocrLoading ? null : () => context.go('/pantry'),
                  child: Text(
                    'Renunță',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          if (_ocrLoading) ...[
            const ModalBarrier(color: Colors.black54, dismissible: false),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    _ocrStatus,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
