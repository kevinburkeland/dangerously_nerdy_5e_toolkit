import 'dart:convert';
import 'package:file_picker/file_picker.dart';

/// Platform-agnostic fallback / Web implementation for saving files.
class CompendiumFileSaver {
  static Future<Uri?> saveJsonFile({
    required String fileName,
    required String content,
    String? dialogTitle,
  }) async {
    final bytes = utf8.encode(content);
    final savedUri = await FilePickerPlatform.instance.saveFile(
      dialogTitle: dialogTitle ?? 'Save Homebrew JSON',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );
    return savedUri;
  }
}
