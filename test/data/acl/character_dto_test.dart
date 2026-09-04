import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/data/acl/character_dto.dart';

void main() {
  group('CharacterDto Serialization & ACL Integrity', () {
    test('round-trips arbitrary unknown homebrew fields with 100% fidelity', () {
      final inputJson = <String, dynamic>{
        'id': 'char_101',
        'name': 'Valeros',
        'level': 5,
        'strength': 18,
        'customHomebrewAttr': 42,
        'thirdPartyTags': ['veteran', 'battle-forged'],
        'vtt_meta': {
          'token_url': 'https://vtt.example/valeros.png',
          'scale': 1.0,
        },
      };

      final dto = CharacterDto.fromJson(inputJson);

      expect(dto.id, equals('char_101'));
      expect(dto.name, equals('Valeros'));
      expect(dto.level, equals(5));
      expect(dto.strength, equals(18));
      expect(dto.unparsedPayload['customHomebrewAttr'], equals(42));
      expect(dto.unparsedPayload['thirdPartyTags'], equals(['veteran', 'battle-forged']));

      final outputJson = dto.toJson();

      expect(outputJson['id'], equals('char_101'));
      expect(outputJson['name'], equals('Valeros'));
      expect(outputJson['level'], equals(5));
      expect(outputJson['strength'], equals(18));
      expect(outputJson['customHomebrewAttr'], equals(42));
      expect(outputJson['thirdPartyTags'], equals(['veteran', 'battle-forged']));
      expect(outputJson['vtt_meta']['token_url'], equals('https://vtt.example/valeros.png'));
    });

    test('strictly clamps level between 1 and 20 and strength between 1 and 30', () {
      final oobJson = <String, dynamic>{
        'id': 'oob_char',
        'name': 'Godling',
        'level': -5,
        'strength': 99,
      };

      final dto = CharacterDto.fromJson(oobJson);

      expect(dto.level, equals(1));
      expect(dto.strength, equals(30));

      final upperOobJson = <String, dynamic>{
        'level': 50,
        'strength': -10,
      };

      final dtoUpper = CharacterDto.fromJson(upperOobJson);

      expect(dtoUpper.level, equals(20));
      expect(dtoUpper.strength, equals(1));
    });

    test('safely defaults missing or erroneous keys without throwing TypeErrors', () {
      final brokenJson = <String, dynamic>{
        'id': null,
        'name': 12345, // invalid type
        'level': 'invalid_string', // invalid type
        'strength': null,
      };

      final dto = CharacterDto.fromJson(brokenJson);

      expect(dto.id, equals(''));
      expect(dto.name, equals('Unknown Adventurer'));
      expect(dto.level, equals(1));
      expect(dto.strength, equals(10));
    });

    test('supports copyWith and value equality', () {
      final dto1 = CharacterDto.fromJson({
        'id': '1',
        'name': 'Hero',
        'level': 3,
        'strength': 14,
      });

      final dto2 = dto1.copyWith(level: 4);

      expect(dto1.level, equals(3));
      expect(dto2.level, equals(4));
      expect(dto2.name, equals('Hero'));
    });
  });
}
