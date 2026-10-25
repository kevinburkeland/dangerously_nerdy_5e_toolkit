import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_header.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';

Uint8List _buildPng(int width, int height) {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // PNG sig
  final bd = ByteData(17);
  bd.setUint32(0, 13); // IHDR length
  bd.setUint8(4, 0x49); // I
  bd.setUint8(5, 0x48); // H
  bd.setUint8(6, 0x44); // D
  bd.setUint8(7, 0x52); // R
  bd.setUint32(8, width);
  bd.setUint32(12, height);
  bd.setUint8(16, 8); // depth
  b.add(bd.buffer.asUint8List());
  b.add([0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // color, comp, filter, interlace, CRC
  return b.toBytes();
}

Uint8List _buildJpeg(int width, int height, {List<int> appSegmentSizes = const [4, 4]}) {
  final b = BytesBuilder();
  b.add([0xFF, 0xD8]); // SOI
  for (var i = 0; i < appSegmentSizes.length; i++) {
    final segSize = appSegmentSizes[i];
    b.add([0xFF, 0xE0 + (i % 16)]); // APP marker
    final bd = ByteData(2);
    bd.setUint16(0, segSize);
    b.add(bd.buffer.asUint8List());
    if (segSize > 2) {
      b.add(Uint8List(segSize - 2));
    }
  }
  b.add([0xFF, 0xC0]); // SOF0
  final sofBd = ByteData(9);
  sofBd.setUint16(0, 9); // segLen = 9 (2 len + 1 prec + 2 h + 2 w + 2 comp)
  sofBd.setUint8(2, 8); // precision
  sofBd.setUint16(3, height);
  sofBd.setUint16(5, width);
  sofBd.setUint8(7, 3); // components
  b.add(sofBd.buffer.asUint8List());
  return b.toBytes();
}

Uint8List _buildWebpVp8(int width, int height) {
  final b = BytesBuilder();
  b.add([0x52, 0x49, 0x46, 0x46]); // RIFF
  final lenBd = ByteData(4);
  lenBd.setUint32(0, 30, Endian.little);
  b.add(lenBd.buffer.asUint8List());
  b.add([0x57, 0x45, 0x42, 0x50]); // WEBP
  b.add([0x56, 0x50, 0x38, 0x20]); // 'VP8 '
  final vp8LenBd = ByteData(4);
  vp8LenBd.setUint32(0, 10, Endian.little);
  b.add(vp8LenBd.buffer.asUint8List());
  b.add([0x00, 0x00, 0x00]); // 3-byte frame tag
  b.add([0x9D, 0x01, 0x2A]); // start code
  final dimBd = ByteData(4);
  dimBd.setUint16(0, width & 0x3FFF, Endian.little);
  dimBd.setUint16(2, height & 0x3FFF, Endian.little);
  b.add(dimBd.buffer.asUint8List());
  return b.toBytes();
}

Uint8List _buildWebpVp8L(int width, int height) {
  final b = BytesBuilder();
  b.add([0x52, 0x49, 0x46, 0x46]); // RIFF
  final lenBd = ByteData(4);
  lenBd.setUint32(0, 30, Endian.little);
  b.add(lenBd.buffer.asUint8List());
  b.add([0x57, 0x45, 0x42, 0x50]); // WEBP
  b.add([0x56, 0x50, 0x38, 0x4C]); // 'VP8L'
  final vp8lLenBd = ByteData(4);
  vp8lLenBd.setUint32(0, 5, Endian.little);
  b.add(vp8lLenBd.buffer.asUint8List());
  b.add([0x2F]); // signature
  final val = ((width - 1) & 0x3FFF) | (((height - 1) & 0x3FFF) << 14);
  final valBd = ByteData(4);
  valBd.setUint32(0, val, Endian.little);
  b.add(valBd.buffer.asUint8List());
  return b.toBytes();
}

Uint8List _buildWebpVp8X(int width, int height) {
  final b = BytesBuilder();
  b.add([0x52, 0x49, 0x46, 0x46]); // RIFF
  final lenBd = ByteData(4);
  lenBd.setUint32(0, 30, Endian.little);
  b.add(lenBd.buffer.asUint8List());
  b.add([0x57, 0x45, 0x42, 0x50]); // WEBP
  b.add([0x56, 0x50, 0x38, 0x58]); // 'VP8X'
  final vp8xLenBd = ByteData(4);
  vp8xLenBd.setUint32(0, 10, Endian.little);
  b.add(vp8xLenBd.buffer.asUint8List());
  b.add([0x00, 0x00, 0x00, 0x00]); // flags
  final wMinus1 = width - 1;
  final hMinus1 = height - 1;
  b.add([wMinus1 & 0xFF, (wMinus1 >> 8) & 0xFF, (wMinus1 >> 16) & 0xFF]);
  b.add([hMinus1 & 0xFF, (hMinus1 >> 8) & 0xFF, (hMinus1 >> 16) & 0xFF]);
  return b.toBytes();
}

Uint8List _buildAvif(List<({int width, int height})> ispeBoxes) {
  // Build ispe boxes
  final ispeBuilder = BytesBuilder();
  for (final box in ispeBoxes) {
    final bd = ByteData(20);
    bd.setUint32(0, 20); // size = 20
    bd.setUint8(4, 0x69); // i
    bd.setUint8(5, 0x73); // s
    bd.setUint8(6, 0x70); // p
    bd.setUint8(7, 0x65); // e
    bd.setUint32(8, 0); // version/flags
    bd.setUint32(12, box.width);
    bd.setUint32(16, box.height);
    ispeBuilder.add(bd.buffer.asUint8List());
  }
  final ispeBytes = ispeBuilder.toBytes();

  // ipco box
  final ipcoBuilder = BytesBuilder();
  final ipcoBd = ByteData(8);
  ipcoBd.setUint32(0, 8 + ispeBytes.length);
  ipcoBd.setUint8(4, 0x69); ipcoBd.setUint8(5, 0x70); ipcoBd.setUint8(6, 0x63); ipcoBd.setUint8(7, 0x6F); // ipco
  ipcoBuilder.add(ipcoBd.buffer.asUint8List());
  ipcoBuilder.add(ispeBytes);
  final ipcoBytes = ipcoBuilder.toBytes();

  // iprp box
  final iprpBuilder = BytesBuilder();
  final iprpBd = ByteData(8);
  iprpBd.setUint32(0, 8 + ipcoBytes.length);
  iprpBd.setUint8(4, 0x69); iprpBd.setUint8(5, 0x70); iprpBd.setUint8(6, 0x72); iprpBd.setUint8(7, 0x70); // iprp
  iprpBuilder.add(iprpBd.buffer.asUint8List());
  iprpBuilder.add(ipcoBytes);
  final iprpBytes = iprpBuilder.toBytes();

  // meta box (FullBox: 8-byte header + 4-byte version/flags)
  final metaBuilder = BytesBuilder();
  final metaBd = ByteData(12);
  metaBd.setUint32(0, 12 + iprpBytes.length);
  metaBd.setUint8(4, 0x6D); metaBd.setUint8(5, 0x65); metaBd.setUint8(6, 0x74); metaBd.setUint8(7, 0x61); // meta
  metaBd.setUint32(8, 0); // version & flags
  metaBuilder.add(metaBd.buffer.asUint8List());
  metaBuilder.add(iprpBytes);
  final metaBytes = metaBuilder.toBytes();

  // ftyp box
  final ftypBuilder = BytesBuilder();
  final ftypBd = ByteData(24);
  ftypBd.setUint32(0, 24);
  ftypBd.setUint8(4, 0x66); ftypBd.setUint8(5, 0x74); ftypBd.setUint8(6, 0x79); ftypBd.setUint8(7, 0x70); // ftyp
  ftypBd.setUint8(8, 0x61); ftypBd.setUint8(9, 0x76); ftypBd.setUint8(10, 0x69); ftypBd.setUint8(11, 0x66); // avif
  ftypBd.setUint32(12, 0); // minor_version
  ftypBd.setUint8(16, 0x61); ftypBd.setUint8(17, 0x76); ftypBd.setUint8(18, 0x69); ftypBd.setUint8(19, 0x66); // avif compatible
  ftypBd.setUint8(20, 0x6D); ftypBd.setUint8(21, 0x69); ftypBd.setUint8(22, 0x66); ftypBd.setUint8(23, 0x31); // mif1 compatible
  ftypBuilder.add(ftypBd.buffer.asUint8List());

  final out = BytesBuilder();
  out.add(ftypBuilder.toBytes());
  out.add(metaBytes);
  return out.toBytes();
}

MapByteRangeReader _makeReader(Uint8List bytes, {void Function(int start, int end)? onRead}) {
  return (int start, int end) async {
    assert(start >= 0 && start < end);
    onRead?.call(start, end);
    final res = Uint8List(end - start);
    if (start < bytes.length) {
      final copyEnd = min(end, bytes.length);
      res.setRange(0, copyEnd - start, bytes.sublist(start, copyEnd));
    }
    return res;
  };
}

void main() {
  group('MapImageHeader parser', () {
    test('H1: minimal header per format gives expected format and size (AVIF takes larger)', () async {
      // PNG
      final png = _buildPng(1200, 800);
      final pngHeader = await readMapImageHeader(_makeReader(png), png.length);
      expect(pngHeader.format, equals(MapInputFormat.png));
      expect(pngHeader.width, equals(1200));
      expect(pngHeader.height, equals(800));

      // JPEG with two APP segments before SOF
      final jpeg = _buildJpeg(1920, 1080);
      final jpegHeader = await readMapImageHeader(_makeReader(jpeg), jpeg.length);
      expect(jpegHeader.format, equals(MapInputFormat.jpeg));
      expect(jpegHeader.width, equals(1920));
      expect(jpegHeader.height, equals(1080));

      // WebP VP8
      final webpVp8 = _buildWebpVp8(640, 480);
      final vp8Header = await readMapImageHeader(_makeReader(webpVp8), webpVp8.length);
      expect(vp8Header.format, equals(MapInputFormat.webp));
      expect(vp8Header.width, equals(640));
      expect(vp8Header.height, equals(480));

      // WebP VP8L
      final webpVp8L = _buildWebpVp8L(1024, 768);
      final vp8lHeader = await readMapImageHeader(_makeReader(webpVp8L), webpVp8L.length);
      expect(vp8lHeader.format, equals(MapInputFormat.webp));
      expect(vp8lHeader.width, equals(1024));
      expect(vp8lHeader.height, equals(768));

      // WebP VP8X
      final webpVp8X = _buildWebpVp8X(2048, 1536);
      final vp8xHeader = await readMapImageHeader(_makeReader(webpVp8X), webpVp8X.length);
      expect(vp8xHeader.format, equals(MapInputFormat.webp));
      expect(vp8xHeader.width, equals(2048));
      expect(vp8xHeader.height, equals(1536));

      // AVIF with two ispe boxes (800x1200 and 1600x600 -> larger is 1600x1200)
      final avif = _buildAvif([
        (width: 800, height: 1200),
        (width: 1600, height: 600),
      ]);
      final avifHeader = await readMapImageHeader(_makeReader(avif), avif.length);
      expect(avifHeader.format, equals(MapInputFormat.avif));
      expect(avifHeader.width, equals(1600));
      expect(avifHeader.height, equals(1200));
    });

    test('H2: JPEG with 65,533 byte APP1 + two 60KB APP2 segments skips without reading segments, reads stay under 1KB', () async {
      final jpeg = _buildJpeg(800, 600, appSegmentSizes: [65533, 60000, 60000]);
      var totalBytesRead = 0;
      final header = await readMapImageHeader(
        _makeReader(jpeg, onRead: (start, end) {
          totalBytesRead += (end - start);
        }),
        jpeg.length,
      );
      expect(header.format, equals(MapInputFormat.jpeg));
      expect(header.width, equals(800));
      expect(header.height, equals(600));
      expect(totalBytesRead, lessThan(1024));
    });

    test('H3: fileSize = 209715201 throws fileTooLarge and reader called zero times; 209715200 accepted', () async {
      var readerCalls = 0;
      Future<Uint8List> reader(int start, int end) async {
        readerCalls++;
        return Uint8List(end - start);
      }

      try {
        await readMapImageHeader(reader, 209715201);
        fail('expected MapIntakeRejected');
      } on MapIntakeRejected catch (e) {
        expect(e.reason, equals(MapRejectReason.fileTooLarge));
        expect(e.byteSize, equals(209715201));
      }
      expect(readerCalls, equals(0));

      final validPng = _buildPng(100, 100);
      Future<Uint8List> bigReader(int start, int end) async {
        if (start < validPng.length) {
          final chunkEnd = min(end, validPng.length);
          final res = Uint8List(end - start);
          res.setRange(0, chunkEnd - start, validPng.sublist(start, chunkEnd));
          return res;
        }
        return Uint8List(end - start);
      }
      final header = await readMapImageHeader(bigReader, 209715200);
      expect(header.width, equals(100));
      expect(header.height, equals(100));
    });

    test('H4: Longest side exactly 8192 accepted, 8193 throws tooManyPixels for every format', () async {
      Future<void> check(Uint8List validBytes, Uint8List invalidWBytes, Uint8List invalidHBytes) async {
        final h = await readMapImageHeader(_makeReader(validBytes), validBytes.length);
        expect(max(h.width, h.height), equals(8192));

        try {
          await readMapImageHeader(_makeReader(invalidWBytes), invalidWBytes.length);
          fail('expected tooManyPixels');
        } on MapIntakeRejected catch (e) {
          expect(e.reason, equals(MapRejectReason.tooManyPixels));
          expect(e.width, equals(8193));
        }

        try {
          await readMapImageHeader(_makeReader(invalidHBytes), invalidHBytes.length);
          fail('expected tooManyPixels');
        } on MapIntakeRejected catch (e) {
          expect(e.reason, equals(MapRejectReason.tooManyPixels));
          expect(e.height, equals(8193));
        }
      }

      // PNG
      await check(_buildPng(8192, 100), _buildPng(8193, 100), _buildPng(100, 8193));
      // JPEG
      await check(_buildJpeg(8192, 100), _buildJpeg(8193, 100), _buildJpeg(100, 8193));
      // WebP VP8
      await check(_buildWebpVp8(8192, 100), _buildWebpVp8(8193, 100), _buildWebpVp8(100, 8193));
      // WebP VP8L
      await check(_buildWebpVp8L(8192, 100), _buildWebpVp8L(8193, 100), _buildWebpVp8L(100, 8193));
      // WebP VP8X
      await check(_buildWebpVp8X(8192, 100), _buildWebpVp8X(8193, 100), _buildWebpVp8X(100, 8193));
      // AVIF
      await check(
        _buildAvif([(width: 8192, height: 100)]),
        _buildAvif([(width: 8193, height: 100)]),
        _buildAvif([(width: 100, height: 8193)]),
      );
    });

    test('H5: GIF, BMP, SVG, PDF, PSD, TIFF, HEIC ftyp and 32 random bytes -> unsupportedFormat', () async {
      Future<void> expectUnsupported(Uint8List bytes) async {
        try {
          await readMapImageHeader(_makeReader(bytes), bytes.length);
          fail('expected unsupportedFormat');
        } on MapIntakeRejected catch (e) {
          expect(e.reason, equals(MapRejectReason.unsupportedFormat));
        }
      }

      await expectUnsupported(Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0, 0, 0, 0, 0])); // GIF89a
      await expectUnsupported(Uint8List.fromList([0x42, 0x4D, 0, 0, 0, 0, 0, 0, 0, 0])); // BM
      await expectUnsupported(Uint8List.fromList('<svg xmlns="http://www.w3.org/2000/svg"/>'.codeUnits));
      await expectUnsupported(Uint8List.fromList('<?xml version="1.0"?><svg></svg>'.codeUnits));
      await expectUnsupported(Uint8List.fromList('%PDF-1.7...'.codeUnits));
      await expectUnsupported(Uint8List.fromList('8BPS....'.codeUnits));
      await expectUnsupported(Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, 0, 0, 0, 0])); // TIFF LE
      await expectUnsupported(Uint8List.fromList([0x4D, 0x4D, 0x00, 0x2A, 0, 0, 0, 0])); // TIFF BE

      // HEIC ftyp (ftyp heic/heix/mif1 with no avif/avis)
      final heic = Uint8List(24);
      final heicBd = ByteData.view(heic.buffer);
      heicBd.setUint32(0, 24);
      heic.setRange(4, 8, 'ftyp'.codeUnits);
      heic.setRange(8, 12, 'heic'.codeUnits);
      heic.setRange(16, 20, 'mif1'.codeUnits);
      heic.setRange(20, 24, 'heix'.codeUnits);
      await expectUnsupported(heic);

      // 32 random bytes
      final rng = Random(42);
      final randBytes = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
      await expectUnsupported(randBytes);
    });

    test('H6: corrupted headers -> unreadable', () async {
      Future<void> expectUnreadable(Uint8List bytes) async {
        try {
          await readMapImageHeader(_makeReader(bytes), bytes.length);
          fail('expected unreadable');
        } on MapIntakeRejected catch (e) {
          expect(e.reason, equals(MapRejectReason.unreadable));
        }
      }

      // PNG whose first chunk isn't IHDR
      final badPng = _buildPng(100, 100);
      badPng[12] = 0x58; // 'X' instead of 'I'
      await expectUnreadable(badPng);

      // JPEG with no SOF before DA
      final badJpeg = BytesBuilder();
      badJpeg.add([0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02]);
      await expectUnreadable(badJpeg.toBytes());

      // WebP VP8 with wrong start code
      final badVp8 = _buildWebpVp8(100, 100);
      badVp8[23] = 0x00; // not 9D
      await expectUnreadable(badVp8);

      // AVIF with no ispe
      final badAvif = _buildAvif([]);
      await expectUnreadable(badAvif);

      // Width of 0
      final zeroW = _buildPng(0, 100);
      await expectUnreadable(zeroW);
    });

    test('H7: Width 0x80000000 gives 2147483648 (then tooManyPixels), not negative', () async {
      final png = _buildPng(100, 100);
      // set width to 0x80000000 at offset 16
      final bd = ByteData.view(png.buffer);
      bd.setUint32(16, 0x80000000);

      try {
        await readMapImageHeader(_makeReader(png), png.length);
        fail('expected tooManyPixels');
      } on MapIntakeRejected catch (e) {
        expect(e.reason, equals(MapRejectReason.tooManyPixels));
        expect(e.width, equals(2147483648));
      }
    });

    test('Law (fuzz): 2000 random byte streams and 2000 mutated headers never throw unhandled, never scan > 16MB', () async {
      for (var seed = 0; seed < 2000; seed++) {
        final randRng = Random(seed);
        final len = randRng.nextInt(512) + 1;
        final bytes = Uint8List.fromList(List.generate(len, (_) => randRng.nextInt(256)));
        final fileSize = len + randRng.nextInt(100);

        try {
          final res = await readMapImageHeader(_makeReader(bytes), fileSize);
          expect(res.width, greaterThanOrEqualTo(1));
          expect(res.height, greaterThanOrEqualTo(1));
          expect(max(res.width, res.height), lessThanOrEqualTo(8192));
        } on MapIntakeRejected catch (_) {
          // Expected
        } catch (e, st) {
          fail('Seed $seed failed with unhandled exception: $e\n$st');
        }
      }

      final validTemplates = [
        _buildPng(800, 600),
        _buildJpeg(800, 600),
        _buildWebpVp8(800, 600),
        _buildWebpVp8L(800, 600),
        _buildWebpVp8X(800, 600),
        _buildAvif([(width: 800, height: 600)]),
      ];

      for (var seed = 0; seed < 2000; seed++) {
        final mutRng = Random(seed + 10000);
        final base = validTemplates[mutRng.nextInt(validTemplates.length)];
        final mutated = Uint8List.fromList(base);

        // 1-8 random byte mutations
        final numMutations = mutRng.nextInt(8) + 1;
        for (var m = 0; m < numMutations; m++) {
          final idx = mutRng.nextInt(mutated.length);
          mutated[idx] = mutRng.nextInt(256);
        }

        // Random truncation
        final truncLen = mutRng.nextInt(mutated.length) + 1;
        final slice = Uint8List.fromList(mutated.sublist(0, truncLen));
        final fileSize = slice.length + mutRng.nextInt(50);

        try {
          final res = await readMapImageHeader(_makeReader(slice), fileSize);
          expect(res.width, greaterThanOrEqualTo(1));
          expect(res.height, greaterThanOrEqualTo(1));
          expect(max(res.width, res.height), lessThanOrEqualTo(8192));
        } on MapIntakeRejected catch (_) {
          // Expected
        } catch (e, st) {
          fail('Mutated seed $seed failed with unhandled exception: $e\n$st');
        }
      }
      // ignore: avoid_print
      print('Fuzz law completed: 2000 random seeds + 2000 mutated seeds tested cleanly.');
    });

    test('Law (target size): 5000 seeded pairs in [1, 8192]^2 plus corners', () {
      final corners = [
        (w: 1, h: 1),
        (w: 1, h: 8192),
        (w: 8192, h: 1),
        (w: 8192, h: 8192),
        (w: 4096, h: 4096),
        (w: 4096, h: 2048),
      ];

      for (final c in corners) {
        final out = mapTargetSize(c.w, c.h);
        expect(out.width, greaterThanOrEqualTo(1));
        expect(out.height, greaterThanOrEqualTo(1));
        expect(max(out.width, out.height), equals(min(4096, max(c.w, c.h))));
      }

      final rng = Random(9999);
      for (var i = 0; i < 5000; i++) {
        final w = rng.nextInt(8192) + 1;
        final h = rng.nextInt(8192) + 1;
        final out = mapTargetSize(w, h);

        final inLongest = max(w, h);
        final outLongest = max(out.width, out.height);

        expect(out.width, greaterThanOrEqualTo(1));
        expect(out.height, greaterThanOrEqualTo(1));

        if (inLongest <= 4096) {
          expect(out.width, equals(w));
          expect(out.height, equals(h));
        } else {
          expect(outLongest, inInclusiveRange(4095, 4096));
          // Aspect ratio difference is less than 1 pixel on short side
          final idealShort = (min(w, h) * (4096.0 / inLongest));
          final actualShort = min(out.width, out.height);
          expect((actualShort - idealShort).abs(), lessThanOrEqualTo(1.0));
        }
      }
      // ignore: avoid_print
      print('Target size law completed: 5000 seeded pairs + 6 corners tested cleanly.');
    });
  });
}
