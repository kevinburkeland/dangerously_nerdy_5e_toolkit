import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Desktop and mobile implementation — reads via path for large files to avoid
/// loading the entire payload into memory as bytes first on IO platforms.
class CompendiumFileLoader {
  static Future<String?> readFileAsString(PlatformFile file) async {
    final filePath = file.path;
    if (filePath != null && filePath.isNotEmpty) {
      final ioFile = File(filePath);
      if (await ioFile.exists()) {
        return await ioFile.readAsString();
      }
    }
    // Fallback: read from the XFile stream
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }
}
