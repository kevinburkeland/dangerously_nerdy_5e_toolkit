import 'package:file_picker/file_picker.dart';
import 'compendium_file_loader.dart';
import 'compendium_file_saver.dart';

/// Representation of a chosen compendium JSON file loaded into memory.
class LoadedCompendiumFile {
  final String fileName;
  final int sizeInBytes;
  final String content;

  const LoadedCompendiumFile({
    required this.fileName,
    required this.sizeInBytes,
    required this.content,
  });

  /// Human-readable file size (e.g., '16.6 MB', '512 KB').
  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Cross-platform helper for selecting, uploading, and saving compendium JSON files.
class CompendiumFilePickerService {
  /// Opens a native system file picker to select a JSON file.
  /// Returns [null] if the user cancelled, or if the file could not be read.
  static Future<LoadedCompendiumFile?> pickCompendiumJsonFile() async {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (files.isEmpty) return null;

    final file = files.first;
    final content = await CompendiumFileLoader.readFileAsString(file);
    if (content == null || content.isEmpty) return null;

    final sizeInBytes = file.lengthSync() ?? content.length;

    return LoadedCompendiumFile(
      fileName: file.name,
      sizeInBytes: sizeInBytes,
      content: content,
    );
  }

  /// Prompts the user to save or download a JSON compendium bundle file.
  /// Returns the saved [Uri] on success, or [null] if cancelled.
  static Future<Uri?> saveCompendiumJsonFile({
    required String fileName,
    required String content,
    String? dialogTitle,
  }) async {
    return CompendiumFileSaver.saveJsonFile(
      fileName: fileName,
      content: content,
      dialogTitle: dialogTitle,
    );
  }

  /// Converts a bundle name to a safe file name, e.g. "My Homebrew Pack" → "my_homebrew_pack.json".
  static String toSafeFileName(String bundleName) {
    final slug = bundleName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${slug.isEmpty ? 'homebrew_bundle' : slug}.json';
  }

  /// Human-readable file size from bytes.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
