import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarcodeService {
  final _controller      = StreamController<String>.broadcast();
  final _debugController = StreamController<String>.broadcast();

  BarcodeService() {
    globalContext['onBarcodeScanned'] = ((JSAny? barcode) {
      final str = barcode?.dartify() as String?;
      if (str != null && !_controller.isClosed) _controller.add(str);
    }).toJS;
    globalContext['onDebugMessage'] = ((JSAny? msg) {
      final str = msg?.dartify() as String?;
      if (str != null && !_debugController.isClosed) _debugController.add(str);
    }).toJS;
  }

  Stream<String> get barcodeStream => _controller.stream;
  Stream<String> get debugStream   => _debugController.stream;

  void startScanner() {
    try {
      globalContext.callMethod('startScanner'.toJS);
    } catch (_) {}
  }

  void stopScanner() {
    try {
      globalContext.callMethod('stopScanner'.toJS);
    } catch (_) {}
  }

  void toggleTorch() {
    try {
      globalContext.callMethod('toggleTorch'.toJS);
    } catch (_) {}
  }

  void dispose() {
    _controller.close();
    _debugController.close();
  }
}

final barcodeServiceProvider = Provider.autoDispose<BarcodeService>((ref) {
  final service = BarcodeService();
  ref.onDispose(service.dispose);
  return service;
});
