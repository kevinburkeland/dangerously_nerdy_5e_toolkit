import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';

void main() {
  group('Fix 5.3 Guard Law: CryptoUtils.sha256Hex matches NIST KATs and package:crypto', () {
    test('NIST SHA-256 known-answer tests', () {
      expect(
        CryptoUtils.sha256Hex(''),
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );
      expect(
        CryptoUtils.sha256Hex('abc'),
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
      expect(
        CryptoUtils.sha256Hex(
          'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
        ),
        equals(
          '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
        ),
      );
    });

    test(
      '1,050 seeded strings (lengths 0..300, multi-byte UTF-8, and SHA-256 block boundaries 55, 56, 63, 64, 65, 119, 120)',
      () {
        final rng = Random(140503);
        const edgeLengths = [0, 1, 55, 56, 63, 64, 65, 119, 120, 127, 128, 300];
        const alphabet =
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_-+=[]{};:,.<>/? \n\téñüΩ漢🎲⚔️';
        final runes = alphabet.runes.toList();

        for (final len in edgeLengths) {
          final ascii = List.generate(len, (i) => String.fromCharCode(97 + (i % 26))).join();
          final expected = sha256.convert(utf8.encode(ascii)).toString();
          expect(
            CryptoUtils.sha256Hex(ascii),
            equals(expected),
            reason: 'Block-boundary ASCII length $len mismatch',
          );
        }

        for (var seed = 0; seed < 1050; seed++) {
          final len = rng.nextInt(301);
          final buf = StringBuffer();
          for (var i = 0; i < len; i++) {
            buf.writeCharCode(runes[rng.nextInt(runes.length)]);
          }
          final s = buf.toString();
          final expected = sha256.convert(utf8.encode(s)).toString();
          expect(
            CryptoUtils.sha256Hex(s),
            equals(expected),
            reason: 'Seed $seed (len=$len) mismatch',
          );
        }
      },
    );
  });
}
