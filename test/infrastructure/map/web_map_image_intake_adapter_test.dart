@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_verifier.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/map/web/web_map_image_intake_adapter.dart';

const String _kPlantedMarker = 'DN5E_PLANTED_MARKER';

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return (~crc) & 0xFFFFFFFF;
}

bool _containsMarker(Uint8List haystack, String marker) {
  final needle = utf8.encode(marker);
  if (needle.isEmpty || haystack.length < needle.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

Future<Uint8List> _renderCanvasBytes(int width, int height, String mimeType) async {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  canvas.width = width;
  canvas.height = height;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx.fillStyle = '#00FF00'.toJS;
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#FF0000'.toJS;
  ctx.fillRect(width ~/ 4, height ~/ 4, width ~/ 2, height ~/ 2);

  final completer = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? b) => completer.complete(b)).toJS,
    mimeType,
    0.9.toJS,
  );
  final blob = await completer.future;
  canvas.width = 0;
  canvas.height = 0;
  final buf = await blob!.arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}

WebMapImageSource _makeSourceFromBytes(Uint8List bytes, String filename, String mimeType) {
  final file = web.File([bytes.toJS].toJS, filename, web.FilePropertyBag(type: mimeType));
  return WebMapImageSource(file);
}

void main() {
  const adapter = MapImageIntakeAdapter();

  group('WebMapImageIntakeAdapter', () {
    test('I1: 6,000 x 3,000 PNG -> output 4,096 x 2,048, format webp, verifyBlob ok', () async {
      final raw = await _renderCanvasBytes(6000, 3000, 'image/png');
      final source = _makeSourceFromBytes(raw, 'big.png', 'image/png');

      final out = await adapter.normalize(
        source,
        targetWidth: 4096,
        targetHeight: 2048,
      ).timeout(const Duration(seconds: 10));

      expect(out.width, equals(4096));
      expect(out.height, equals(2048));
      expect(out.format, equals(BlobFormat.webp));

      final hash = sha256.convert(out.bytes).toString().toLowerCase();
      final ref = BlobRef(
        sha256Hex: hash,
        byteSize: out.bytes.length,
        width: out.width,
        height: out.height,
        format: out.format,
      );
      expect(verifyBlob(ref, out.bytes), equals(BlobVerdict.ok));
    });

    test('I2: 1,000 x 800 JPEG -> output 1,000 x 800, never larger', () async {
      final raw = await _renderCanvasBytes(1000, 800, 'image/jpeg');
      final source = _makeSourceFromBytes(raw, 'photo.jpg', 'image/jpeg');

      final out = await adapter.normalize(
        source,
        targetWidth: 1000,
        targetHeight: 800,
      ).timeout(const Duration(seconds: 10));

      expect(out.width, equals(1000));
      expect(out.height, equals(800));
    });

    test('I3: planted metadata is completely removed in output', () async {
      // 1. PNG with tEXt chunk holding marker
      final pngBytes = await _renderCanvasBytes(200, 200, 'image/png');
      final textChunkData = utf8.encode('Comment\x00$_kPlantedMarker');
      final textChunkType = utf8.encode('tEXt');
      final crcPayload = <int>[...textChunkType, ...textChunkData];
      final crc = _crc32(crcPayload);

      final pngWithText = BytesBuilder();
      // Write PNG header + IHDR
      pngWithText.add(pngBytes.sublist(0, 33));
      // Write tEXt chunk: length, type, data, crc
      final tLenBd = ByteData(4)..setUint32(0, textChunkData.length);
      final tCrcBd = ByteData(4)..setUint32(0, crc);
      pngWithText.add(tLenBd.buffer.asUint8List());
      pngWithText.add(textChunkType);
      pngWithText.add(textChunkData);
      pngWithText.add(tCrcBd.buffer.asUint8List());
      pngWithText.add(pngBytes.sublist(33));

      final pngSource = _makeSourceFromBytes(pngWithText.toBytes(), 'metadata.png', 'image/png');
      expect(_containsMarker(pngWithText.toBytes(), _kPlantedMarker), isTrue);
      final pngOut = await adapter.normalize(pngSource, targetWidth: 200, targetHeight: 200).timeout(const Duration(seconds: 10));
      expect(_containsMarker(pngOut.bytes, _kPlantedMarker), isFalse);

      // 2. JPEG with APP1 Exif segment holding marker
      final jpegBytes = await _renderCanvasBytes(200, 200, 'image/jpeg');
      final exifPayload = utf8.encode('Exif\x00\x00$_kPlantedMarker');
      final jpegWithExif = BytesBuilder();
      jpegWithExif.add([0xFF, 0xD8]); // SOI
      jpegWithExif.add([0xFF, 0xE1]); // APP1
      final exifLenBd = ByteData(2)..setUint16(0, 2 + exifPayload.length);
      jpegWithExif.add(exifLenBd.buffer.asUint8List());
      jpegWithExif.add(exifPayload);
      jpegWithExif.add(jpegBytes.sublist(2));

      final jpegSource = _makeSourceFromBytes(jpegWithExif.toBytes(), 'metadata.jpg', 'image/jpeg');
      expect(_containsMarker(jpegWithExif.toBytes(), _kPlantedMarker), isTrue);
      final jpegOut = await adapter.normalize(jpegSource, targetWidth: 200, targetHeight: 200).timeout(const Duration(seconds: 10));
      expect(_containsMarker(jpegOut.bytes, _kPlantedMarker), isFalse);

      // 3. PNG with marker appended after IEND
      final pngTrailing = BytesBuilder();
      pngTrailing.add(pngBytes);
      pngTrailing.add(utf8.encode(_kPlantedMarker));
      final pngTrailingSource = _makeSourceFromBytes(pngTrailing.toBytes(), 'trailing.png', 'image/png');
      expect(_containsMarker(pngTrailing.toBytes(), _kPlantedMarker), isTrue);
      final pngTrailingOut = await adapter.normalize(pngTrailingSource, targetWidth: 200, targetHeight: 200).timeout(const Duration(seconds: 10));
      expect(_containsMarker(pngTrailingOut.bytes, _kPlantedMarker), isFalse);

      // 4. WebP with marker appended after RIFF data
      final webpBytes = await _renderCanvasBytes(200, 200, 'image/webp');
      final webpTrailing = BytesBuilder();
      webpTrailing.add(webpBytes);
      webpTrailing.add(utf8.encode(_kPlantedMarker));
      final webpTrailingSource = _makeSourceFromBytes(webpTrailing.toBytes(), 'trailing.webp', 'image/webp');
      expect(_containsMarker(webpTrailing.toBytes(), _kPlantedMarker), isTrue);
      final webpTrailingOut = await adapter.normalize(webpTrailingSource, targetWidth: 200, targetHeight: 200).timeout(const Duration(seconds: 10));
      expect(_containsMarker(webpTrailingOut.bytes, _kPlantedMarker), isFalse);
    });

    test('I4: PNG input -> output is never PNG (format is webp or jpeg, signature matches)', () async {
      final raw = await _renderCanvasBytes(400, 300, 'image/png');
      final source = _makeSourceFromBytes(raw, 'drawing.png', 'image/png');

      final out = await adapter.normalize(
        source,
        targetWidth: 400,
        targetHeight: 300,
      ).timeout(const Duration(seconds: 10));

      expect(out.format, anyOf(equals(BlobFormat.webp), equals(BlobFormat.jpeg)));
      if (out.format == BlobFormat.webp) {
        expect(out.bytes.sublist(0, 4), equals([0x52, 0x49, 0x46, 0x46]));
        expect(out.bytes.sublist(8, 12), equals([0x57, 0x45, 0x42, 0x50]));
      } else {
        expect(out.bytes.sublist(0, 3), equals([0xFF, 0xD8, 0xFF]));
      }
    });

    test('I5: Safari path: toBlob webp -> png causes jpeg fallback; control throws encoderMismatch', () async {
      final raw = await _renderCanvasBytes(200, 200, 'image/png');
      final source = _makeSourceFromBytes(raw, 'test.png', 'image/png');
      final canvasCtor = (web.window as JSObject).getProperty<JSObject>('HTMLCanvasElement'.toJS);
      final proto = canvasCtor.getProperty<JSObject>('prototype'.toJS);
      final origToBlob = proto.getProperty<JSFunction>('toBlob'.toJS);

      final jsFnCtor = (web.window as JSObject).getProperty<JSFunction>('Function'.toJS);
      final wrapperMaker = jsFnCtor.callAsFunction(
        web.window,
        'orig'.toJS,
        'return function(cb, type, quality) { var actual = window.__safariTurnAllPng || (type === "image/webp") ? "image/png" : type; return orig.call(this, cb, actual, quality); };'.toJS,
      ) as JSFunction;
      final toBlobWrapper = wrapperMaker.callAsFunction(web.window, origToBlob) as JSFunction;

      try {
        proto.setProperty('toBlob'.toJS, toBlobWrapper);

        final out = await adapter.normalize(
          source,
          targetWidth: 200,
          targetHeight: 200,
        ).timeout(const Duration(seconds: 10));

        expect(out.format, equals(BlobFormat.jpeg));
        expect(out.bytes.sublist(0, 3), equals([0xFF, 0xD8, 0xFF]));

        // Control: also turns image/jpeg into PNG -> throws encoderMismatch
        (web.window as JSObject).setProperty('__safariTurnAllPng'.toJS, true.toJS);

        await expectLater(
          adapter.normalize(source, targetWidth: 200, targetHeight: 200).timeout(const Duration(seconds: 10)),
          throwsA(predicate<MapIntakeRejected>((e) => e.reason == MapRejectReason.encoderMismatch)),
        );
      } finally {
        proto.setProperty('toBlob'.toJS, origToBlob);
        (web.window as JSObject).delete('__safariTurnAllPng'.toJS);
      }
    });

    test('I6: bytes starting with valid PNG header followed by garbage -> undecodable', () async {
      final b = BytesBuilder();
      b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // PNG header
      // Add garbage bytes
      final rng = Random(1234);
      b.add(Uint8List.fromList(List.generate(200, (_) => rng.nextInt(256))));
      final badSource = _makeSourceFromBytes(b.toBytes(), 'corrupt.png', 'image/png');

      await expectLater(
        adapter.normalize(badSource, targetWidth: 100, targetHeight: 100).timeout(const Duration(seconds: 10)),
        throwsA(predicate<MapIntakeRejected>((e) => e.reason == MapRejectReason.undecodable)),
      );
    });

    test('I7: AVIF fixture decodes to WebP output of same size', () async {
      // 323-byte real AVIF fixture generated with:
      // ffmpeg -y -f lavfi -i color=c=blue:s=64x64:d=1 -frames:v 1 -c:v libaom-av1 test/fixtures/map_intake/sample.avif
      const avifBase64 =
          'AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAAD5bWV0YQAAAAAAAAAvaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAFBpY3R1cmVIYW5kbGVyAAAAAA5waXRtAAAAAAABAAAAHmlsb2MAAAAARAAAAQABAAAAAQAAASEAAAAiAAAAKGlpbmYAAAAAAAEAAAAaaW5mZQIAAAAAAQAAYXYwMUNvbG9yAAAAAGppcHJwAAAAS2lwY28AAAAUaXNwZQAAAAAAAABAAAAAQAAAABBwaXhpAAAAAAMICAgAAAAMYXYxQ4EADAAAAAATY29scm5jbHgAAgACAAIAAAAAF2lwbWEAAAAAAAAAAQABBAECgwQAAAAqbWRhdAoKAAAAAq//n18wCDIUEADAAAACgAAACgV2pNYvH/oePNg=';
      final avifBytes = base64Decode(avifBase64);
      final avifSource = _makeSourceFromBytes(avifBytes, 'sample.avif', 'image/avif');

      final out = await adapter.normalize(
        avifSource,
        targetWidth: 64,
        targetHeight: 64,
      ).timeout(const Duration(seconds: 10));

      expect(out.width, equals(64));
      expect(out.height, equals(64));
      expect(out.format, equals(BlobFormat.webp));
    });

    test('I8: readRange returns exact requested bytes for (0, 32), (10, 20), (byteSize - 4, byteSize)', () async {
      final data = Uint8List.fromList(List.generate(100, (i) => i));
      final source = _makeSourceFromBytes(data, 'test.bin', 'application/octet-stream');

      final r1 = await source.readRange(0, 32);
      expect(r1, equals(data.sublist(0, 32)));

      final r2 = await source.readRange(10, 20);
      expect(r2, equals(data.sublist(10, 20)));

      final r3 = await source.readRange(source.byteSize - 4, source.byteSize);
      expect(r3, equals(data.sublist(96, 100)));
    });
  });
}
