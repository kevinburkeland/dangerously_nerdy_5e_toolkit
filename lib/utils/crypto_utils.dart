import 'dart:convert';
import 'dart:typed_data';
import 'secure_random.dart';

/// Cryptographic and security helper utilities for DangerouslyNerdy 5e Toolkit.
class CryptoUtils {
  static const String _roomCharset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Unambiguous chars

  /// Generates an unguessable 6-character campaign room code (e.g., "ROOM-A1B2C3")
  static String generateRoomCode({bool includePrefix = true}) {
    final buffer = StringBuffer();
    if (includePrefix) {
      buffer.write('ROOM-');
    }
    for (int i = 0; i < 6; i++) {
      final idx = secureRandom.nextInt(_roomCharset.length);
      buffer.write(_roomCharset[idx]);
    }
    return buffer.toString();
  }

  /// Generates a cryptographically secure UUID v4 string for host administrative passkeys
  static String generateHostKey() {
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = secureRandom.nextInt(256);
    }
    // Set UUID v4 variant & version
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) {
      return bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Computes SHA-256 hex digest for passwordless hostKey verification
  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = _sha256(Uint8List.fromList(bytes));
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Pure Dart SHA-256 implementation (Zero external dependency)
  static Uint8List _sha256(Uint8List message) {
    // Initial hash values (first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19)
    final h = Uint32List.fromList([
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]);

    // Round constants (first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311)
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

    // Pre-processing (Padding)
    final msgLen = message.length;
    final bitLen = msgLen * 8;
    final padLen = (msgLen % 64 < 56) ? (56 - (msgLen % 64)) : (120 - (msgLen % 64));
    final totalLen = msgLen + padLen + 8;
    final padded = Uint8List(totalLen);
    padded.setRange(0, msgLen, message);
    padded[msgLen] = 0x80;

    // Append original bit length as 64-bit big-endian integer
    final bd = ByteData.view(padded.buffer);
    bd.setUint32(totalLen - 4, bitLen & 0xFFFFFFFF, Endian.big);
    bd.setUint32(totalLen - 8, (bitLen >> 32) & 0xFFFFFFFF, Endian.big);

    // Process 512-bit (64-byte) blocks
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

  // =========================================================================
  // 6-WORD MNEMONIC PASSKEY CODEC
  // =========================================================================
  static const List<String> _dndWordList = [
    'dragon', 'wizard', 'shield', 'potion', 'goblin', 'scroll', 'tavern', 'shadow',
    'paladin', 'dagger', 'cleric', 'phoenix', 'dungeon', 'temple', 'rogue', 'knight',
    'arcane', 'flame', 'silver', 'crown', 'hammer', 'portal', 'relic', 'sorcerer',
    'bard', 'druid', 'monk', 'ranger', 'warlock', 'castle', 'forest', 'glory',
    'citadel', 'crystal', 'emerald', 'falcon', 'griffin', 'harbor', 'island', 'jewel',
    'kraken', 'lantern', 'mystic', 'nebula', 'oracle', 'prism', 'quest', 'raven',
    'scepter', 'titan', 'unicorn', 'vortex', 'wyvern', 'zenith', 'amber', 'blade',
    'cavern', 'domain', 'elixir', 'fathom', 'granite', 'haven', 'iron', 'jasper',
    'keep', 'legend', 'mantle', 'nexus', 'oasis', 'parchment', 'quartz', 'realm',
    'sanctuary', 'tome', 'umbra', 'valiant', 'warden', 'yonder', 'zephyr', 'aurora',
    'beacon', 'compass', 'dynasty', 'enigma', 'forge', 'gargoyle', 'horizon', 'illusion',
    'javelin', 'kindred', 'lore', 'mirage', 'nomad', 'obsidian', 'pyre', 'quiver',
    'runic', 'sigil', 'talon', 'unity', 'valor', 'weaver', 'yearling', 'zodiac',
    'abyss', 'basilisk', 'cinder', 'dire', 'elemental', 'fey', 'golem', 'hydra',
    'infernal', 'kobold', 'lich', 'medusa', 'necromancer', 'owlbear', 'pegasus', 'quasit',
    'specter', 'troll', 'undead', 'vampire', 'wraith', 'xorn', 'yeti', 'zombie',
    'anvil', 'bravery', 'chalice', 'destiny', 'echo', 'fortune', 'grimoire', 'herald',
    'insight', 'journey', 'karma', 'legacy', 'monolith', 'noble', 'omen', 'passage',
    'radiance', 'sanctum', 'triumph', 'vault', 'wisdom', 'alchemy', 'bastion', 'covenant',
    'dawn', 'eclipse', 'frost', 'glyph', 'honor', 'infinite', 'judgment', 'legacy',
    'mastery', 'nexus', 'outpost', 'prowess', 'quintessence', 'rune', 'sovereign', 'tribute',
    'unbroken', 'vow', 'whisper', 'zeal', 'astral', 'bone', 'chaos', 'divine',
    'ether', 'fang', 'ghost', 'haunt', 'idol', 'judge', 'karma', 'lightning',
    'memory', 'night', 'oath', 'phantom', 'spirit', 'thunder', 'universe', 'vision',
    'wild', 'yearn', 'zealot', 'armor', 'battle', 'crest', 'deliverance', 'emblem',
    'frontier', 'guild', 'hero', 'immortal', 'justice', 'kingdom', 'legendary', 'myth',
    'noble', 'order', 'praise', 'questing', 'royal', 'sanction', 'throne', 'unity',
    'victory', 'warrior', 'crusade', 'zenith', 'aegis', 'bolt', 'champion', 'dragonfire',
    'empower', 'flameheart', 'guardian', 'haven', 'infinity', 'justice', 'keep', 'luminary',
  ];

  /// Encodes a UUID hostKey into a 6-word human-friendly mnemonic phrase
  static String encodeHostKeyToMnemonic(String hostKey) {
    final clean = hostKey.replaceAll('-', '').toLowerCase();
    if (clean.length < 12) return 'dragon shield potion wizard goblin scroll';

    final words = <String>[];
    for (int i = 0; i < 6; i++) {
      final hexChunk = clean.substring(i * 2, (i + 1) * 2);
      final byteVal = int.tryParse(hexChunk, radix: 16) ?? 0;
      final wordIndex = byteVal % _dndWordList.length;
      words.add(_dndWordList[wordIndex]);
    }
    return words.join(' ');
  }

  /// Verifies whether a given mnemonic represents a valid passkey format
  static bool isValidMnemonic(String phrase) {
    final words = phrase.trim().toLowerCase().split(RegExp(r'\s+'));
    return words.length == 6 && words.every((w) => _dndWordList.contains(w));
  }

  /// Extracts a raw host key / UUID from user input or formatted text.
  /// Handles raw UUIDs, `"HostKey: <uuid>"`, or copied passkey text blocks.
  static String extractHostKey(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // If text contains "HostKey:" or "Host Key:"
    final hostKeyMatch = RegExp(r'Host\s*Key\s*:\s*([^\s\n\r]+)', caseSensitive: false).firstMatch(trimmed);
    if (hostKeyMatch != null) {
      return hostKeyMatch.group(1)!.trim();
    }

    // Match standard UUID v4 format if present in text
    final uuidMatch = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').firstMatch(trimmed);
    if (uuidMatch != null) {
      return uuidMatch.group(0)!.trim();
    }

    return trimmed;
  }
}
