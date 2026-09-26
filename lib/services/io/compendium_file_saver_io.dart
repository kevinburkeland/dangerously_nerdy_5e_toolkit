import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Desktop and mobile implementation — opens a native "Save As" dialog and
/// writes the content directly to disk.
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

    // On desktop platforms, the picker may return a path but not auto-write.
    // Ensure the file exists and has content.
    if (savedUri != null && savedUri.isScheme('file')) {
      final ioFile = File(savedUri.toFilePath());
      if (!await ioFile.exists() || await ioFile.length() == 0) {
        await ioFile.writeAsString(content);
      }
    }

    return savedUri;
  }
}
