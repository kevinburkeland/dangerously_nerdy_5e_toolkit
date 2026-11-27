import 'dart:convert';
import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_bundle.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/monster_golden_serializer.dart';
import '../../support/step6_normalizer.dart';
import '../../test_doubles/hive_test_harness.dart';

const _dir = 'test/fixtures/stored_formats';

Map<String, dynamic> _readJson(String name) {
  final file = File('$_dir/$name');
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'Missing stored-format monster fixture $_dir/$name. '
        'Generate explicitly with UPDATE_STEP4_MONSTER_FIXTURES=1.',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _assertLoadedMonstersMatch(
  HomebrewPersistenceService svc,
  Map<String, dynamic> expectedSection,
  String contextLabel,
) async {
  await svc.syncToLibraries();
  final loadedMonsters = await svc.loadCustomMonsters();
  final hbItems = MonsterCodexLibrary.homebrewMonsters;
  final hbIds = hbItems.map((m) => m.id).toSet();

  final actual = jsonDecode(jsonEncode({
    'monsters': loadedMonsters.map((m) {
      final item = MonsterCodexLibrary.getMonsterById(m.id.slug);
      expect(
        item,
        isNotNull,
        reason: '$contextLabel: missing monster ${m.id.slug} in MonsterCodexLibrary',
      );
      return {
        'slug': m.id.slug,
        'domainMonster': serializeDomainMonster(m),
        'codexItem': serializeMonsterForGolden(item!),
        'statBlock': serializeStatBlockForGolden(item.sourceStatBlock),
      };
    }).toList(),
    'codexState': {
      'homebrewIds': hbItems.map((m) => m.id).toList(),
      'homebrewCrBands': {
        'all': MonsterCodexLibrary.allMonsters
            .where((m) => hbIds.contains(m.id))
            .map((m) => m.id)
            .toList(),
        'cr0ToQuarter': MonsterCodexLibrary.getCr0ToQuarterMonsters()
            .where((m) => hbIds.contains(m.id))
            .map((m) => m.id)
            .toList(),
        'crHalfToOne': MonsterCodexLibrary.getCrHalfToOneMonsters()
            .where((m) => hbIds.contains(m.id))
            .map((m) => m.id)
            .toList(),
        'crTwoToFour': MonsterCodexLibrary.getCrTwoToFourMonsters()
            .where((m) => hbIds.contains(m.id))
            .map((m) => m.id)
            .toList(),
        'crFiveToEight': MonsterCodexLibrary.getCrFiveToEightMonsters()
            .where((m) => hbIds.contains(m.id))
            .map((m) => m.id)
            .toList(),
        'crNinePlus': MonsterCodexLibrary.getCrNinePlusMonsters()
            .where((m) => hbIds.contains(m.id))
            .map((m) => m.id)
            .toList(),
      },
      'homebrewSortModes2024': {
        for (final mode in MonsterSortMode.values)
          mode.name: sortMonsterIdsByMode(hbItems, mode, DmRulesEdition.v2024),
      },
    },
  })) as Map<String, dynamic>;

  final expMonsters = (expectedSection['monsters'] as List).cast<Map<String, dynamic>>();
  final actMonsters = (actual['monsters'] as List).cast<Map<String, dynamic>>();
  expect(
    actMonsters.map((e) => e['slug']).toList(),
    equals(expMonsters.map((e) => e['slug']).toList()),
    reason: '$contextLabel: monster slug list mismatch',
  );

  for (var i = 0; i < expMonsters.length; i++) {
    final slug = expMonsters[i]['slug'] as String;
    final diff = firstJsonDiff(
      expMonsters[i],
      actMonsters[i],
      '$contextLabel.monster.$slug',
    );
    expect(
      diff,
      isNull,
      reason: 'Monster stored-format mismatch ($contextLabel, $slug): $diff',
    );
  }

  final codexDiff = firstJsonDiff(
    expectedSection['codexState'],
    actual['codexState'],
    '$contextLabel.codexState',
  );
  expect(
    codexDiff,
    isNull,
    reason: 'Monster codex state mismatch ($contextLabel): $codexDiff',
  );
}

void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await hive.setUpInMemory();
    MonsterCodexLibrary.clearHomebrewMonsters();
    MonsterItem.clearCaches();
  });

  tearDown(() async {
    MonsterCodexLibrary.clearHomebrewMonsters();
    MonsterItem.clearCaches();
    await hive.tearDown();
  });

  group('Fix 4.2: Stored monster, bundle, and backup format load law', () {
    test('stored homebrew monster JSON strings load and sync identically', () async {
      final expected = _readJson('expected_loaded_monsters.json');
      final stored = _readJson('homebrew_monsters_stored.json');

      final db = AppDatabaseService();
      await db.put(
        AppDatabaseService.boxHomebrew,
        'dn_homebrew_monsters_v1',
        List<String>.from(stored['storedJsonList'] as List),
      );

      final svc = HomebrewPersistenceService();
      await _assertLoadedMonstersMatch(
        svc,
        expected['directStored'] as Map<String, dynamic>,
        'direct_stored_json',
      );
    });

    test('exported HomebrewBundle restores monsters identically', () async {
      final expected = _readJson('expected_loaded_monsters.json');
      final bundleMap = _readJson('monster_exported_homebrew_bundle.json');
      final bundle = HomebrewBundle.fromMap(bundleMap);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final analysis =
          const HomebrewMergeResolver().analyzeBundle(incomingBundle: bundle);
      await svc.importResolvedBundle(analysis);
      await _assertLoadedMonstersMatch(
        svc,
        expected['exportedAndBackedUp'] as Map<String, dynamic>,
        'monster_exported_homebrew_bundle',
      );
    });

    test('exported raw bundle restores monsters identically', () async {
      final expected = _readJson('expected_loaded_monsters.json');
      final bundleMap = _readJson('monster_exported_bundle.json');
      final bundle = HomebrewBundle.fromMap(bundleMap);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final analysis =
          const HomebrewMergeResolver().analyzeBundle(incomingBundle: bundle);
      await svc.importResolvedBundle(analysis);
      await _assertLoadedMonstersMatch(
        svc,
        expected['exportedAndBackedUp'] as Map<String, dynamic>,
        'monster_exported_raw_bundle',
      );
    });

    test('app backup JSON restores homebrew monsters identically', () async {
      final expected = _readJson('expected_loaded_monsters.json');
      final backupFile = File('$_dir/monster_app_backup.json');
      expect(backupFile.existsSync(), isTrue);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final result = await AppBackupService()
          .importFullBackupJson(backupFile.readAsStringSync());
      expect(
        result.success,
        isTrue,
        reason: 'App backup restore failed: ${result.errorMessage}',
      );
      await _assertLoadedMonstersMatch(
        svc,
        expected['exportedAndBackedUp'] as Map<String, dynamic>,
        'monster_app_backup',
      );
    });

    test('DM backup snapshot restores homebrew monsters identically', () async {
      final expected = _readJson('expected_loaded_monsters.json');
      final dmFile = File('$_dir/monster_dm_backup.json');
      expect(dmFile.existsSync(), isTrue);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final ok = await DmBackupService()
          .restoreFullSystemSnapshot(dmFile.readAsStringSync());
      expect(ok, isTrue, reason: 'DM backup restore returned false');
      await _assertLoadedMonstersMatch(
        svc,
        expected['exportedAndBackedUp'] as Map<String, dynamic>,
        'monster_dm_backup',
      );
    });
  });
}
