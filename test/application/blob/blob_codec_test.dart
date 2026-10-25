import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_protocol.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_verifier.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

Uint8List _makeValidWebp({int totalBytes = 20}) {
  final bytes = Uint8List(totalBytes);
  // 'RIFF'
  bytes[0] = 0x52;
  bytes[1] = 0x49;
  bytes[2] = 0x46;
  bytes[3] = 0x46;
  // bytes 4-7 file size placeholder
  // 'WEBP'
  bytes[8] = 0x57;
  bytes[9] = 0x45;
  bytes[10] = 0x42;
  bytes[11] = 0x50;
  for (var i = 12; i < totalBytes; i++) {
    bytes[i] = (i * 7) % 256;
  }
  return bytes;
}

Uint8List _makeValidJpeg({int totalBytes = 20}) {
  final bytes = Uint8List(totalBytes);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  for (var i = 3; i < totalBytes; i++) {
    bytes[i] = (i * 13) % 256;
  }
  return bytes;
}

BlobRef _refFor(Uint8List bytes, BlobFormat format, {int width = 100, int height = 100}) {
  final hash = sha256.convert(bytes).toString().toLowerCase();
  return BlobRef(
    sha256Hex: hash,
    byteSize: bytes.length,
    width: width,
    height: height,
    format: format,
  );
}

void main() {
  group('V1: verifyBlob', () {
    test('ok for valid WebP and valid JPEG', () {
      final webpBytes = _makeValidWebp();
      final webpRef = _refFor(webpBytes, BlobFormat.webp);
      expect(verifyBlob(webpRef, webpBytes), equals(BlobVerdict.ok));

      final jpegBytes = _makeValidJpeg();
      final jpegRef = _refFor(jpegBytes, BlobFormat.jpeg);
      expect(verifyBlob(jpegRef, jpegBytes), equals(BlobVerdict.ok));
    });

    test('wrongSize for one byte more and one byte less', () {
      final webpBytes = _makeValidWebp(totalBytes: 30);
      final ref = _refFor(webpBytes, BlobFormat.webp);

      final oneLess = webpBytes.sublist(0, webpBytes.length - 1);
      expect(verifyBlob(ref, oneLess), equals(BlobVerdict.wrongSize));

      final oneMore = Uint8List(webpBytes.length + 1)..setRange(0, webpBytes.length, webpBytes);
      expect(verifyBlob(ref, oneMore), equals(BlobVerdict.wrongSize));
    });

    test('wrongSignature for WebP ref over JPEG bytes and vice versa', () {
      final webpBytes = _makeValidWebp(totalBytes: 30);
      final jpegBytes = _makeValidJpeg(totalBytes: 30);

      final webpRef = _refFor(webpBytes, BlobFormat.webp);
      final jpegRef = _refFor(jpegBytes, BlobFormat.jpeg);

      expect(verifyBlob(webpRef, jpegBytes), equals(BlobVerdict.wrongSignature));
      expect(verifyBlob(jpegRef, webpBytes), equals(BlobVerdict.wrongSignature));
    });

    test('wrongSignature for RIFF....WAVE', () {
      final waveBytes = Uint8List(20);
      waveBytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // RIFF
      waveBytes.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // WAVE
      final ref = _refFor(waveBytes, BlobFormat.webp);
      expect(verifyBlob(ref, waveBytes), equals(BlobVerdict.wrongSignature));
    });

    test('wrongSignature for PNG signature', () {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]);
      final refWebp = _refFor(pngBytes, BlobFormat.webp);
      final refJpeg = _refFor(pngBytes, BlobFormat.jpeg);
      expect(verifyBlob(refWebp, pngBytes), equals(BlobVerdict.wrongSignature));
      expect(verifyBlob(refJpeg, pngBytes), equals(BlobVerdict.wrongSignature));
    });

    test('wrongSignature for 1-byte and 11-byte WebP and 2-byte JPEG', () {
      final oneByte = Uint8List.fromList([0x52]);
      final refOneByte = _refFor(oneByte, BlobFormat.webp);
      expect(verifyBlob(refOneByte, oneByte), equals(BlobVerdict.wrongSignature));

      final elevenBytes = Uint8List(11);
      elevenBytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
      final refEleven = _refFor(elevenBytes, BlobFormat.webp);
      expect(verifyBlob(refEleven, elevenBytes), equals(BlobVerdict.wrongSignature));

      final twoByteJpeg = Uint8List.fromList([0xFF, 0xD8]);
      final refTwoByte = _refFor(twoByteJpeg, BlobFormat.jpeg);
      expect(verifyBlob(refTwoByte, twoByteJpeg), equals(BlobVerdict.wrongSignature));
    });

    test('wrongHash for flipped byte after signature, middle, and last byte', () {
      final bytes = _makeValidWebp(totalBytes: 50);
      final ref = _refFor(bytes, BlobFormat.webp);

      // Byte immediately after signature (index 12)
      final flipAfterSig = Uint8List.fromList(bytes);
      flipAfterSig[12] ^= 0xFF;
      expect(verifyBlob(ref, flipAfterSig), equals(BlobVerdict.wrongHash));

      // Middle byte (index 25)
      final flipMiddle = Uint8List.fromList(bytes);
      flipMiddle[25] ^= 0xFF;
      expect(verifyBlob(ref, flipMiddle), equals(BlobVerdict.wrongHash));

      // Last byte (index 49)
      final flipLast = Uint8List.fromList(bytes);
      flipLast[49] ^= 0xFF;
      expect(verifyBlob(ref, flipLast), equals(BlobVerdict.wrongHash));
    });
  });

  group('P1: Chunk frame encoding and decoding', () {
    test('round-trip for index 0, 1, 159 with payload of 1 and 65,536 bytes', () {
      const hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final payload1 = Uint8List.fromList([42]);
      final payloadMax = Uint8List(kBlobChunkBytes)..fillRange(0, kBlobChunkBytes, 77);

      for (final index in [0, 1, 159]) {
        for (final payload in [payload1, payloadMax]) {
          final frame = encodeChunkFrame(
            sha256Hex: hash,
            index: index,
            payload: payload,
          );
          final decoded = decodeChunkFrame(frame);
          expect(decoded, isNotNull);
          expect(decoded!.sha256Hex, equals(hash));
          expect(decoded.index, equals(index));
          expect(decoded.payload, equals(payload));
        }
      }
    });

    test('decodeChunkFrame returns null for 36 bytes and for 36 + 65,537 bytes', () {
      final tooShort = Uint8List(36);
      expect(decodeChunkFrame(tooShort), isNull);

      final tooLong = Uint8List(36 + 65537);
      expect(decodeChunkFrame(tooLong), isNull);
    });
  });

  group('P2: Control messages', () {
    const validHash = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    test('want and none round-trip', () {
      final wantEncoded = encodeBlobWant(validHash, [0, 3, 15]);
      final wantDecoded = parseBlobControl(wantEncoded);
      expect(wantDecoded, equals(const BlobWantMessage(sha256Hex: validHash, missingIndices: [0, 3, 15])));

      final noneEncoded = encodeBlobNone(validHash);
      final noneDecoded = parseBlobControl(noneEncoded);
      expect(noneDecoded, equals(const BlobNoneMessage(sha256Hex: validHash)));
    });

    test('parseBlobControl returns null for not JSON', () {
      expect(parseBlobControl('not-json!'), isNull);
    });

    test('parseBlobControl returns null for not an object', () {
      expect(parseBlobControl('["want", "abc"]'), isNull);
    });

    test('parseBlobControl returns null for unknown t', () {
      expect(parseBlobControl(jsonEncode({'t': 'other', 'h': validHash})), isNull);
    });

    test('parseBlobControl returns null for missing or extra keys in none', () {
      expect(parseBlobControl(jsonEncode({'t': 'none'})), isNull); // missing h
      expect(parseBlobControl(jsonEncode({'t': 'none', 'h': validHash, 'extra': 1})), isNull); // extra
    });

    test('parseBlobControl returns null for missing or extra keys in want', () {
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash})), isNull); // missing m
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash, 'm': [0], 'extra': 1})), isNull); // extra
    });

    test('parseBlobControl returns null for bad hash', () {
      expect(parseBlobControl(jsonEncode({'t': 'none', 'h': 'short'})), isNull);
      expect(parseBlobControl(jsonEncode({'t': 'none', 'h': 'G' * 64})), isNull); // invalid hex
      expect(parseBlobControl(jsonEncode({'t': 'none', 'h': validHash.toUpperCase()})), isNull); // uppercase
    });

    test('parseBlobControl returns null for empty m', () {
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash, 'm': []})), isNull);
    });

    test('parseBlobControl returns null for not ascending m', () {
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash, 'm': [2, 1]})), isNull);
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash, 'm': [1, 1]})), isNull); // duplicate
    });

    test('parseBlobControl returns null for negative entry in m', () {
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash, 'm': [-1, 2]})), isNull);
    });

    test('parseBlobControl returns null for non-int entry (10.5) in m', () {
      expect(parseBlobControl('{"t":"want","h":"$validHash","m":[1, 10.5]}'), isNull);
    });

    test('parseBlobControl returns null for more than 160 entries in m', () {
      final list = List.generate(161, (i) => i);
      expect(parseBlobControl(jsonEncode({'t': 'want', 'h': validHash, 'm': list})), isNull);
    });

    test('parseBlobControl returns null for text longer than kBlobMaxControlChars', () {
      final longText = ' ' * (kBlobMaxControlChars + 1);
      expect(parseBlobControl(longText), isNull);
    });
  });

  group('P3: Chunk maths', () {
    test('sizes 1, 65,535, 65,536, 65,537, 131,072 and 10,485,760', () {
      // Size 1: 1 chunk of length 1
      expect(blobChunkCount(1), equals(1));
      expect(blobChunkLength(1, 0), equals(1));

      // Size 65,535: 1 chunk of length 65,535
      expect(blobChunkCount(65535), equals(1));
      expect(blobChunkLength(65535, 0), equals(65535));

      // Size 65,536: 1 chunk of length 65,536
      expect(blobChunkCount(65536), equals(1));
      expect(blobChunkLength(65536, 0), equals(65536));

      // Size 65,537: 2 chunks (65,536 and 1)
      expect(blobChunkCount(65537), equals(2));
      expect(blobChunkLength(65537, 0), equals(65536));
      expect(blobChunkLength(65537, 1), equals(1));

      // Size 131,072: 2 chunks (65,536 and 65,536)
      expect(blobChunkCount(131072), equals(2));
      expect(blobChunkLength(131072, 0), equals(65536));
      expect(blobChunkLength(131072, 1), equals(65536));

      // Size 10,485,760 (10 MiB): 160 chunks, last one 65,536
      expect(blobChunkCount(10485760), equals(160));
      expect(blobChunkLength(10485760, 0), equals(65536));
      expect(blobChunkLength(10485760, 159), equals(65536));
    });
  });
}
