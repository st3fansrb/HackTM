import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../features/products/data/product_resolution_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  bool _navigated = false;
  bool _resolving = false;
  bool _torchOn = false;
  String? _lastBarcode;
  int _sameCount = 0;

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || _navigated || !mounted || _resolving) return;
    if (barcode == _lastBarcode) {
      _sameCount++;
      if (_sameCount >= 2) _onBarcode(barcode);
    } else {
      _lastBarcode = barcode;
      _sameCount = 1;
    }
  }

  Future<void> _onBarcode(String barcode) async {
    if (_navigated || !mounted || _resolving) return;
    _navigated = true;
    await _controller.stop();

    // TEMP DIAGNOSTIC — remove after barcode debug
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RAW barcode: "$barcode" (len ${barcode.length})'),
          duration: const Duration(seconds: 4),
        ),
      );
    }

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

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  void dispose() {
    _controller.dispose();
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
            icon: Icon(
              _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
            ),
            tooltip: 'Lanternă',
            onPressed: _toggleTorch,
          ),
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          if (_resolving)
            Container(
              color: Colors.black54,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Caut produsul…',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
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
