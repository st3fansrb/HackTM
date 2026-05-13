import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarcodeService {
  Stream<String> get barcodeStream => const Stream.empty();
  Stream<String> get debugStream   => const Stream.empty();
  void startScanner() {}
  void stopScanner() {}
  void toggleTorch() {}
  void dispose() {}
}

final barcodeServiceProvider = Provider.autoDispose<BarcodeService>((ref) {
  final service = BarcodeService();
  ref.onDispose(service.dispose);
  return service;
});
