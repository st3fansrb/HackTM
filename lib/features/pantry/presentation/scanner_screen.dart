import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/barcode_service.dart';
import '../../../features/products/data/product_resolution_service.dart';
import 'qr_view_factory.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  late final BarcodeService _service;
  StreamSubscription<String>? _sub;
  bool _isScanning = false;
  bool _navigated = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    registerQrViewFactory();
    _service = BarcodeService();
    _sub = _service.barcodeStream.listen(_onBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  void _startScanning() {
    if (!mounted || _isScanning || _resolving) return;
    _navigated = false;
    _service.startScanner();
    setState(() => _isScanning = true);
  }

  void _stopScanning() {
    _service.stopScanner();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _onBarcode(String barcode) async {
    if (_navigated || !mounted || _resolving) return;
    _navigated = true;
    _stopScanning();

    setState(() => _resolving = true);
    try {
      final service = ref.read(productResolutionServiceProvider);
      final resolution = await service.resolveByBarcode(barcode);

      if (!mounted) return;
      if (resolution.isResolved) {
        context.push('/pantry/add', extra: resolution.product);
      } else {
        context.push('/pantry/product-not-found',
            extra: <String, String>{'barcode': barcode});
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.stopScanner();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Scanner Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Caută după nume',
            onPressed: () => context.push('/pantry/search'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb)
            const HtmlElementView(viewType: 'qr-reader-view')
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Scanner disponibil doar în browser (PWA)',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (_resolving)
            Container(
              color: Colors.black54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    'Caut produsul…',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          else if (!_isScanning)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner,
                        size: 80, color: Colors.white38),
                    const SizedBox(height: 24),
                    const Text(
                      'Scanner oprit',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Apasă butonul pentru a scana din nou',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _startScanning,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Pornește scanner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.push('/pantry/search'),
                      child: const Text(
                        'Caută după nume →',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Îndreptați camera spre barcode',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
