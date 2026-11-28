import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'opaque_id.dart';
import 'secure_random.dart';

/// Cryptographic and security helper utilities for DangerouslyNerdy 5e Toolkit.
class CryptoUtils {
  static const String _roomCharset =
      '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Unambiguous chars

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
  static String generateHostKey() => newOpaqueId();

  /// Computes SHA-256 hex digest for passwordless hostKey verification.
  static String sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  // =========================================================================
  // 6-WORD MNEMONIC PASSKEY CODEC
  // =========================================================================
  static const List<String> _dndWordList = [
    // 0-31
    'dragon', 'wizard', 'shield', 'potion', 'goblin', 'scroll', 'tavern',
    'shadow',
    'paladin', 'dagger', 'cleric', 'phoenix', 'dungeon', 'temple', 'rogue',
    'knight',
    'arcane', 'flame', 'silver', 'crown', 'hammer', 'portal', 'relic',
    'sorcerer',
    'bard', 'druid', 'monk', 'ranger', 'warlock', 'castle', 'forest', 'glory',
    // 32-63
    'citadel', 'crystal', 'emerald', 'falcon', 'griffin', 'harbor', 'island',
    'jewel',
    'kraken', 'lantern', 'mystic', 'nebula', 'oracle', 'prism', 'quest',
    'raven',
    'scepter', 'titan', 'unicorn', 'vortex', 'wyvern', 'zenith', 'amber',
    'blade',
    'cavern', 'domain', 'elixir', 'fathom', 'granite', 'haven', 'iron',
    'jasper',
    // 64-95
    'keep', 'legend', 'mantle', 'nexus', 'oasis', 'parchment', 'quartz',
    'realm',
    'sanctuary', 'tome', 'umbra', 'valiant', 'warden', 'yonder', 'zephyr',
    'aurora',
    'beacon', 'compass', 'dynasty', 'enigma', 'forge', 'gargoyle', 'horizon',
    'illusion',
    'javelin', 'kindred', 'lore', 'mirage', 'nomad', 'obsidian', 'pyre',
    'quiver',
    // 96-127
    'runic', 'sigil', 'talon', 'unity', 'valor', 'weaver', 'yearling', 'zodiac',
    'abyss', 'basilisk', 'cinder', 'dire', 'elemental', 'fey', 'golem', 'hydra',
    'infernal', 'kobold', 'lich', 'medusa', 'necromancer', 'owlbear', 'pegasus',
    'quasit',
    'specter', 'troll', 'undead', 'vampire', 'wraith', 'xorn', 'yeti', 'zombie',
    // 128-159
    'anvil', 'bravery', 'chalice', 'destiny', 'echo', 'fortune', 'grimoire',
    'herald',
    'insight', 'journey', 'karma', 'legacy', 'monolith', 'noble', 'omen',
    'passage',
    'radiance', 'sanctum', 'triumph', 'vault', 'wisdom', 'alchemy', 'bastion',
    'covenant',
    'dawn', 'eclipse', 'frost', 'glyph', 'honor', 'infinite', 'judgment',
    'solitude',
    // 160-191
    'mastery', 'bastille', 'outpost', 'prowess', 'quintessence', 'rune',
    'sovereign', 'tribute',
    'unbroken', 'vow', 'whisper', 'zeal', 'astral', 'bone', 'chaos', 'divine',
    'ether', 'fang', 'ghost', 'haunt', 'idol', 'judge', 'spirit', 'lightning',
    'memory', 'night', 'oath', 'phantom', 'tempest', 'thunder', 'universe',
    'vision',
    // 192-223
    'wild', 'yearn', 'zealot', 'armor', 'battle', 'crest', 'deliverance',
    'emblem',
    'frontier', 'guild', 'hero', 'immortal', 'justice', 'kingdom', 'legendary',
    'myth',
    'majesty', 'order', 'praise', 'questing', 'royal', 'sanction', 'throne',
    'harmony',
    'victory', 'warrior', 'crusade', 'apogee', 'aegis', 'bolt', 'champion',
    'dragonfire',
    // 224-255
    'empower', 'flameheart', 'guardian', 'refuge', 'infinity', 'verdict',
    'fortress', 'luminary',
    'maelstrom', 'chronicle', 'summit', 'paragon', 'spellcraft', 'vanguard',
    'sentinel', 'watchtower',
    'wyrm', 'sentry', 'starfall', 'celestial', 'beaconlight', 'sunblade',
    'moonshadow', 'bloodline',
    'crossroad', 'sanctity', 'truename', 'elderwood', 'highland', 'drakefire',
    'deepstone', 'everlight',
  ];

  /// Checks whether a given phrase is a 6-word phrase from the legacy mnemonic word list.
  static bool isLegacyMnemonicPhrase(String phrase) {
    final words = phrase.trim().toLowerCase().split(RegExp(r'\s+'));
    return words.length == 6 && words.every((w) => _dndWordList.contains(w));
  }

  /// Extracts a raw host key / UUID from user input or formatted text.
  /// Handles raw UUIDs, `"HostKey: <uuid>"`, or copied passkey text blocks.
  static String extractHostKey(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // If text contains "HostKey:" or "Host Key:"
    final hostKeyMatch =
        RegExp(r'Host\s*Key\s*:\s*([^\s\n\r]+)', caseSensitive: false)
            .firstMatch(trimmed);
    if (hostKeyMatch != null) {
      return hostKeyMatch.group(1)!.trim();
    }

    // Match standard UUID v4 format if present in text
    final uuidMatch = RegExp(
            r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
        .firstMatch(trimmed);
    if (uuidMatch != null) {
      return uuidMatch.group(0)!.trim();
    }

    return trimmed;
  }
}
