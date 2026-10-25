import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_header.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
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
  ifdBd.setUint16(0, 1, endian); // 1 entry
  ifdBd.setUint16(2, 0x0112, endian); // Orientation tag
  ifdBd.setUint16(4, 3, endian); // SHORT
  ifdBd.setUint32(6, 1, endian); // count 1
  ifdBd.setUint16(10, orientation, endian); // value
  ifdBd.setUint16(12, 0, endian); // pad
  b.add(ifdBd.buffer.asUint8List());
  return b.toBytes();
}

Uint8List _buildJpegWithExif(
  int width,
  int height,
  Uint8List tiffBytes, {
  List<Uint8List>? extraAppSegments,
}) {
  final b = BytesBuilder();
  b.add([0xFF, 0xD8]); // SOI
  if (extraAppSegments != null) {
    for (final seg in extraAppSegments) {
      b.add(seg);
    }
  }
  // APP1 Exif segment
  b.add([0xFF, 0xE1]);
  final segLen = 2 + 6 + tiffBytes.length;
  final lenBd = ByteData(2);
  lenBd.setUint16(0, segLen);
  b.add(lenBd.buffer.asUint8List());
  b.add([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]); // Exif\0\0
  b.add(tiffBytes);

  // SOF0
  b.add([0xFF, 0xC0]);
  final sofBd = ByteData(9);
  sofBd.setUint16(0, 9);
  sofBd.setUint8(2, 8);
  sofBd.setUint16(3, height);
  sofBd.setUint16(5, width);
  sofBd.setUint8(7, 3);
  b.add(sofBd.buffer.asUint8List());
  return b.toBytes();
}

Uint8List _buildPngWithExif(
  int width,
  int height,
  Uint8List tiffBytes, {
  bool afterIdat = false,
  int? customLength,
}) {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // PNG sig
  // IHDR
  final bd = ByteData(17);
  bd.setUint32(0, 13);
  bd.setUint8(4, 0x49); bd.setUint8(5, 0x48); bd.setUint8(6, 0x44); bd.setUint8(7, 0x52); // IHDR
  bd.setUint32(8, width);
  bd.setUint32(12, height);
  bd.setUint8(16, 8);
  b.add(bd.buffer.asUint8List());
  final ihdrTypeAndData = [
    0x49, 0x48, 0x44, 0x52,
    ...bd.buffer.asUint8List().sublist(8, 17),
    0x02, 0x00, 0x00, 0x00,
  ];
  final ihdrCrc = ByteData(4);
  ihdrCrc.setUint32(0, _crc32(ihdrTypeAndData));
  b.add([0x02, 0x00, 0x00, 0x00]);
  b.add(ihdrCrc.buffer.asUint8List());

  void addExifChunk() {
    final len = customLength ?? tiffBytes.length;
    final lenBd = ByteData(4);
    lenBd.setUint32(0, len);
    b.add(lenBd.buffer.asUint8List());
    final typeBytes = [0x65, 0x58, 0x49, 0x66]; // eXIf
    b.add(typeBytes);
    b.add(tiffBytes);
    final crcBd = ByteData(4);
    crcBd.setUint32(0, _crc32([...typeBytes, ...tiffBytes]));
    b.add(crcBd.buffer.asUint8List());
  }

  void addIdatChunk() {
    final lenBd = ByteData(4);
    lenBd.setUint32(0, 0);
    b.add(lenBd.buffer.asUint8List());
    final typeBytes = [0x49, 0x44, 0x41, 0x54]; // IDAT
    b.add(typeBytes);
    final crcBd = ByteData(4);
    crcBd.setUint32(0, _crc32(typeBytes));
    b.add(crcBd.buffer.asUint8List());
  }

  if (afterIdat) {
    addIdatChunk();
    addExifChunk();
  } else {
    addExifChunk();
    addIdatChunk();
  }

  return b.toBytes();
}

Uint8List _buildWebpVp8XWithExif(int width, int height, Uint8List tiffBytes) {
  final b = BytesBuilder();
  b.add([0x52, 0x49, 0x46, 0x46]); // RIFF
  const vp8xSize = 8 + 10;
  final exifChunkSize = 8 + tiffBytes.length + (tiffBytes.length.isOdd ? 1 : 0);
  final riffLenBd = ByteData(4);
  riffLenBd.setUint32(0, 4 + vp8xSize + exifChunkSize, Endian.little);
  b.add(riffLenBd.buffer.asUint8List());
  b.add([0x57, 0x45, 0x42, 0x50]); // WEBP
  // VP8X chunk
  b.add([0x56, 0x50, 0x38, 0x58]); // VP8X
  final vp8xLen = ByteData(4);
  vp8xLen.setUint32(0, 10, Endian.little);
  b.add(vp8xLen.buffer.asUint8List());
  b.add([0x08, 0x00, 0x00, 0x00]); // flags: bit 3 (EXIF)
  final wMinus1 = width - 1;
  final hMinus1 = height - 1;
  b.add([wMinus1 & 0xFF, (wMinus1 >> 8) & 0xFF, (wMinus1 >> 16) & 0xFF]);
  b.add([hMinus1 & 0xFF, (hMinus1 >> 8) & 0xFF, (hMinus1 >> 16) & 0xFF]);
  // EXIF chunk
  b.add([0x45, 0x58, 0x49, 0x46]); // EXIF
  final exifLen = ByteData(4);
  exifLen.setUint32(0, tiffBytes.length, Endian.little);
  b.add(exifLen.buffer.asUint8List());
  b.add(tiffBytes);
  if (tiffBytes.length.isOdd) {
    b.add([0x00]);
  }
  return b.toBytes();
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
    propBox.add([0x69, 0x6D, 0x69, 0x72]); // imir
    propBox.add([0x00]);
  } else {
    propBox.add([0x69, 0x72, 0x6F, 0x74]); // irot
    propBox.add([irotAngle! & 0x03]);
  }
  final propBytes = propBox.toBytes();

  // Find ipco:
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

  // Find ipma in res:
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

  // Update sizes:
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

    test('OR1: JPEG 400x200 orientations 1-8 in MM and II byte order (16 cases)', () async {
      for (final littleEndian in [true, false]) {
        for (var o = 1; o <= 8; o++) {
          final tiff = _buildTiffExif(o, littleEndian: littleEndian);
          final jpeg = _buildJpegWithExif(400, 200, tiff);
          final header = await readMapImageHeader(_makeReader(jpeg), jpeg.length);
          expect(header.format, equals(MapInputFormat.jpeg));
          if (o >= 1 && o <= 4) {
            expect(header.width, equals(400), reason: 'orientation $o littleEndian $littleEndian');
            expect(header.height, equals(200));
            expect(header.quarterTurn, isFalse);
          } else {
            expect(header.width, equals(200), reason: 'orientation $o littleEndian $littleEndian');
            expect(header.height, equals(400));
            expect(header.quarterTurn, isTrue);
          }
        }
      }
    });

    test('OR2: JPEG with XMP APP1 before Exif (6) gives 200x400; two Exif APP1s (1 then 6) gives 400x200', () async {
      // 1. XMP APP1 before Exif (orientation 6)
      final xmpData = utf8.encode('http://ns.adobe.com/xap/1.0/\x00some xmp data');
      final xmpSeg = BytesBuilder();
      xmpSeg.add([0xFF, 0xE1]);
      final xmpLenBd = ByteData(2);
      xmpLenBd.setUint16(0, 2 + xmpData.length);
      xmpSeg.add(xmpLenBd.buffer.asUint8List());
      xmpSeg.add(xmpData);

      final tiff6 = _buildTiffExif(6);
      final jpegWithXmp = _buildJpegWithExif(400, 200, tiff6, extraAppSegments: [xmpSeg.toBytes()]);
      final headerXmp = await readMapImageHeader(_makeReader(jpegWithXmp), jpegWithXmp.length);
      expect(headerXmp.width, equals(200));
      expect(headerXmp.height, equals(400));
      expect(headerXmp.quarterTurn, isTrue);

      // 2. Two Exif APP1 segments: first saying 1, second saying 6 -> first wins (400x200)
      final tiff1 = _buildTiffExif(1);
      final exif1Seg = BytesBuilder();
      exif1Seg.add([0xFF, 0xE1]);
      final exif1LenBd = ByteData(2);
      exif1LenBd.setUint16(0, 2 + 6 + tiff1.length);
      exif1Seg.add(exif1LenBd.buffer.asUint8List());
      exif1Seg.add([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]);
      exif1Seg.add(tiff1);

      final jpegTwoExif = _buildJpegWithExif(400, 200, tiff6, extraAppSegments: [exif1Seg.toBytes()]);
      final headerTwoExif = await readMapImageHeader(_makeReader(jpegTwoExif), jpegTwoExif.length);
      expect(headerTwoExif.width, equals(400));
      expect(headerTwoExif.height, equals(200));
      expect(headerTwoExif.quarterTurn, isFalse);
    });

    test('OR3: Damaged Exif (7 cases) all give 400x200 and are not rejected', () async {
      // 1. IFD0 offset past end of segment
      final tiff1 = _buildTiffExif(6);
      final bd1 = ByteData.view(tiff1.buffer);
      bd1.setUint32(4, 1000, Endian.little);
      final jpeg1 = _buildJpegWithExif(400, 200, tiff1);
      final h1 = await readMapImageHeader(_makeReader(jpeg1), jpeg1.length);
      expect(h1.width, equals(400));
      expect(h1.height, equals(200));

      // 2. Entry count larger than segment holds
      final tiff2 = _buildTiffExif(6);
      final bd2 = ByteData.view(tiff2.buffer);
      bd2.setUint16(8, 50, Endian.little);
      final jpeg2 = _buildJpegWithExif(400, 200, tiff2);
      final h2 = await readMapImageHeader(_makeReader(jpeg2), jpeg2.length);
      expect(h2.width, equals(400));
      expect(h2.height, equals(200));

      // 3. Tag 0x0112 with type LONG (4) instead of SHORT (3)
      final tiff3 = _buildTiffExif(6);
      final bd3 = ByteData.view(tiff3.buffer);
      bd3.setUint16(12, 4, Endian.little);
      final jpeg3 = _buildJpegWithExif(400, 200, tiff3);
      final h3 = await readMapImageHeader(_makeReader(jpeg3), jpeg3.length);
      expect(h3.width, equals(400));
      expect(h3.height, equals(200));

      // 4. Value 0
      final tiff4 = _buildTiffExif(0);
      final jpeg4 = _buildJpegWithExif(400, 200, tiff4);
      final h4 = await readMapImageHeader(_makeReader(jpeg4), jpeg4.length);
      expect(h4.width, equals(400));
      expect(h4.height, equals(200));

      // 5. Value 9
      final tiff5 = _buildTiffExif(9);
      final jpeg5 = _buildJpegWithExif(400, 200, tiff5);
      final h5 = await readMapImageHeader(_makeReader(jpeg5), jpeg5.length);
      expect(h5.width, equals(400));
      expect(h5.height, equals(200));

      // 6. Segment ends inside TIFF header (< 8 bytes)
      final tiff6 = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, 0x08]);
      final jpeg6 = _buildJpegWithExif(400, 200, tiff6);
      final h6 = await readMapImageHeader(_makeReader(jpeg6), jpeg6.length);
      expect(h6.width, equals(400));
      expect(h6.height, equals(200));

      // 7. Exif\0\0 followed by XX*\0
      final tiff7 = _buildTiffExif(6);
      tiff7[0] = 0x58; // 'X'
      tiff7[1] = 0x58; // 'X'
      final jpeg7 = _buildJpegWithExif(400, 200, tiff7);
      final h7 = await readMapImageHeader(_makeReader(jpeg7), jpeg7.length);
      expect(h7.width, equals(400));
      expect(h7.height, equals(200));
    });

    test('OR4: PNG 400x200: eXIf 6 before IDAT -> 200x400; after IDAT -> 400x200; 70KB eXIf -> 400x200 unread', () async {
      final tiff6 = _buildTiffExif(6);

      // eXIf 6 before IDAT -> 200x400
      final pngBefore = _buildPngWithExif(400, 200, tiff6, afterIdat: false);
      final hBefore = await readMapImageHeader(_makeReader(pngBefore), pngBefore.length);
      expect(hBefore.width, equals(200));
      expect(hBefore.height, equals(400));
      expect(hBefore.quarterTurn, isTrue);

      // eXIf 6 after IDAT -> 400x200
      final pngAfter = _buildPngWithExif(400, 200, tiff6, afterIdat: true);
      final hAfter = await readMapImageHeader(_makeReader(pngAfter), pngAfter.length);
      expect(hAfter.width, equals(400));
      expect(hAfter.height, equals(200));
      expect(hAfter.quarterTurn, isFalse);

      // eXIf chunk with 70 KiB of data before IDAT: reader never asks for those 70 KiB
      final bigTiff = Uint8List(70 * 1024);
      final png70K = _buildPngWithExif(400, 200, bigTiff, afterIdat: false);
      var bytesRead = 0;
      final h70K = await readMapImageHeader(
        _makeReader(png70K, onRead: (start, end) {
          bytesRead += (end - start);
        }),
        png70K.length,
      );
      expect(h70K.width, equals(400));
      expect(h70K.height, equals(200));
      expect(h70K.quarterTurn, isFalse);
      expect(bytesRead, lessThan(1024)); // Proves the 70KB was skipped without reading
    });

    test('OR5: WebP VP8X with EXIF 6 stored 400x200 gives 400x200, quarterTurn false', () async {
      final tiff6 = _buildTiffExif(6);
      final webp = _buildWebpVp8XWithExif(400, 200, tiff6);
      final header = await readMapImageHeader(_makeReader(webp), webp.length);
      expect(header.format, equals(MapInputFormat.webp));
      expect(header.width, equals(400));
      expect(header.height, equals(200));
      expect(header.quarterTurn, isFalse);
    });

    test('OR6: AVIF with irot angles 0, 1, 2, 3, different item id, imir, and plain fixture', () async {
      // Plain fixture
      final plain = _buildRotatedAvif();
      final hPlain = await readMapImageHeader(_makeReader(plain), plain.length);
      expect(hPlain.width, equals(64));
      expect(hPlain.height, equals(32));
      expect(hPlain.quarterTurn, isFalse);

      // Angle 0: 64x32
      final avif0 = _buildRotatedAvif(irotAngle: 0);
      final h0 = await readMapImageHeader(_makeReader(avif0), avif0.length);
      expect(h0.width, equals(64));
      expect(h0.height, equals(32));
      expect(h0.quarterTurn, isFalse);

      // Angle 1: 32x64
      final avif1 = _buildRotatedAvif(irotAngle: 1);
      final h1 = await readMapImageHeader(_makeReader(avif1), avif1.length);
      expect(h1.width, equals(32));
      expect(h1.height, equals(64));
      expect(h1.quarterTurn, isTrue);

      // Angle 2: 64x32
      final avif2 = _buildRotatedAvif(irotAngle: 2);
      final h2 = await readMapImageHeader(_makeReader(avif2), avif2.length);
      expect(h2.width, equals(64));
      expect(h2.height, equals(32));
      expect(h2.quarterTurn, isFalse);

      // Angle 3: 32x64
      final avif3 = _buildRotatedAvif(irotAngle: 3);
      final h3 = await readMapImageHeader(_makeReader(avif3), avif3.length);
      expect(h3.width, equals(32));
      expect(h3.height, equals(64));
      expect(h3.quarterTurn, isTrue);

      // irot angle 1 associated with different item id (2): 64x32
      final avifOther = _buildRotatedAvif(irotAngle: 1, associatedItemId: 2);
      final hOther = await readMapImageHeader(_makeReader(avifOther), avifOther.length);
      expect(hOther.width, equals(64));
      expect(hOther.height, equals(32));
      expect(hOther.quarterTurn, isFalse);

      // imir box instead of irot: 64x32
      final avifImir = _buildRotatedAvif(useImir: true);
      final hImir = await readMapImageHeader(_makeReader(avifImir), avifImir.length);
      expect(hImir.width, equals(64));
      expect(hImir.height, equals(32));
      expect(hImir.quarterTurn, isFalse);
    });

    test('OR7: JPEG stored as 8193x100 with orientation 6 rejected tooManyPixels with width 100, height 8193', () async {
      final tiff6 = _buildTiffExif(6);
      final jpeg = _buildJpegWithExif(8193, 100, tiff6);
      try {
        await readMapImageHeader(_makeReader(jpeg), jpeg.length);
        fail('expected tooManyPixels');
      } on MapIntakeRejected catch (e) {
        expect(e.reason, equals(MapRejectReason.tooManyPixels));
        expect(e.width, equals(100));
        expect(e.height, equals(8193));
      }
    });

    test('Law (fuzz): 2000 random byte streams, 2000 mutated headers, and 1000 orientation mutated headers', () async {
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

      // 1,000 orientation-specific mutations
      final orientationTemplates = [
        _buildJpegWithExif(800, 600, _buildTiffExif(6)),
        _buildPngWithExif(800, 600, _buildTiffExif(6)),
        _buildRotatedAvif(irotAngle: 1),
      ];

      for (var seed = 0; seed < 1000; seed++) {
        final oRng = Random(seed + 20000);
        final base = orientationTemplates[oRng.nextInt(orientationTemplates.length)];
        final mutated = Uint8List.fromList(base);

        final numMutations = oRng.nextInt(8) + 1;
        for (var m = 0; m < numMutations; m++) {
          final idx = oRng.nextInt(mutated.length);
          mutated[idx] = oRng.nextInt(256);
        }

        final fileSize = mutated.length + oRng.nextInt(50);
        try {
          final res = await readMapImageHeader(_makeReader(mutated), fileSize);
          expect(res.width, greaterThanOrEqualTo(1));
          expect(res.height, greaterThanOrEqualTo(1));
          expect(max(res.width, res.height), lessThanOrEqualTo(8192));
        } on MapIntakeRejected catch (_) {
          // Expected
        } catch (e, st) {
          fail('Orientation mutated seed $seed failed with unhandled exception: $e\n$st');
        }
      }

      // ignore: avoid_print
      print('Fuzz law completed: 2000 random seeds + 2000 mutated seeds + 1000 orientation seeds tested cleanly.');
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
