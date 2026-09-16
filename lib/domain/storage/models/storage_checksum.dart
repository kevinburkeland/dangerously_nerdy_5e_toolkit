import 'dart:convert';
import 'dart:typed_data';

/// Pure Dart SHA-256 and constant-time digest comparison utility for the domain layer.
/// Zero external package dependencies and zero Flutter engine dependencies.
class StorageChecksum {
  const StorageChecksum._();

  /// Computes the standard SHA-256 hex digest for [vaultId] + [payloadBytes].
  static String computeBundleChecksum(String vaultId, Uint8List payloadBytes) {
    final vaultBytes = utf8.encode(vaultId);
    final combined = Uint8List(vaultBytes.length + payloadBytes.length);
    combined.setRange(0, vaultBytes.length, vaultBytes);
    combined.setRange(vaultBytes.length, combined.length, payloadBytes);
    return computeSha256(combined);
  }

  /// Verifies [checksum] against `SHA-256(vaultId + payloadBytes)` using constant-time comparison.
  static bool verifyBundleChecksum({
    required String vaultId,
    required Uint8List payloadBytes,
    required String expectedChecksum,
  }) {
    final actual = computeBundleChecksum(vaultId, payloadBytes);
    return constantTimeEquals(actual.toLowerCase(), expectedChecksum.toLowerCase());
  }

  /// Constant-time string equality check to eliminate timing side-channel attacks.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Computes SHA-256 digest on raw bytes, returning a 64-character lowercase hex string.
  static String computeSha256(Uint8List message) {
    final digest = _sha256(message);
    final buffer = StringBuffer();
    for (int i = 0; i < digest.length; i++) {
      buffer.write(digest[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List _sha256(Uint8List message) {
    final h = Uint32List.fromList([
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]);

    const k = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    final msgLen = message.length;
    final bitLen = msgLen * 8;
    final padLen = (msgLen % 64 < 56) ? (56 - (msgLen % 64)) : (120 - (msgLen % 64));
    final totalLen = msgLen + padLen + 8;
    final padded = Uint8List(totalLen);
    padded.setRange(0, msgLen, message);
    padded[msgLen] = 0x80;

    final bd = ByteData.view(padded.buffer);
    bd.setUint32(totalLen - 4, bitLen & 0xFFFFFFFF, Endian.big);
    bd.setUint32(totalLen - 8, (bitLen >> 32) & 0xFFFFFFFF, Endian.big);

    final w = Uint32List(64);
    for (int chunkStart = 0; chunkStart < totalLen; chunkStart += 64) {
      for (int t = 0; t < 16; t++) {
        w[t] = bd.getUint32(chunkStart + t * 4, Endian.big);
      }
      for (int t = 16; t < 64; t++) {
        final s0 = _rotr32(w[t - 15], 7) ^ _rotr32(w[t - 15], 18) ^ (w[t - 15] >> 3);
        final s1 = _rotr32(w[t - 2], 17) ^ _rotr32(w[t - 2], 19) ^ (w[t - 2] >> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h[0];
      int b = h[1];
      int c = h[2];
      int d = h[3];
      int e = h[4];
      int f = h[5];
      int g = h[6];
      int hVar = h[7];

      for (int t = 0; t < 64; t++) {
        final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = (hVar + s1 + ch + k[t] + w[t]) & 0xFFFFFFFF;
        final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        hVar = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hVar) & 0xFFFFFFFF;
    }

    final out = Uint8List(32);
    final outBd = ByteData.view(out.buffer);
    for (int i = 0; i < 8; i++) {
      outBd.setUint32(i * 4, h[i], Endian.big);
    }
    return out;
  }

  static int _rotr32(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
}
