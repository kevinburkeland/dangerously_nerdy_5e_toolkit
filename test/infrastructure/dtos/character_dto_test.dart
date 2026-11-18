import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';

void main() {
  group('CharacterDto thin codec', () {
    test('round-trips raw map keys through fromMap and toMap', () {
      final inputMap = <String, dynamic>{
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

      final dto = CharacterDto.fromMap(inputMap);
      expect(dto.name, equals('Valeros'));

      final outputMap = dto.toMap();
      expect(outputMap['id'], equals('char_101'));
      expect(outputMap['name'], equals('Valeros'));
      expect(outputMap['customHomebrewAttr'], equals(42));
      expect(
          outputMap['thirdPartyTags'], equals(['veteran', 'battle-forged']));
      expect(outputMap['vtt_meta']['token_url'],
          equals('https://vtt.example/valeros.png'));
    });

    test('toDomain and fromDomain match Character.fromMap and Character.toMap',
        () {
      final inputMap = <String, dynamic>{
        'id': 'char_202',
        'name': 'Seoni',
        'level': 7,
        'strength': 10,
      };

      final fromDto = CharacterDto.fromMap(inputMap).toDomain();
      final direct = Character.fromMap(inputMap);
      expect(fromDto.toMap(), equals(direct.toMap()));
      expect(CharacterDto.fromDomain(direct).toMap(), equals(direct.toMap()));
    });

    test('safely handles missing or erroneous keys in toDomain without throwing',
        () {
      final brokenMap = <String, dynamic>{
        'id': null,
        'name': 12345,
        'level': 'invalid_string',
        'strength': null,
      };

      final dto = CharacterDto.fromMap(brokenMap);
      expect(dto.name, equals('Unknown Adventurer'));
      expect(dto.toDomain().toMap(), equals(Character.fromMap(brokenMap).toMap()));
    });
  });
}
