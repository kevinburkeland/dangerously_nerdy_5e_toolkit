import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

enum BlobVerdict { ok, wrongSize, wrongSignature, wrongHash }

BlobVerdict verifyBlob(BlobRef ref, Uint8List bytes) {
  if (bytes.length != ref.byteSize) {
    return BlobVerdict.wrongSize;
  }

  final format = ref.format;
  if (format == BlobFormat.webp) {
    if (bytes.length < 12) {
      return BlobVerdict.wrongSignature;
    }
    // bytes 0-3: ASCII 'RIFF' (0x52, 0x49, 0x46, 0x46)
    // bytes 8-11: ASCII 'WEBP' (0x57, 0x45, 0x42, 0x50)
    final isRiff = bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46;
    final isWebp = bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    if (!isRiff || !isWebp) {
      return BlobVerdict.wrongSignature;
    }
  } else if (format == BlobFormat.jpeg) {
    if (bytes.length < 3) {
      return BlobVerdict.wrongSignature;
    }
    // bytes 0-2: FF D8 FF
    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    if (!isJpeg) {
      return BlobVerdict.wrongSignature;
    }
  } else {
    return BlobVerdict.wrongSignature;
  }

  final calculatedHash = sha256.convert(bytes).toString().toLowerCase();
  if (calculatedHash != ref.sha256Hex) {
    return BlobVerdict.wrongHash;
  }

  return BlobVerdict.ok;
}
