import 'dart:typed_data';

import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

class FakeMapImageSource implements MapImageSource {
  @override
  final String name;
  final Uint8List bytes;

  int readRangeCalls = 0;
  int bytesRead = 0;

  FakeMapImageSource({
    required this.bytes,
    this.name = 'test.png',
  });

  @override
  int get byteSize => bytes.length;

  @override
  Future<Uint8List> readRange(int start, int end) async {
    readRangeCalls++;
    final clampedEnd = end > bytes.length ? bytes.length : end;
    if (start >= clampedEnd) {
      return Uint8List(0);
    }
    final length = clampedEnd - start;
    bytesRead += length;
    return bytes.sublist(start, clampedEnd);
  }
}

class FakeMapImageIntake implements MapImageIntakePort {
  MapImageSource? nextPickResult;
  bool pickCalled = false;

  NormalizedMapImage? nextNormalized;
  Object? normalizeError;
  int normalizeCalls = 0;
  int? lastTargetWidth;
  int? lastTargetHeight;

  @override
  Future<MapImageSource?> pick() async {
    pickCalled = true;
    return nextPickResult;
  }

  @override
  Future<NormalizedMapImage> normalize(
    MapImageSource source, {
    required int targetWidth,
    required int targetHeight,
  }) async {
    normalizeCalls++;
    lastTargetWidth = targetWidth;
    lastTargetHeight = targetHeight;
    if (normalizeError != null) {
      throw normalizeError!;
    }
    return nextNormalized ??
        createValidWebpNormalized(width: targetWidth, height: targetHeight);
  }

  static NormalizedMapImage createValidWebpNormalized({
    int width = 100,
    int height = 100,
    int payloadLength = 16,
  }) {
    // Minimal valid WebP buffer satisfying verifyBlob:
    // bytes 0-3: RIFF
    // bytes 4-7: length (u32 LE)
    // bytes 8-11: WEBP
    final totalSize = 12 + payloadLength;
    final bytes = Uint8List(totalSize);
    bytes[0] = 0x52; // R
    bytes[1] = 0x49; // I
    bytes[2] = 0x46; // F
    bytes[3] = 0x46; // F

    final len = totalSize - 8;
    bytes[4] = len & 0xFF;
    bytes[5] = (len >> 8) & 0xFF;
    bytes[6] = (len >> 16) & 0xFF;
    bytes[7] = (len >> 24) & 0xFF;

    bytes[8] = 0x57; // W
    bytes[9] = 0x45; // E
    bytes[10] = 0x42; // B
    bytes[11] = 0x50; // P

    return NormalizedMapImage(
      bytes: bytes,
      width: width,
      height: height,
      format: BlobFormat.webp,
    );
  }
}
