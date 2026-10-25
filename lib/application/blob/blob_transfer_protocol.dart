import 'dart:convert';
import 'dart:typed_data';

const String kBlobChannelLabel = 'dn5e_blob';
const int kBlobChannelId = 7;
const int kBlobChunkBytes = 65536;
const int kBlobFrameHeaderBytes = 36;
const int kBlobHighWaterBytes = 1048576;
const int kBlobLowWaterBytes = 262144;
const int kBlobMaxControlChars = 8192;
const Duration kBlobDefaultStallTimeout = Duration(seconds: 10);

int blobChunkCount(int byteSize) {
  if (byteSize <= 0) return 0;
  return (byteSize / kBlobChunkBytes).ceil();
}

int blobChunkLength(int byteSize, int index) {
  final count = blobChunkCount(byteSize);
  if (index < 0 || index >= count) {
    throw RangeError.range(index, 0, count - 1, 'index');
  }
  if (index < count - 1) {
    return kBlobChunkBytes;
  }
  final remainder = byteSize % kBlobChunkBytes;
  return remainder == 0 ? kBlobChunkBytes : remainder;
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String _bytesToHex(Uint8List bytes, int offset, int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(bytes[offset + i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List encodeChunkFrame({
  required String sha256Hex,
  required int index,
  required Uint8List payload,
}) {
  final frame = Uint8List(kBlobFrameHeaderBytes + payload.length);
  final hashBytes = _hexToBytes(sha256Hex);
  frame.setRange(0, 32, hashBytes);
  final bd = ByteData.sublistView(frame);
  bd.setUint32(32, index, Endian.big);
  frame.setRange(kBlobFrameHeaderBytes, frame.length, payload);
  return frame;
}

class BlobChunkFrame {
  final String sha256Hex;
  final int index;
  final Uint8List payload;

  const BlobChunkFrame({
    required this.sha256Hex,
    required this.index,
    required this.payload,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobChunkFrame &&
          sha256Hex == other.sha256Hex &&
          index == other.index &&
          _bytesEqual(payload, other.payload);

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(sha256Hex, index, payload.length);
}

BlobChunkFrame? decodeChunkFrame(Uint8List frame) {
  try {
    if (frame.length < kBlobFrameHeaderBytes + 1 ||
        frame.length > kBlobFrameHeaderBytes + kBlobChunkBytes) {
      return null;
    }
    final sha256Hex = _bytesToHex(frame, 0, 32);
    final bd = ByteData.sublistView(frame);
    final index = bd.getUint32(32, Endian.big);
    final payload = Uint8List.sublistView(frame, kBlobFrameHeaderBytes);
    return BlobChunkFrame(
      sha256Hex: sha256Hex,
      index: index,
      payload: payload,
    );
  } catch (_) {
    return null;
  }
}

sealed class BlobControlMessage {
  final String sha256Hex;
  const BlobControlMessage(this.sha256Hex);
}

final class BlobWantMessage extends BlobControlMessage {
  final List<int> missingIndices;

  const BlobWantMessage({
    required String sha256Hex,
    required this.missingIndices,
  }) : super(sha256Hex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobWantMessage &&
          sha256Hex == other.sha256Hex &&
          _listEquals(missingIndices, other.missingIndices);

  @override
  int get hashCode => Object.hash(sha256Hex, Object.hashAll(missingIndices));

  static bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class BlobNoneMessage extends BlobControlMessage {
  const BlobNoneMessage({required String sha256Hex}) : super(sha256Hex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobNoneMessage && sha256Hex == other.sha256Hex;

  @override
  int get hashCode => sha256Hex.hashCode;
}

String encodeBlobWant(String sha256Hex, List<int> missingIndices) {
  return jsonEncode({
    't': 'want',
    'h': sha256Hex,
    'm': missingIndices,
  });
}

String encodeBlobNone(String sha256Hex) {
  return jsonEncode({
    't': 'none',
    'h': sha256Hex,
  });
}

BlobControlMessage? parseBlobControl(String text) {
  if (text.length > kBlobMaxControlChars) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;
    final map = decoded;

    final type = map['t'];
    if (type is! String) return null;

    final hash = map['h'];
    if (hash is! String || hash.length != 64) return null;
    for (var i = 0; i < 64; i++) {
      final code = hash.codeUnitAt(i);
      final isDigit = code >= 0x30 && code <= 0x39;
      final isLowerHex = code >= 0x61 && code <= 0x66;
      if (!isDigit && !isLowerHex) return null;
    }

    if (type == 'none') {
      if (map.length != 2) return null;
      if (!map.containsKey('t') || !map.containsKey('h')) return null;
      return BlobNoneMessage(sha256Hex: hash);
    } else if (type == 'want') {
      if (map.length != 3) return null;
      if (!map.containsKey('t') || !map.containsKey('h') || !map.containsKey('m')) {
        return null;
      }
      final rawM = map['m'];
      if (rawM is! List || rawM.isEmpty || rawM.length > 160) return null;

      final indices = <int>[];
      int? prev;
      for (final item in rawM) {
        if (item is! num) return null;
        if (item % 1 != 0) return null;
        final val = item.toInt();
        if (val < 0) return null;
        if (prev != null && val <= prev) return null;
        indices.add(val);
        prev = val;
      }
      return BlobWantMessage(sha256Hex: hash, missingIndices: indices);
    }
    return null;
  } catch (_) {
    return null;
  }
}
