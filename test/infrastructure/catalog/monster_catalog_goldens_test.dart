import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/monster_golden_serializer.dart';
import '../../support/step6_normalizer.dart';

const _monsterCatalogPath =
    'test/fixtures/catalog_goldens/monster_catalog_golden.json';
const _monsterLookupsPath =
    'test/fixtures/catalog_goldens/monster_lookups_golden.json';

Map<String, dynamic> _readFixture(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'Missing monster catalog golden fixture $path. '
        'Generate explicitly with UPDATE_STEP4_MONSTER_FIXTURES=1.',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('Fix 4.1: Bundled monster and summon catalog goldens', () {
    test('bundled monsters and summon presets match golden field by field', () {
      final expected = _readFixture(_monsterCatalogPath);
      final actual = jsonDecode(jsonEncode(buildMonsterCatalogGoldenMap()))
          as Map<String, dynamic>;

      expect(actual['monsterCount'], equals(expected['monsterCount']));
      expect(
        actual['summonPresetCount'],
        equals(expected['summonPresetCount']),
      );
      expect(
        actual['summonStatBlockCount'],
        equals(expected['summonStatBlockCount']),
      );

      final expMonsters = expected['monsters'] as Map<String, dynamic>;
      final actMonsters = actual['monsters'] as Map<String, dynamic>;
      expect(actMonsters.keys.toList(), equals(expMonsters.keys.toList()));

      for (final id in expMonsters.keys) {
        final diff =
            firstJsonDiff(expMonsters[id], actMonsters[id], 'monster.$id');
        expect(
          diff,
          isNull,
          reason: 'Monster catalog golden mismatch at $id: $diff',
        );
      }

      final expPresets = expected['summonPresets'] as Map<String, dynamic>;
      final actPresets = actual['summonPresets'] as Map<String, dynamic>;
      expect(actPresets.keys.toList(), equals(expPresets.keys.toList()));

      for (final presetId in expPresets.keys) {
        final expPreset = expPresets[presetId] as Map<String, dynamic>;
        final actPreset = actPresets[presetId] as Map<String, dynamic>;
        final expBlocks = expPreset['statBlocks'] as Map<String, dynamic>;
        final actBlocks = actPreset['statBlocks'] as Map<String, dynamic>;
        expect(actBlocks.keys.toList(), equals(expBlocks.keys.toList()));

        for (final sbId in expBlocks.keys) {
          final diff = firstJsonDiff(
            expBlocks[sbId],
            actBlocks[sbId],
            'summonPreset.$presetId.$sbId',
          );
          expect(
            diff,
            isNull,
            reason:
                'Summon preset golden mismatch at $presetId/$sbId: $diff',
          );
        }

        final presetDiff =
            firstJsonDiff(expPreset, actPreset, 'summonPreset.$presetId');
        expect(
          presetDiff,
          isNull,
          reason: 'Summon preset metadata mismatch at $presetId: $presetDiff',
        );
      }
    });

    test('monster codex and summon lookups match golden in exact order', () {
      final expected = _readFixture(_monsterLookupsPath);
      final actual = jsonDecode(jsonEncode(buildMonsterLookupsGoldenMap()))
          as Map<String, dynamic>;

      final diff = firstJsonDiff(expected, actual, 'monsterLookups');
      expect(
        diff,
        isNull,
        reason: 'Monster lookups golden mismatch: $diff',
      );
    });
  });
}
