import 'dart:math';
import 'dart:typed_data';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'map_image_intake_port.dart';

const int kMapInputMaxBytes = 209715200;
const int kMapInputMaxLongestSidePx = 8192;
const int kMapHeaderScanMaxBytes = 16 * 1024 * 1024;
const int kMapOutputMaxLongestSidePx = BlobRef.maxLongestSidePx;

enum MapInputFormat { png, jpeg, webp, avif }

final class MapImageHeader {
  final MapInputFormat format;
  final int width;
  final int height;

  const MapImageHeader({
    required this.format,
    required this.width,
    required this.height,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapImageHeader &&
          format == other.format &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(format, width, height);

  @override
  String toString() => 'MapImageHeader($format, ${width}x$height)';
}

/// Reads bytes [start, end) of the picked file.
typedef MapByteRangeReader = Future<Uint8List> Function(int start, int end);

({int width, int height}) mapTargetSize(int width, int height) {
  final longest = max(width, height);
  if (longest <= kMapOutputMaxLongestSidePx) {
    return (width: width, height: height);
  }
  final scale = kMapOutputMaxLongestSidePx / longest;
  final targetW = max(1, (width * scale).round());
  final targetH = max(1, (height * scale).round());
  return (width: targetW, height: targetH);
}

Future<MapImageHeader> readMapImageHeader(
  MapByteRangeReader read,
  int fileSize,
) async {
  // 1. fileSize > kMapInputMaxBytes -> fileTooLarge, before any read. fileSize <= 0 -> unreadable.
  if (fileSize > kMapInputMaxBytes) {
    throw MapIntakeRejected(MapRejectReason.fileTooLarge, byteSize: fileSize);
  }
  if (fileSize <= 0) {
    throw const MapIntakeRejected(MapRejectReason.unreadable);
  }

  var totalBytesRead = 0;

  Future<Uint8List> safeRead(int start, int end) async {
    if (start < 0 || end <= start || end > fileSize) {
      throw const MapIntakeRejected(MapRejectReason.unreadable);
    }
    final len = end - start;
    totalBytesRead += len;
    if (totalBytesRead > kMapHeaderScanMaxBytes) {
      throw const MapIntakeRejected(MapRejectReason.unreadable);
    }
    final bytes = await read(start, end);
    if (bytes.length != len) {
      throw const MapIntakeRejected(MapRejectReason.unreadable);
    }
    return bytes;
  }

  // 2. Read first 32 bytes (or fewer if file is shorter) and sniff.
  final sniffLen = min(fileSize, 32);
  final sniffBytes = await safeRead(0, sniffLen);

  MapInputFormat? format;

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (sniffBytes.length >= 8 &&
      sniffBytes[0] == 0x89 &&
      sniffBytes[1] == 0x50 &&
      sniffBytes[2] == 0x4E &&
      sniffBytes[3] == 0x47 &&
      sniffBytes[4] == 0x0D &&
      sniffBytes[5] == 0x0A &&
      sniffBytes[6] == 0x1A &&
      sniffBytes[7] == 0x0A) {
    format = MapInputFormat.png;
  }
  // JPEG: FF D8 FF
  else if (sniffBytes.length >= 3 &&
      sniffBytes[0] == 0xFF &&
      sniffBytes[1] == 0xD8 &&
      sniffBytes[2] == 0xFF) {
    format = MapInputFormat.jpeg;
  }
  // WebP: RIFF at 0 and WEBP at 8
  else if (sniffBytes.length >= 12 &&
      sniffBytes[0] == 0x52 &&
      sniffBytes[1] == 0x49 &&
      sniffBytes[2] == 0x46 &&
      sniffBytes[3] == 0x46 && // RIFF
      sniffBytes[8] == 0x57 &&
      sniffBytes[9] == 0x45 &&
      sniffBytes[10] == 0x42 &&
      sniffBytes[11] == 0x50) { // WEBP
    format = MapInputFormat.webp;
  }
  // AVIF: ftyp at 4, and major brand or compatible brand is avif or avis
  else if (sniffBytes.length >= 12 &&
      sniffBytes[4] == 0x66 &&
      sniffBytes[5] == 0x74 &&
      sniffBytes[6] == 0x79 &&
      sniffBytes[7] == 0x70) { // ftyp
    bool isAvifBrand(int b0, int b1, int b2, int b3) {
      final isAvif = b0 == 0x61 && b1 == 0x76 && b2 == 0x69 && b3 == 0x66; // avif
      final isAvis = b0 == 0x61 && b1 == 0x76 && b2 == 0x69 && b3 == 0x73; // avis
      return isAvif || isAvis;
    }

    bool hasAvif = isAvifBrand(
      sniffBytes[8],
      sniffBytes[9],
      sniffBytes[10],
      sniffBytes[11],
    );

    // Check compatible brands in the sniffed header
    if (!hasAvif) {
      for (var i = 16; i + 4 <= sniffBytes.length; i += 4) {
        if (isAvifBrand(
          sniffBytes[i],
          sniffBytes[i + 1],
          sniffBytes[i + 2],
          sniffBytes[i + 3],
        )) {
          hasAvif = true;
          break;
        }
      }
    }

    if (hasAvif) {
      format = MapInputFormat.avif;
    } else {
      throw const MapIntakeRejected(MapRejectReason.unsupportedFormat);
    }
  } else {
    throw const MapIntakeRejected(MapRejectReason.unsupportedFormat);
  }

  int width = 0;
  int height = 0;

  // 3. Dimensions
  switch (format) {
    case MapInputFormat.png:
      // First chunk must be IHDR (length 13) at offset 8.
      if (fileSize < 24) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }
      final ihdrBytes = await safeRead(8, 24);
      final bd = ByteData.view(ihdrBytes.buffer, ihdrBytes.offsetInBytes, ihdrBytes.length);
      final chunkLen = bd.getUint32(0);
      final isIhdr = ihdrBytes[4] == 0x49 &&
          ihdrBytes[5] == 0x48 &&
          ihdrBytes[6] == 0x44 &&
          ihdrBytes[7] == 0x52; // IHDR
      if (chunkLen != 13 || !isIhdr) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }
      width = bd.getUint32(8);
      height = bd.getUint32(12);

    case MapInputFormat.jpeg:
      // Walk segments from offset 2. Skip FF fill bytes.
      var offset = 2;
      bool foundSof = false;

      while (offset < fileSize) {
        if (offset > kMapHeaderScanMaxBytes) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }

        // Read at current offset to find next marker (skip FF fill bytes)
        final probe = await safeRead(offset, min(offset + 32, fileSize));
        var i = 0;
        while (i < probe.length && probe[i] == 0xFF) {
          i++;
        }
        if (i >= probe.length) {
          offset += probe.length;
          continue;
        }
        offset += i;

        final marker = probe[i];
        offset++; // moved past marker byte

        // Markers D0-D7 and 01 have no length
        if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
          continue;
        }

        // Reaching DA (start of scan) or D9 (end of image) without SOF -> unreadable
        if (marker == 0xDA || marker == 0xD9) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }

        // Check if SOF: C0-C3, C5-C7, C9-CB, CD-CF
        final isSof = (marker >= 0xC0 && marker <= 0xCF) &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC;

        if (isSof) {
          // Read SOF header: length(2), precision(1), height(2), width(2)
          if (offset + 7 > fileSize) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          final sofData = await safeRead(offset, offset + 7);
          final bd = ByteData.view(sofData.buffer, sofData.offsetInBytes, sofData.length);
          final segLen = bd.getUint16(0);
          if (segLen < 7 || offset + segLen > fileSize) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          height = bd.getUint16(3);
          width = bd.getUint16(5);
          foundSof = true;
          break;
        } else {
          // Other segment: read 2-byte segment length, then skip it
          if (offset + 2 > fileSize) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          final lenData = await safeRead(offset, offset + 2);
          final bd = ByteData.view(lenData.buffer, lenData.offsetInBytes, lenData.length);
          final segLen = bd.getUint16(0);
          if (segLen < 2 || offset + segLen > fileSize) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          offset += segLen;
        }
      }

      if (!foundSof) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }

    case MapInputFormat.webp:
      if (fileSize < 16) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }
      // FourCC at 12
      final fourCcChunk = await safeRead(12, 16);
      final fourCc = String.fromCharCodes(fourCcChunk);

      if (fourCc == 'VP8 ') {
        if (fileSize < 30) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        final headerChunk = await safeRead(12, 30);
        // Check start code 9D 01 2A at byte 23 (index 11 in headerChunk)
        if (headerChunk[11] != 0x9D ||
            headerChunk[12] != 0x01 ||
            headerChunk[13] != 0x2A) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        // width = u16 LE at byte 26 (index 14) & 0x3FFF
        // height = u16 LE at byte 28 (index 16) & 0x3FFF
        final wLow = headerChunk[14];
        final wHigh = headerChunk[15];
        width = (wLow | (wHigh << 8)) & 0x3FFF;

        final hLow = headerChunk[16];
        final hHigh = headerChunk[17];
        height = (hLow | (hHigh << 8)) & 0x3FFF;
      } else if (fourCc == 'VP8L') {
        if (fileSize < 25) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        final headerChunk = await safeRead(12, 25);
        // check 0x2F at 20 (index 8)
        if (headerChunk[8] != 0x2F) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        // 14-bit width-1 and height-1 packed LE from byte 21 (index 9)
        final b0 = headerChunk[9];
        final b1 = headerChunk[10];
        final b2 = headerChunk[11];
        final b3 = headerChunk[12];
        final val = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        width = (val & 0x3FFF) + 1;
        height = ((val >> 14) & 0x3FFF) + 1;
      } else if (fourCc == 'VP8X') {
        if (fileSize < 30) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        final headerChunk = await safeRead(12, 30);
        // canvas width-1 = u24 LE at 24 (index 12), height-1 = u24 LE at 27 (index 15)
        final w0 = headerChunk[12];
        final w1 = headerChunk[13];
        final w2 = headerChunk[14];
        width = (w0 | (w1 << 8) | (w2 << 16)) + 1;

        final h0 = headerChunk[15];
        final h1 = headerChunk[16];
        final h2 = headerChunk[17];
        height = (h0 | (h1 << 8) | (h2 << 16)) + 1;
      } else {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }

    case MapInputFormat.avif:
      // Walk top-level boxes to find meta
      var offset = 0;
      int? metaOffset;
      int? metaSize;

      while (offset < fileSize) {
        if (offset > kMapHeaderScanMaxBytes) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        if (offset + 8 > fileSize) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }
        final boxHeader = await safeRead(offset, offset + 8);
        final bd = ByteData.view(boxHeader.buffer, boxHeader.offsetInBytes, boxHeader.length);
        var size = bd.getUint32(0);
        final type = String.fromCharCodes(boxHeader.sublist(4, 8));
        var headerSize = 8;

        if (size == 1) {
          if (offset + 16 > fileSize) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          final extHeader = await safeRead(offset + 8, offset + 16);
          final extBd = ByteData.view(extHeader.buffer, extHeader.offsetInBytes, extHeader.length);
          // Large size (high 32 bits + low 32 bits)
          final high = extBd.getUint32(0);
          final low = extBd.getUint32(4);
          if (high != 0) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          size = low;
          headerSize = 16;
        } else if (size == 0) {
          size = fileSize - offset;
        }

        if (size < headerSize || offset + size > fileSize) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }

        if (type == 'meta') {
          // A meta box bigger than 1 MiB -> unreadable
          if (size > 1024 * 1024) {
            throw const MapIntakeRejected(MapRejectReason.unreadable);
          }
          metaOffset = offset;
          metaSize = size;
          break;
        }

        offset += size;
      }

      if (metaOffset == null || metaSize == null) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }

      // meta is a full box: skip header + 4 bytes version and flags
      final metaHeaderBytes = await safeRead(metaOffset, metaOffset + 8);
      var metaHeaderLen = 8;
      final metaBd = ByteData.view(metaHeaderBytes.buffer, metaHeaderBytes.offsetInBytes, metaHeaderBytes.length);
      if (metaBd.getUint32(0) == 1) {
        metaHeaderLen = 16;
      }
      final metaPayloadStart = metaOffset + metaHeaderLen + 4;
      final metaEnd = metaOffset + metaSize;
      if (metaPayloadStart > metaEnd) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }

      // Read meta box payload into memory to parse iprp -> ipco -> ispe
      final metaPayload = await safeRead(metaPayloadStart, metaEnd);
      final metaPayloadBd = ByteData.view(metaPayload.buffer, metaPayload.offsetInBytes, metaPayload.length);

      int maxWidth = 0;
      int maxHeight = 0;
      var ispeFound = false;

      // Find iprp inside meta
      var pOffset = 0;
      while (pOffset + 8 <= metaPayload.length) {
        final bSize = metaPayloadBd.getUint32(pOffset);
        final bType = String.fromCharCodes(metaPayload.sublist(pOffset + 4, pOffset + 8));
        if (bSize < 8 || pOffset + bSize > metaPayload.length) {
          throw const MapIntakeRejected(MapRejectReason.unreadable);
        }

        if (bType == 'iprp') {
          // Inside iprp, find ipco
          final iprpEnd = pOffset + bSize;
          var iprpOffset = pOffset + 8;

          while (iprpOffset + 8 <= iprpEnd) {
            final ipcoSize = metaPayloadBd.getUint32(iprpOffset);
            final ipcoType = String.fromCharCodes(metaPayload.sublist(iprpOffset + 4, iprpOffset + 8));
            if (ipcoSize < 8 || iprpOffset + ipcoSize > iprpEnd) {
              throw const MapIntakeRejected(MapRejectReason.unreadable);
            }

            if (ipcoType == 'ipco') {
              // Inside ipco, read every ispe box
              final ipcoEnd = iprpOffset + ipcoSize;
              var ispeOffset = iprpOffset + 8;

              while (ispeOffset + 8 <= ipcoEnd) {
                final boxLen = metaPayloadBd.getUint32(ispeOffset);
                final boxType = String.fromCharCodes(metaPayload.sublist(ispeOffset + 4, ispeOffset + 8));
                if (boxLen < 8 || ispeOffset + boxLen > ipcoEnd) {
                  throw const MapIntakeRejected(MapRejectReason.unreadable);
                }

                if (boxType == 'ispe') {
                  // Full box (skip 4 bytes version/flags), then u32 BE width, u32 BE height
                  if (boxLen < 20) {
                    throw const MapIntakeRejected(MapRejectReason.unreadable);
                  }
                  final ispeWidth = metaPayloadBd.getUint32(ispeOffset + 12);
                  final ispeHeight = metaPayloadBd.getUint32(ispeOffset + 16);
                  maxWidth = max(maxWidth, ispeWidth);
                  maxHeight = max(maxHeight, ispeHeight);
                  ispeFound = true;
                }

                ispeOffset += boxLen;
              }
            }

            iprpOffset += ipcoSize;
          }
        }

        pOffset += bSize;
      }

      if (!ispeFound) {
        throw const MapIntakeRejected(MapRejectReason.unreadable);
      }
      width = maxWidth;
      height = maxHeight;
  }

  // 4. width == 0 or height == 0 -> unreadable.
  if (width == 0 || height == 0) {
    throw const MapIntakeRejected(MapRejectReason.unreadable);
  }

  // max(width, height) > kMapInputMaxLongestSidePx -> tooManyPixels (with width and height)
  if (max(width, height) > kMapInputMaxLongestSidePx) {
    throw MapIntakeRejected(
      MapRejectReason.tooManyPixels,
      width: width,
      height: height,
    );
  }

  return MapImageHeader(
    format: format,
    width: width,
    height: height,
  );
}
