import 'dart:typed_data';
import 'package:vtt_engine_core/vtt_engine_core.dart';

enum MapRejectReason {
  fileTooLarge,
  tooManyPixels,
  unsupportedFormat,
  unreadable,
  undecodable,
  outputTooLarge,
  encoderMismatch,
  orientationMismatch,
}

final class MapIntakeRejected implements Exception {
  final MapRejectReason reason;
  final int? width;
  final int? height;
  final int? byteSize;

  const MapIntakeRejected(
    this.reason, {
    this.width,
    this.height,
    this.byteSize,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapIntakeRejected &&
          reason == other.reason &&
          width == other.width &&
          height == other.height &&
          byteSize == other.byteSize;

  @override
  int get hashCode => Object.hash(reason, width, height, byteSize);

  @override
  String toString() =>
      'MapIntakeRejected($reason, width: $width, height: $height, byteSize: $byteSize)';
}

final class MapIntakeUnavailableException implements Exception {
  final String message;
  const MapIntakeUnavailableException(this.message);

  @override
  String toString() => 'MapIntakeUnavailableException: $message';
}

/// A file the DM picked. Holds the browser File on web; never holds its bytes.
abstract interface class MapImageSource {
  String get name;
  int get byteSize;
  Future<Uint8List> readRange(int start, int end);
}

final class NormalizedMapImage {
  final Uint8List bytes;
  final int width;
  final int height;
  final BlobFormat format; // webp or jpeg

  const NormalizedMapImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });
}

abstract interface class MapImageIntakePort {
  /// Shows the file chooser. Null if the user cancelled.
  Future<MapImageSource?> pick();

  /// Decodes [source] in the browser, scales it to [targetWidth] × [targetHeight]
  /// (the displayed size), and encodes a fresh WebP (or JPEG where WebP can't be encoded).
  Future<NormalizedMapImage> normalize(
    MapImageSource source, {
    required int targetWidth,
    required int targetHeight,
  });
}
