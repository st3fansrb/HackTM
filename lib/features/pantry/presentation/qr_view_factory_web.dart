// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

bool _registered = false;

void registerQrViewFactory() {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(
    'qr-reader-view',
    (int viewId) => html.DivElement()
      ..id = 'qr-reader'
      ..style.width = '100%'
      ..style.height = '100%',
  );
}