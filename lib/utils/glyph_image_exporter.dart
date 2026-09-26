import 'dart:typed_data';
import 'glyph_image_exporter_stub.dart'
    if (dart.library.html) 'glyph_image_exporter_web.dart'
    if (dart.library.js_interop) 'glyph_image_exporter_web.dart';

abstract class GlyphImageExporter {
  static Future<void> downloadPngBytes(Uint8List bytes, String filename) async {
    await downloadPngBytesImpl(bytes, filename);
  }
}
