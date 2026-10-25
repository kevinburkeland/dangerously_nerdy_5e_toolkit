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
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_header.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_intake_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/map/web/web_map_image_intake_adapter.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';

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

Uint8List _buildTiffExif(int orientation, {bool littleEndian = true}) {
  final b = BytesBuilder();
  final endian = littleEndian ? Endian.little : Endian.big;
  if (littleEndian) {
    b.add([0x49, 0x49, 0x2A, 0x00]); // II*\0
  } else {
    b.add([0x4D, 0x4D, 0x00, 0x2A]); // MM\0*
  }
  final ifdOffsetBd = ByteData(4);
  ifdOffsetBd.setUint32(0, 8, endian);
  b.add(ifdOffsetBd.buffer.asUint8List());

  final ifdBd = ByteData(2 + 12);
  ifdBd.setUint16(0, 1, endian);
  ifdBd.setUint16(2, 0x0112, endian);
  ifdBd.setUint16(4, 3, endian);
  ifdBd.setUint32(6, 1, endian);
  ifdBd.setUint16(10, orientation, endian);
  ifdBd.setUint16(12, 0, endian);
  b.add(ifdBd.buffer.asUint8List());
  return b.toBytes();
}

Future<Uint8List> _renderSplitCanvasBytes(int width, int height, String mimeType) async {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  canvas.width = width;
  canvas.height = height;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx.fillStyle = '#FF0000'.toJS; // Red left half
  ctx.fillRect(0, 0, width ~/ 2, height);
  ctx.fillStyle = '#0000FF'.toJS; // Blue right half
  ctx.fillRect(width ~/ 2, 0, width - width ~/ 2, height);

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

Uint8List _spliceJpegExif(Uint8List jpegBytes, int orientation, {bool littleEndian = true}) {
  final tiff = _buildTiffExif(orientation, littleEndian: littleEndian);
  final b = BytesBuilder();
  b.add(jpegBytes.sublist(0, 2)); // SOI
  b.add([0xFF, 0xE1]);
  final segLen = 2 + 6 + tiff.length;
  final lenBd = ByteData(2);
  lenBd.setUint16(0, segLen);
  b.add(lenBd.buffer.asUint8List());
  b.add([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]);
  b.add(tiff);
  b.add(jpegBytes.sublist(2));
  return b.toBytes();
}

Uint8List _splicePngExif(Uint8List pngBytes, int orientation, {bool afterIdat = false}) {
  final tiff = _buildTiffExif(orientation);
  final exifChunk = BytesBuilder();
  final lenBd = ByteData(4);
  lenBd.setUint32(0, tiff.length);
  exifChunk.add(lenBd.buffer.asUint8List());
  final typeBytes = [0x65, 0x58, 0x49, 0x66]; // eXIf
  exifChunk.add(typeBytes);
  exifChunk.add(tiff);
  final crcBd = ByteData(4);
  crcBd.setUint32(0, _crc32([...typeBytes, ...tiff]));
  exifChunk.add(crcBd.buffer.asUint8List());
  final exifChunkBytes = exifChunk.toBytes();

  final b = BytesBuilder();
  if (afterIdat) {
    var idatEnd = -1;
    for (var i = 8; i < pngBytes.length - 8; i++) {
      if (pngBytes[i + 4] == 0x49 &&
          pngBytes[i + 5] == 0x44 &&
          pngBytes[i + 6] == 0x41 &&
          pngBytes[i + 7] == 0x54) {
        final bd = ByteData.view(pngBytes.buffer, pngBytes.offsetInBytes);
        final cLen = bd.getUint32(i);
        idatEnd = i + 8 + cLen + 4;
        break;
      }
    }
    b.add(pngBytes.sublist(0, idatEnd));
    b.add(exifChunkBytes);
    b.add(pngBytes.sublist(idatEnd));
  } else {
    b.add(pngBytes.sublist(0, 33));
    b.add(exifChunkBytes);
    b.add(pngBytes.sublist(33));
  }
  return b.toBytes();
}

Uint8List _spliceWebpExif(Uint8List webpBytes, int orientation, {int width = 400, int height = 200}) {
  final tiff = _buildTiffExif(orientation);
  final fourcc = String.fromCharCodes(webpBytes.sublist(12, 16));

  final exifChunk = BytesBuilder();
  exifChunk.add([0x45, 0x58, 0x49, 0x46]);
  final exifLen = ByteData(4)..setUint32(0, tiff.length, Endian.little);
  exifChunk.add(exifLen.buffer.asUint8List());
  exifChunk.add(tiff);
  if (tiff.length.isOdd) {
    exifChunk.add([0x00]);
  }
  final exifChunkBytes = exifChunk.toBytes();

  if (fourcc == 'VP8X') {
    final copy = Uint8List.fromList(webpBytes);
    copy[20] |= 0x08;

    final b = BytesBuilder();
    b.add(copy);
    b.add(exifChunkBytes);
    final res = b.toBytes();

    ByteData.view(res.buffer).setUint32(4, res.length - 8, Endian.little);
    return res;
  } else {
    final wMinus1 = width - 1;
    final hMinus1 = height - 1;

    final b = BytesBuilder();
    b.add([0x52, 0x49, 0x46, 0x46]);
    const vp8xSize = 8 + 10;
    final vp8DataSize = webpBytes.length - 12;
    final totalRiffSize = 4 + vp8xSize + vp8DataSize + exifChunkBytes.length;
    final rLenBd = ByteData(4)..setUint32(0, totalRiffSize, Endian.little);
    b.add(rLenBd.buffer.asUint8List());
    b.add([0x57, 0x45, 0x42, 0x50]);

    b.add([0x56, 0x50, 0x38, 0x58]);
    final vp8xLen = ByteData(4)..setUint32(0, 10, Endian.little);
    b.add(vp8xLen.buffer.asUint8List());
    b.add([0x08, 0x00, 0x00, 0x00]);
    b.add([wMinus1 & 0xFF, (wMinus1 >> 8) & 0xFF, (wMinus1 >> 16) & 0xFF]);
    b.add([hMinus1 & 0xFF, (hMinus1 >> 8) & 0xFF, (hMinus1 >> 16) & 0xFF]);

    b.add(webpBytes.sublist(12));
    b.add(exifChunkBytes);

    return b.toBytes();
  }
}

Uint8List _buildRotatedAvif({
  int? irotAngle,
  bool useImir = false,
  int associatedItemId = 1,
}) {
  const base64Avif =
      'AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAAD5bWV0YQAAAAAAAAAvaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAFBpY3R1cmVIYW5kbGVyAAAAAA5waXRtAAAAAAABAAAAHmlsb2MAAAAARAAAAQABAAAAAQAAASEAAAAmAAAAKGlpbmYAAAAAAAEAAAAaaW5mZQIAAAAAAQAAYXYwMUNvbG9yAAAAAGppcHJwAAAAS2lwY28AAAAUaXNwZQAAAAAAAABAAAAAIAAAABBwaXhpAAAAAAMICAgAAAAMYXYxQ4EADAAAAAATY29scm5jbHgAAgACAAIAAAAAF2lwbWEAAAAAAAAAAQABBAECgwQAAAAubWRhdAoGGBU/+2AQMhwYAAAAUAAAALNXJX+abv+Ty52isD92RpTZ+DQO';
  final raw = base64Decode(base64Avif);
  if (irotAngle == null && !useImir) {
    return raw;
  }
  final d = Uint8List.fromList(raw);
  final bd = ByteData.view(d.buffer);

  final propBox = BytesBuilder();
  final boxLen = ByteData(4);
  boxLen.setUint32(0, 9);
  propBox.add(boxLen.buffer.asUint8List());
  if (useImir) {
    propBox.add([0x69, 0x6D, 0x69, 0x72]);
    propBox.add([0x00]);
  } else {
    propBox.add([0x69, 0x72, 0x6F, 0x74]);
    propBox.add([irotAngle! & 0x03]);
  }
  final propBytes = propBox.toBytes();

  var ipcoEnd = -1;
  for (var i = 0; i < d.length - 8; i++) {
    if (d[i] == 0x69 && d[i + 1] == 0x70 && d[i + 2] == 0x63 && d[i + 3] == 0x6F) {
      final ipcoSize = bd.getUint32(i - 4);
      ipcoEnd = (i - 4) + ipcoSize;
      break;
    }
  }

  final out = BytesBuilder();
  out.add(d.sublist(0, ipcoEnd));
  out.add(propBytes);
  final afterIpco = d.sublist(ipcoEnd);
  out.add(afterIpco);
  final res = out.toBytes();
  final resBd = ByteData.view(res.buffer);

  var ipmaOffset = -1;
  for (var i = 0; i < res.length - 8; i++) {
    if (res[i] == 0x69 && res[i + 1] == 0x70 && res[i + 2] == 0x6D && res[i + 3] == 0x61) {
      ipmaOffset = i - 4;
      break;
    }
  }

  if (associatedItemId != 1) {
    resBd.setUint16(ipmaOffset + 16, associatedItemId);
  }
  res[ipmaOffset + 18] = 5;

  final oldIpmaSize = resBd.getUint32(ipmaOffset);
  final ipmaInsertPoint = ipmaOffset + oldIpmaSize;
  final finalOut = BytesBuilder();
  finalOut.add(res.sublist(0, ipmaInsertPoint));
  finalOut.add([0x85]); // essential bit set for transformative property
  finalOut.add(res.sublist(ipmaInsertPoint));
  final finalBytes = finalOut.toBytes();
  final finalBd = ByteData.view(finalBytes.buffer);

  final metaSize = finalBd.getUint32(32);
  finalBd.setUint32(32, metaSize + 10);

  final extentOffset = finalBd.getUint32(127);
  finalBd.setUint32(127, extentOffset + 10);

  for (var i = 0; i < finalBytes.length - 8; i++) {
    if (finalBytes[i] == 0x69 && finalBytes[i + 1] == 0x70 && finalBytes[i + 2] == 0x72 && finalBytes[i + 3] == 0x70) {
      final iprpSize = finalBd.getUint32(i - 4);
      finalBd.setUint32(i - 4, iprpSize + 10);
      break;
    }
  }

  for (var i = 0; i < finalBytes.length - 8; i++) {
    if (finalBytes[i] == 0x69 && finalBytes[i + 1] == 0x70 && finalBytes[i + 2] == 0x63 && finalBytes[i + 3] == 0x6F) {
      final ipcoSize = finalBd.getUint32(i - 4);
      finalBd.setUint32(i - 4, ipcoSize + 9);
      break;
    }
  }

  finalBd.setUint32(ipmaOffset, oldIpmaSize + 1);
  return finalBytes;
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

    test('OR8: the browser law: header matches createImageBitmap for all 16 rotation fixtures', () async {
      final baseJpeg = await _renderSplitCanvasBytes(400, 200, 'image/jpeg');
      final basePng = await _renderSplitCanvasBytes(400, 200, 'image/png');
      final baseWebp = await _renderSplitCanvasBytes(400, 200, 'image/webp');

      final fixtures = <({String name, Uint8List bytes, String mime})>[];

      for (var o = 1; o <= 8; o++) {
        fixtures.add((
          name: 'JPEG orientation $o',
          bytes: _spliceJpegExif(baseJpeg, o),
          mime: 'image/jpeg',
        ));
      }
      fixtures.add((
        name: 'PNG eXIf 6 before IDAT',
        bytes: _splicePngExif(basePng, 6, afterIdat: false),
        mime: 'image/png',
      ));
      fixtures.add((
        name: 'PNG eXIf 6 after IDAT',
        bytes: _splicePngExif(basePng, 6, afterIdat: true),
        mime: 'image/png',
      ));
      fixtures.add((
        name: 'WebP with EXIF 6',
        bytes: _spliceWebpExif(baseWebp, 6),
        mime: 'image/webp',
      ));
      for (var a = 0; a <= 3; a++) {
        fixtures.add((
          name: 'AVIF irot $a',
          bytes: _buildRotatedAvif(irotAngle: a),
          mime: 'image/avif',
        ));
      }
      fixtures.add((
        name: 'AVIF imir',
        bytes: _buildRotatedAvif(useImir: true),
        mime: 'image/avif',
      ));

      for (final f in fixtures) {
        final header = await readMapImageHeader(
          (s, e) async => f.bytes.sublist(s, e),
          f.bytes.length,
        );

        final file = web.File([f.bytes.toJS].toJS, 'fixture', web.FilePropertyBag(type: f.mime));
        final bitmap = await web.window.createImageBitmap(file).toDart;
        final bW = bitmap.width;
        final bH = bitmap.height;
        bitmap.close();

        // ignore: avoid_print
        print('OR8: ${f.name} -> header: ${header.width}x${header.height}, browser: ${bW}x$bH');

        if (header.width != bW || header.height != bH) {
          fail('OR8 mismatch on ${f.name}: header=${header.width}x${header.height}, browser=${bW}x$bH');
        }
      }
      // ignore: avoid_print
      print('OR8 browser law completed: all ${fixtures.length} fixtures match browser dimensions.');
    });

    test('OR9: end-to-end MapIntakeService with orientation 6 JPEG, orientation 8 JPEG, and irot 1 AVIF', () async {
      final store = FakeBlobStore();
      final repo = FakeCampaignRepository(
        CampaignProfile.initial(id: 'c1', name: 'Test Campaign', nodeId: 'test-node'),
      );
      final clock = StatefulHlcClock(
        replicaId: ReplicaId('test-node'),
        timeProvider: () => 1700000000000,
      );
      final service = MapIntakeService(
        intake: adapter,
        store: store,
        campaignRepo: repo,
        clock: clock,
      );

      final baseJpeg = await _renderSplitCanvasBytes(400, 200, 'image/jpeg');

      // 1. Orientation 6 JPEG
      final jpeg6Bytes = _spliceJpegExif(baseJpeg, 6);
      final source6 = _makeSourceFromBytes(jpeg6Bytes, 'photo6.jpg', 'image/jpeg');
      final res6 = await service.setMapFromSource(source6, campaignId: 'c1').timeout(const Duration(seconds: 10));

      expect(res6.ref.width, equals(200));
      expect(res6.ref.height, equals(400));
      expect(res6.originalWidth, equals(200));
      expect(res6.originalHeight, equals(400));

      final stored6 = await store.get(res6.ref.sha256Hex);
      final blob6 = web.Blob([stored6.bytes.toJS].toJS);
      final bm6 = await web.window.createImageBitmap(blob6).toDart;
      final canvas6 = web.document.createElement('canvas') as web.HTMLCanvasElement;
      canvas6.width = bm6.width;
      canvas6.height = bm6.height;
      final ctx6 = canvas6.getContext('2d') as web.CanvasRenderingContext2D;
      ctx6.drawImage(bm6, 0, 0);
      bm6.close();

      final topPixel6 = ctx6.getImageData(canvas6.width ~/ 2, (canvas6.height * 0.2).toInt(), 1, 1).data.toDart;
      final bottomPixel6 = ctx6.getImageData(canvas6.width ~/ 2, (canvas6.height * 0.8).toInt(), 1, 1).data.toDart;
      // Orientation 6 rotated 90 deg clockwise: left half (red) is top, right half (blue) is bottom
      expect(topPixel6[0], greaterThan(150), reason: 'red near top');
      expect(topPixel6[2], lessThan(100));
      expect(bottomPixel6[2], greaterThan(150), reason: 'blue near bottom');
      expect(bottomPixel6[0], lessThan(100));

      // 2. Orientation 8 JPEG
      final jpeg8Bytes = _spliceJpegExif(baseJpeg, 8);
      final source8 = _makeSourceFromBytes(jpeg8Bytes, 'photo8.jpg', 'image/jpeg');
      final res8 = await service.setMapFromSource(source8, campaignId: 'c1').timeout(const Duration(seconds: 10));

      expect(res8.ref.width, equals(200));
      expect(res8.ref.height, equals(400));

      final stored8 = await store.get(res8.ref.sha256Hex);
      final blob8 = web.Blob([stored8.bytes.toJS].toJS);
      final bm8 = await web.window.createImageBitmap(blob8).toDart;
      final canvas8 = web.document.createElement('canvas') as web.HTMLCanvasElement;
      canvas8.width = bm8.width;
      canvas8.height = bm8.height;
      final ctx8 = canvas8.getContext('2d') as web.CanvasRenderingContext2D;
      ctx8.drawImage(bm8, 0, 0);
      bm8.close();

      final topPixel8 = ctx8.getImageData(canvas8.width ~/ 2, (canvas8.height * 0.2).toInt(), 1, 1).data.toDart;
      final bottomPixel8 = ctx8.getImageData(canvas8.width ~/ 2, (canvas8.height * 0.8).toInt(), 1, 1).data.toDart;
      // Orientation 8 rotated 270 deg clockwise: left half (red) is bottom, right half (blue) is top
      expect(topPixel8[2], greaterThan(150), reason: 'blue near top');
      expect(topPixel8[0], lessThan(100));
      expect(bottomPixel8[0], greaterThan(150), reason: 'red near bottom');
      expect(bottomPixel8[2], lessThan(100));

      // 3. irot 1 AVIF gives 32 x 64
      final avif1Bytes = _buildRotatedAvif(irotAngle: 1);
      final sourceAvif = _makeSourceFromBytes(avif1Bytes, 'map.avif', 'image/avif');
      final resAvif = await service.setMapFromSource(sourceAvif, campaignId: 'c1').timeout(const Duration(seconds: 10));
      expect(resAvif.ref.width, equals(32));
      expect(resAvif.ref.height, equals(64));
    });

    test('OR10: normalize with wrong target throws orientationMismatch; control with correct target succeeds', () async {
      final baseJpeg = await _renderSplitCanvasBytes(400, 200, 'image/jpeg');
      final jpeg6Bytes = _spliceJpegExif(baseJpeg, 6);
      final source6 = _makeSourceFromBytes(jpeg6Bytes, 'photo6.jpg', 'image/jpeg');

      // Calling normalize with targetWidth: 400, targetHeight: 200 throws orientationMismatch
      await expectLater(
        adapter.normalize(source6, targetWidth: 400, targetHeight: 200).timeout(const Duration(seconds: 10)),
        throwsA(predicate<MapIntakeRejected>((e) => e.reason == MapRejectReason.orientationMismatch)),
      );

      // Control: calling normalize with targetWidth: 200, targetHeight: 400 succeeds
      final out = await adapter.normalize(
        source6,
        targetWidth: 200,
        targetHeight: 400,
      ).timeout(const Duration(seconds: 10));
      expect(out.width, equals(200));
      expect(out.height, equals(400));
    });
  });
}
