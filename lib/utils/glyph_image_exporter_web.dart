import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('eval')
external void _eval(String code);

Future<void> downloadPngBytesImpl(Uint8List bytes, String filename) async {
  try {
    final base64Data = base64Encode(bytes);
    final dataUrl = 'data:image/png;base64,$base64Data';
    final sanitizedFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');

    _eval('''
      (function() {
        var a = document.createElement('a');
        a.href = "$dataUrl";
        a.download = "$sanitizedFilename";
        document.body.appendChild(a);
        a.click();
        setTimeout(function() {
          document.body.removeChild(a);
        }, 100);
      })();
    ''');
  } catch (_) {}
}
