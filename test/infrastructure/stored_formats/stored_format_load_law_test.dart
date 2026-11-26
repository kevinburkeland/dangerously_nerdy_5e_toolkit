import 'dart:convert';
import 'dart:io';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_bundle.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/catalog_golden_serializer.dart';
import '../../support/step6_normalizer.dart';
import '../../test_doubles/hive_test_harness.dart';

const _dir = 'test/fixtures/stored_formats';

Map<String, dynamic> _readJson(String name) {
  final file = File('$_dir/$name');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing stored-format fixture $_dir/$name. Generate with UPDATE_STEP4_FIXTURES=1.',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _assertLoadedMatchesExpected(
  HomebrewPersistenceService svc,
  Map<String, dynamic> expected,
  String contextLabel,
) async {
  await svc.syncToLibraries();
  final loadedSpells = await svc.loadCustomSpells();
  final loadedItems = await svc.loadCustomItems();

  final actual = jsonDecode(jsonEncode({
    'spells': loadedSpells.map((s) {
      final libItem = SpellbookLibrary.getSpellById(s.id.slug);
      expect(libItem, isNotNull, reason: '$contextLabel: missing spell ${s.id.slug} in SpellbookLibrary');
      return {
        'slug': s.id.slug,
        'name': s.name,
        'level': s.level,
        'school': s.school,
        'libraryView': serializeSpellForCatalogGolden(libItem!),
      };
    }).toList(),
    'items': loadedItems.map((i) {
      final libItem = MagicItemLibrary.findById(i.id.slug);
      expect(libItem, isNotNull, reason: '$contextLabel: missing item ${i.id.slug} in MagicItemLibrary');
      return {
        'slug': i.id.slug,
        'name': i.name,
        'itemType': i.itemType,
        'rarity': i.rarity,
        'requiresAttunement': i.requiresAttunement,
        'libraryView': serializeItemForCatalogGolden(libItem!),
      };
    }).toList(),
  })) as Map<String, dynamic>;

  final diff = firstJsonDiff(expected, actual, contextLabel);
  expect(diff, isNull, reason: 'Stored-format load law mismatch ($contextLabel): $diff');
}

void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await hive.setUpInMemory();
    SpellbookLibrary.setHomebrewSpells(const []);
    MagicItemLibrary.setHomebrewItems(const []);
  });

  tearDown(() async {
    SpellbookLibrary.setHomebrewSpells(const []);
    MagicItemLibrary.setHomebrewItems(const []);
    await hive.tearDown();
  });

  group('Fix 4.2: Stored homebrew, backup, and bundle format load law', () {
    test('stored homebrew spell and item JSON strings load and sync identically', () async {
      final expected = _readJson('expected_loaded_values.json');
      final spellsFixture = _readJson('homebrew_spells_stored.json');
      final itemsFixture = _readJson('homebrew_items_stored.json');

      final db = AppDatabaseService();
      await db.put(
        AppDatabaseService.boxHomebrew,
        'dn_homebrew_spells_v1',
        List<String>.from(spellsFixture['storedJsonList'] as List),
      );
      await db.put(
        AppDatabaseService.boxHomebrew,
        'dn_homebrew_items_v1',
        List<String>.from(itemsFixture['storedJsonList'] as List),
      );

      final svc = HomebrewPersistenceService();
      await _assertLoadedMatchesExpected(svc, expected, 'direct_stored_json');
    });

    test('exported HomebrewBundle loads through importResolvedBundle identically', () async {
      final expected = _readJson('expected_loaded_values.json');
      final bundleMap = _readJson('exported_homebrew_bundle.json');
      final bundle = HomebrewBundle.fromMap(bundleMap);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final analysis = const HomebrewMergeResolver().analyzeBundle(incomingBundle: bundle);
      await svc.importResolvedBundle(analysis);
      await _assertLoadedMatchesExpected(svc, expected, 'exported_homebrew_bundle');
    });

    test('exported raw bundle loads through HomebrewBundle.fromMap + importResolvedBundle identically', () async {
      final expected = _readJson('expected_loaded_values.json');
      final rawBundleMap = _readJson('exported_bundle.json');
      final bundle = HomebrewBundle.fromMap(rawBundleMap);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final analysis = const HomebrewMergeResolver().analyzeBundle(incomingBundle: bundle);
      await svc.importResolvedBundle(analysis);
      await _assertLoadedMatchesExpected(svc, expected, 'exported_raw_bundle');
    });

    test('app backup JSON restores homebrew spells and items identically', () async {
      final expected = _readJson('expected_loaded_values.json');
      final backupFile = File('$_dir/app_backup.json');
      expect(backupFile.existsSync(), isTrue);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final result = await AppBackupService()
          .importFullBackupJson(backupFile.readAsStringSync());
      expect(result.success, isTrue, reason: 'App backup restore failed: ${result.errorMessage}');
      await _assertLoadedMatchesExpected(svc, expected, 'app_backup');
    });

    test('DM backup snapshot restores homebrew spells and items identically', () async {
      final expected = _readJson('expected_loaded_values.json');
      final dmFile = File('$_dir/dm_backup.json');
      expect(dmFile.existsSync(), isTrue);

      final svc = HomebrewPersistenceService();
      await svc.clearAllHomebrew();
      final ok = await DmBackupService()
          .restoreFullSystemSnapshot(dmFile.readAsStringSync());
      expect(ok, isTrue, reason: 'DM backup restore returned false');
      await _assertLoadedMatchesExpected(svc, expected, 'dm_backup');
    });
  });
}
