import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickCameraImage() async {
  final completer = Completer<Uint8List?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..setAttribute('capture', 'environment')
    ..style.display = 'none';

  html.document.body?.append(input);

  // Detect cancel via window regaining focus
  html.window.onFocus.first.then((_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  input.onChange.listen((_) async {
    final file = input.files?.first;
    input.remove();

    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.readAsDataUrl(file);

    reader.onLoad.listen((_) {
      try {
        final dataUrl = reader.result as String;
        final base64Str = dataUrl.split(',').last;
        if (!completer.isCompleted) {
          completer.complete(base64Decode(base64Str));
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  input.click();

  return completer.future;
}
