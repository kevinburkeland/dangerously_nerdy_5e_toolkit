import 'dart:convert';
import 'dart:js_interop';

@JS('eval')
external void _eval(String code);

Future<bool> downloadJsonFileImpl(String jsonContent, String filename) async {
  try {
    final base64Data = base64Encode(utf8.encode(jsonContent));
    final dataUrl = 'data:application/json;charset=utf-8;base64,$base64Data';
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
    return true;
  } catch (_) {
    return false;
  }
}
