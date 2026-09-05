import 'dart:convert';
import 'package:file_picker/file_picker.dart';

/// Platform-agnostic fallback / Web implementation for loading file bytes into string.
class CompendiumFileLoader {
  static Future<String?> readFileAsString(PlatformFile file) async {
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }
}
