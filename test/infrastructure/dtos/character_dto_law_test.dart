import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterDto codec law', () {
    List<Map<String, dynamic>> loadLegacyCharacterMaps() {
      final maps = <Map<String, dynamic>>[];

      final regressionFile =
          File('test/fixtures/legacy_character_regression.json');
      if (regressionFile.existsSync()) {
        final decoded =
            json.decode(regressionFile.readAsStringSync()) as Map<String, dynamic>;
        maps.add(decoded);
      }

      for (var era = 1; era <= 9; era++) {
        final storageFile =
            File('test/fixtures/legacy_storage/E$era/storage.json');
        if (!storageFile.existsSync()) continue;
        final storage =
            json.decode(storageFile.readAsStringSync()) as Map<String, dynamic>;
        final boxes = storage['boxes'] as Map<String, dynamic>? ?? const {};
        final charsBox =
            boxes['dn_characters_v1'] as Map<String, dynamic>? ?? const {};
        final rawRoster = charsBox['saved_characters_roster_v1'];
        final rosterList = rawRoster is String
            ? json.decode(rawRoster) as List<dynamic>
            : rawRoster is List<dynamic>
                ? rawRoster
                : const <dynamic>[];
        for (final entry in rosterList) {
          if (entry is Map) {
            maps.add(Map<String, dynamic>.from(entry));
          }
        }
      }
      return maps;
    }

    List<Map<String, dynamic>> generateSeededCharacterMaps({
      required int count,
      int seed = 12082026,
    }) {
      final rng = Random(seed);
      final levels = [-5, 0, 1, 3, 5, 10, 20, 25, 99, 'bad', null];
      final classLevels = [-5, 0, 1, 3, 5, 10, 20, 25, 99, null];
      final strengths = [-10, 0, 1, 8, 10, 18, 30, 45, 99, 'bad', null];
      final names = [
        'Valeros',
        'Merlin',
        'Sir Galahad',
        '',
        null,
        12345,
      ];

      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < count; i++) {
        final m = <String, dynamic>{
          'id': i % 7 == 0 ? {'slug': 'char_$i'} : 'char_$i',
          'level': levels[rng.nextInt(levels.length)],
          'progression': {
            'classes': [
              {
                'classRef': {'slug': 'fighter', 'displayName': 'Fighter'},
                'level': classLevels[rng.nextInt(classLevels.length)],
              },
            ],
          },
          'strength': strengths[rng.nextInt(strengths.length)],
          'dexterity': rng.nextInt(25) + 1,
          'constitution': rng.nextInt(25) + 1,
          'intelligence': rng.nextInt(25) + 1,
          'wisdom': rng.nextInt(25) + 1,
          'charisma': rng.nextInt(25) + 1,
        };
        final pickedName = names[rng.nextInt(names.length)];
        if (pickedName != null || rng.nextBool()) {
          if (pickedName != null) {
            m['name'] = pickedName;
          }
          // Otherwise omit 'name' completely to exercise missing name.
        }
        if (rng.nextBool()) {
          m['customHomebrewAttr'] = rng.nextInt(1000);
          m['extraUnknownNested'] = {'tag': 'seed_$i', 'flag': rng.nextBool()};
        }
        out.add(m);
      }
      return out;
    }

    test(
        'CharacterDto.fromMap(m).toDomain().toMap() == Character.fromMap(m).toMap() '
        'and CharacterDto.fromDomain(c).toMap() == c.toMap() over legacy fixtures and 300+ seeded maps',
        () {
      final legacyMaps = loadLegacyCharacterMaps();
      expect(legacyMaps.length, greaterThanOrEqualTo(19));

      final seededMaps = generateSeededCharacterMaps(count: 320);
      expect(seededMaps.length, greaterThanOrEqualTo(300));

      final allMaps = [...legacyMaps, ...seededMaps];
      for (var i = 0; i < allMaps.length; i++) {
        final m = allMaps[i];
        final expectedDomain = Character.fromMap(m);
        final expectedMap = expectedDomain.toMap();

        final fromDto = CharacterDto.fromMap(m).toDomain();
        expect(
          fromDto.toMap(),
          equals(expectedMap),
          reason: 'Mismatch on fromMap(m).toDomain().toMap() at index $i',
        );

        final dtoRoundTrip = CharacterDto.fromDomain(expectedDomain).toMap();
        expect(
          dtoRoundTrip,
          equals(expectedMap),
          reason: 'Mismatch on fromDomain(c).toMap() at index $i',
        );
      }
    });
  });
}
