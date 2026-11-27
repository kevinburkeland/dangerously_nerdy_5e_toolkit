import 'dart:convert';
import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/field_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_field.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_span.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_monster_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/monster_builder_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_doubles/hive_test_harness.dart';
import 'monster_golden_serializer.dart';

List<Monster> _buildRichStoredTestMonsters() {
  return [
    // 1. Every customProperties key in string shape + ### Heading and **Bold.** markdown
    Monster.singleEdition(
      id: const EntityId(
        slug: 'hb-full-props-string',
        ruleset: RulesetVersion.homebrew,
      ),
      name: 'Ashbound Warden',
      size: 'Large',
      monsterType: 'Fiend',
      alignment: 'lawful evil',
      armorClass: 17,
      hitPoints: 114,
      hitDieFormula: '12d10 + 48',
      challengeRating: '7',
      actionsMarkdown:
          '### Traits\n\n### Smoke Aura\nCreatures within 5 feet have disadvantage on Perception checks.\n\n**Pack Tactics.** The warden has advantage on an attack roll against a creature if at least one ally is within 5 feet.\n\n### Actions\n\n**Multiattack.** The warden makes two halberd attacks.\n\n**Halberd.** Melee Weapon Attack: +8 to hit, reach 10 ft., one target. Hit: 14 (2d8 + 5) slashing damage.',
      customProperties: const {
        'speed': '35 ft., climb 20 ft.',
        'str': 20,
        'dex': 12,
        'con': 18,
        'int': 11,
        'wis': 14,
        'cha': 15,
        'savingThrows': 'STR +8, CON +7, WIS +5',
        'skills': 'Athletics +8, Perception +5',
        'damageVulnerabilities': 'cold',
        'damageResistances': 'necrotic, poison',
        'damageImmunities': 'fire',
        'conditionImmunities': 'charmed, frightened',
        'senses': 'darkvision 60 ft., passive Perception 15',
        'languages': 'Common, Infernal',
      },
    ),
    // 2. Every customProperties key in map/list/legacy shape + markdown speed + all trait/action shapes
    Monster.singleEdition(
      id: const EntityId(
        slug: 'hb-full-props-maps-lists',
        ruleset: RulesetVersion.homebrew,
      ),
      name: 'Gale Revenant',
      size: 'Medium',
      monsterType: 'Undead',
      alignment: 'neutral evil',
      armorClass: 15,
      hitPoints: 75,
      hitDieFormula: '10d8 + 30',
      challengeRating: '4',
      actionsMarkdown:
          '**Speed:** 40 ft., fly 60 ft.\n\n### Traits\n\n### Storm Shroud: Ranged attacks against the revenant have disadvantage.\n\n- **Wind Walk**: Moves through hostile spaces without penalty.\n\n*Cold Presence.* Deals 3 cold damage to grappling creatures.\n\nHollow Echo: Cannot be tracked by nonmagical means.\n\n- Misty Form: Can squeeze through a 1-inch gap.\n\n### Silent Drift\n\nGale Surge\nPushes nearby creatures 10 feet on initiative count 20.\n\nAn ancient echo lingers in the storm.\n\n### Actions\n\n**Gale Slash.** Melee Weapon Attack: +6 to hit, reach 5 ft, one target. Hit: 12 (2d6 + 5) cold damage.\n\n### Reactions',
      customProperties: const {
        'strScore': 14,
        'dexScore': 18,
        'conScore': 16,
        'intScore': 10,
        'wisScore': 13,
        'chaScore': 15,
        'save': {'dex': '+6', 'wis': '+3'},
        'skill': {'stealth': '+6', 'perception': '+3'},
        'vulnerable': ['radiant'],
        'resist': [
          'cold',
          {
            'resist': 'bludgeoning, piercing, slashing',
            'note': 'from nonmagical attacks',
          },
        ],
        'immune': ['poison', 'necrotic'],
        'conditionImmune': ['exhaustion', 'poisoned'],
        'senses': ['darkvision 120 ft.'],
        'passive': 15,
        'languages': ['Common', 'Primordial'],
      },
    ),
    // 3. Senses list without passive + attackMath fallback (no parsed actions in markdown)
    Monster.singleEdition(
      id: const EntityId(
        slug: 'hb-senses-no-passive',
        ruleset: RulesetVersion.homebrew,
      ),
      name: 'Shard Beetle',
      size: 'Small',
      monsterType: 'Construct',
      alignment: 'unaligned',
      armorClass: 16,
      hitPoints: 33,
      hitDieFormula: '6d6 + 12',
      challengeRating: '1/2',
      actionsMarkdown: '**Crystal Carapace.** Sheds dim light in a 10-foot radius.',
      attackMath: const [
        EvaluationMath(
          diceFormula: '2d4 + 3',
          damageType: DamageType.piercing,
        ),
      ],
      customProperties: const {
        'senses': ['tremorsense 30 ft.'],
        'languages': <String>[],
      },
    ),
    // 4. Unreadable CR text
    Monster.singleEdition(
      id: const EntityId(
        slug: 'hb-unreadable-cr',
        ruleset: RulesetVersion.homebrew,
      ),
      name: 'Rift Mimic',
      size: 'Medium',
      monsterType: 'Aberration',
      alignment: 'chaotic neutral',
      armorClass: 14,
      hitPoints: 58,
      hitDieFormula: '9d8 + 18',
      challengeRating: 'varies',
      actionsMarkdown:
          '**Pseudopod.** Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 9 (1d10 + 4) force damage.',
      customProperties: const {
        'speed': '30 ft.',
      },
    ),
  ];
}

List<Map<String, dynamic>> _buildMissingKeyRawStoredMaps() {
  Map<String, dynamic> fullBase(String slug, String name) => {
        'id': {'slug': slug, 'ruleset': 'homebrew'},
        'name': name,
        'size': 'Large',
        'monsterType': 'Beast',
        'alignment': 'neutral',
        'armorClass': 14,
        'hitPoints': 45,
        'hitDieFormula': '6d10 + 12',
        'challengeRating': '2',
        'actionsMarkdown': '',
        'innateSpells': <dynamic>[],
        'attackMath': <dynamic>[],
        'customProperties': <String, dynamic>{},
      };

  return [
    // 5. Empty map apart from id and name
    {
      'id': {'slug': 'hb-minimal-id-name', 'ruleset': 'homebrew'},
      'name': 'Minimal Shade',
    },
    // 6-12. Each F-16 fact missing individually
    fullBase('hb-missing-size', 'Sizeless Hound')..remove('size'),
    fullBase('hb-missing-type', 'Typeless Stalker')..remove('monsterType'),
    fullBase('hb-missing-alignment', 'Alignmentless Spirit')
      ..remove('alignment'),
    fullBase('hb-missing-ac', 'Unarmored Phantom')..remove('armorClass'),
    fullBase('hb-missing-hp', 'Hpless Specter')..remove('hitPoints'),
    fullBase('hb-missing-hitdice', 'Diceless Golem')..remove('hitDieFormula'),
    fullBase('hb-missing-cr', 'Unrated Beast')..remove('challengeRating'),
  ];
}

Map<String, dynamic> _buildLoadedMonstersSnapshot(
  List<Monster> loadedMonsters,
) {
  final hbItems = MonsterCodexLibrary.homebrewMonsters;
  final hbIds = hbItems.map((m) => m.id.slug).toSet();
  return {
    'monsters': loadedMonsters.map((m) {
      final item = MonsterCodexLibrary.getMonsterById(m.id.slug)!;
      return {
        'slug': m.id.slug,
        'domainMonster': serializeDomainMonster(m),
        'codexItem': serializeMonsterForGolden(item),
        'statBlock': serializeStatBlockForGolden(item.sourceStatBlock),
      };
    }).toList(),
    'codexState': {
      'homebrewIds': hbItems.map((m) => m.id.slug).toList(),
      'homebrewCrBands': {
        'all': MonsterCodexLibrary.allMonsters
            .where((m) => hbIds.contains(m.id.slug))
            .map((m) => m.id.slug)
            .toList(),
        'cr0ToQuarter': MonsterCodexLibrary.getCr0ToQuarterMonsters()
            .where((m) => hbIds.contains(m.id.slug))
            .map((m) => m.id.slug)
            .toList(),
        'crHalfToOne': MonsterCodexLibrary.getCrHalfToOneMonsters()
            .where((m) => hbIds.contains(m.id.slug))
            .map((m) => m.id.slug)
            .toList(),
        'crTwoToFour': MonsterCodexLibrary.getCrTwoToFourMonsters()
            .where((m) => hbIds.contains(m.id.slug))
            .map((m) => m.id.slug)
            .toList(),
        'crFiveToEight': MonsterCodexLibrary.getCrFiveToEightMonsters()
            .where((m) => hbIds.contains(m.id.slug))
            .map((m) => m.id.slug)
            .toList(),
        'crNinePlus': MonsterCodexLibrary.getCrNinePlusMonsters()
            .where((m) => hbIds.contains(m.id.slug))
            .map((m) => m.id.slug)
            .toList(),
      },
      'homebrewSortModes2024': {
        for (final mode in MonsterSortMode.values)
          mode.name: sortMonsterIdsByMode(hbItems, mode, DmRulesEdition.v2024),
      },
    },
  };
}

Map<String, dynamic> _syncAndSerializeMonsterPath(Monster m) {
  MonsterCodexLibrary.setHomebrewMonsters([m]);
  final item = MonsterCodexLibrary.getMonsterById(m.id.slug);
  expect(item, isNotNull, reason: 'Monster ${m.id.slug} missing after sync');
  return jsonDecode(jsonEncode({
    'domainMonster': serializeDomainMonster(m),
    'codexView': serializeMonsterForGolden(item!),
  })) as Map<String, dynamic>;
}

IngestionCandidate _buildCandidate(
  String id,
  String rawSource,
  Map<String, dynamic> rawFields,
) {
  final fields = <String, IngestionField<dynamic>>{};
  rawFields.forEach((k, v) {
    fields[k] = IngestionField<dynamic>(
      key: k,
      label: k,
      state: IngestionFieldState.extracted,
      rawText: v.toString(),
      value: v,
    );
  });
  return IngestionCandidate(
    id: id,
    span: const SourceSpan.empty(),
    rawSource: rawSource,
    normalizedSource: rawSource,
    blocks: const [],
    identification: const CandidateIdentification(
      identifiedTypeKey: 'monster',
      confidence: 1.0,
      evidence: [],
    ),
    targetTypeKey: 'monster',
    fields: fields,
  );
}

/// Explicit opt-in generator for Step 4 monster catalog, stored-format,
/// and construction-path fixtures.
///
/// Run with:
///   UPDATE_STEP4_MONSTER_FIXTURES=1 flutter test test/support/generate_step4_monster_fixtures.dart
void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await hive.setUpInMemory();
    MonsterCodexLibrary.clearHomebrewMonsters();
    MonsterCodexLibrary.clearCaches();
  });

  tearDown(() async {
    MonsterCodexLibrary.clearHomebrewMonsters();
    MonsterCodexLibrary.clearCaches();
    await hive.tearDown();
  });

  test('generate Fix 4.1 monster catalog goldens and Fix 4.2 stored-format fixtures',
      () async {
    if (Platform.environment['UPDATE_STEP4_MONSTER_FIXTURES'] != '1') {
      fail(
        'Set UPDATE_STEP4_MONSTER_FIXTURES=1 to regenerate Step 4 monster fixtures.',
      );
    }

    const encoder = JsonEncoder.withIndent('  ');

    // === Fix 4.1: Monster & summon catalog goldens ===
    final catalogDir = Directory('test/fixtures/catalog_goldens')
      ..createSync(recursive: true);

    final monsterCatalog = buildMonsterCatalogGoldenMap();
    File('${catalogDir.path}/monster_catalog_golden.json')
        .writeAsStringSync('${encoder.convert(monsterCatalog)}\n');

    final monsterLookups = buildMonsterLookupsGoldenMap();
    File('${catalogDir.path}/monster_lookups_golden.json')
        .writeAsStringSync('${encoder.convert(monsterLookups)}\n');

    stdout.writeln(
      'Wrote Fix 4.1 monster goldens: monsters=${monsterCatalog['monsterCount']}, '
      'summonPresets=${monsterCatalog['summonPresetCount']}, '
      'summonStatBlocks=${monsterCatalog['summonStatBlockCount']}',
    );

    // === Fix 4.2 (Stored): Monster stored formats, bundles, and backups ===
    final storedDir = Directory('test/fixtures/stored_formats')
      ..createSync(recursive: true);

    final svc = HomebrewPersistenceService();
    await svc.clearAllHomebrew();

    final richMonsters = _buildRichStoredTestMonsters();
    final richRaws = richMonsters
        .map((m) => <String, dynamic>{
              'name': m.name,
              'source': 'HB',
              'size': m.size,
              'type': m.monsterType,
              'cr': m.challengeRating,
            })
        .toList();
    await svc.saveCustomMonstersBatch(richMonsters, rawPayloads: richRaws);

    // Append raw missing-key JSON maps directly into dn_homebrew_monsters_v1
    final db = AppDatabaseService();
    final existingJsonList = List<String>.from(
      (db.get(AppDatabaseService.boxHomebrew, 'dn_homebrew_monsters_v1')
              as List?) ??
          const [],
    );
    final missingKeyMaps = _buildMissingKeyRawStoredMaps();
    for (final rawMap in missingKeyMaps) {
      existingJsonList.add(jsonEncode(rawMap));
    }
    await db.put(
      AppDatabaseService.boxHomebrew,
      'dn_homebrew_monsters_v1',
      existingJsonList,
    );

    final storedMonsterRaws = await svc.loadRawPayloads(EntityType.monster);
    File('${storedDir.path}/homebrew_monsters_stored.json').writeAsStringSync(
      '${encoder.convert({
            'storedJsonList': existingJsonList,
            'rawPayloads': storedMonsterRaws,
          })}\n',
    );

    // Export both bundle formats
    final hbBundle = await svc.exportHomebrewBundle(
      bundleName: 'Step 4 Monster Stored Bundle',
      author: 'Test Harness',
    );
    final hbBundleMap = hbBundle.toMap();
    hbBundleMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    File('${storedDir.path}/monster_exported_homebrew_bundle.json')
        .writeAsStringSync('${encoder.convert(hbBundleMap)}\n');

    final rawBundleMap = await svc.exportBundle(
      bundleName: 'Step 4 Monster Raw Export Bundle',
      author: 'Test Harness',
    );
    if (rawBundleMap['exportedAt'] != null) {
      rawBundleMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    }
    File('${storedDir.path}/monster_exported_bundle.json')
        .writeAsStringSync('${encoder.convert(rawBundleMap)}\n');

    // Export App backup and DM backup
    final appBackupJson =
        await AppBackupService().exportFullBackupJson(const AppSettings());
    final appBackupMap = jsonDecode(appBackupJson) as Map<String, dynamic>;
    appBackupMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    File('${storedDir.path}/monster_app_backup.json')
        .writeAsStringSync('${encoder.convert(appBackupMap)}\n');

    final dmBackupJson = await DmBackupService().exportFullSystemSnapshot();
    final dmBackupMap = jsonDecode(dmBackupJson) as Map<String, dynamic>;
    if (dmBackupMap['exportedAt'] != null) {
      dmBackupMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    }
    if (dmBackupMap['timestamp'] != null) {
      dmBackupMap['timestamp'] = '2026-01-01T00:00:00.000Z';
    }
    File('${storedDir.path}/monster_dm_backup.json')
        .writeAsStringSync('${encoder.convert(dmBackupMap)}\n');

    // Record expected loaded values for direct stored JSON and exported/backed-up formats
    await svc.syncToLibraries();
    final loadedMonsters = await svc.loadCustomMonsters();
    final snapshot = _buildLoadedMonstersSnapshot(loadedMonsters);
    final expectedLoaded = {
      'directStored': snapshot,
      'exportedAndBackedUp': snapshot,
    };
    File('${storedDir.path}/expected_loaded_monsters.json')
        .writeAsStringSync('${encoder.convert(expectedLoaded)}\n');

    stdout.writeln(
      'Wrote Fix 4.2 stored monster fixtures: count=${loadedMonsters.length}',
    );
  });

  testWidgets('generate Fix 4.2 newly-built monster construction path expected views',
      (tester) async {
    if (Platform.environment['UPDATE_STEP4_MONSTER_FIXTURES'] != '1') {
      fail(
        'Set UPDATE_STEP4_MONSTER_FIXTURES=1 to regenerate Step 4 monster fixtures.',
      );
    }

    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const dir = 'test/fixtures/construction_paths/monsters';
    final formInputs = jsonDecode(
      File('$dir/monster_form_inputs.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final importerInputs = jsonDecode(
      File('$dir/monster_importers_inputs.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final expected = <String, Map<String, dynamic>>{};

    // 1. MonsterBuilderDialog
    final formRecords = <String, dynamic>{};
    for (final raw
        in (formInputs['monsters'] as List).cast<Map<String, dynamic>>()) {
      final inputId = raw['inputId'] as String;
      Monster? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  saved = await showDialog<Monster>(
                    context: context,
                    builder: (_) => const MonsterBuilderDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).at(0), raw['name'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(1), raw['size'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(2), raw['type'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(3), raw['alignment'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(4), raw['cr'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(5), raw['ac'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(6), raw['hp'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(7), raw['hitDice'] as String);
      await tester.enterText(
          find.byType(TextFormField).at(8), raw['actionsMarkdown'] as String);

      await tester.ensureVisible(find.text('Save Monster'));
      await tester.tap(find.text('Save Monster'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: 'Failed saving form input $inputId');
      formRecords[inputId] = _syncAndSerializeMonsterPath(saved!);
    }
    expected['lib/widgets/homebrew/monster_builder_dialog.dart'] = formRecords;

    // 2. CompendiumMonsterParser
    final aclParser = CompendiumMonsterParser();
    final aclRecords = <String, dynamic>{};
    for (final entry in (importerInputs['compendiumMonsters'] as List)
        .cast<Map<String, dynamic>>()) {
      final id = entry['inputId'] as String;
      MonsterCodexLibrary.clearHomebrewMonsters();
      final monster = aclParser.parseMonster(
        Map<String, dynamic>.from(entry['raw'] as Map),
      );
      aclRecords[id] = _syncAndSerializeMonsterPath(monster);
    }
    expected['lib/services/acl/compendium_monster_parser.dart'] = aclRecords;

    // 3. CommunityCompendiumAdapters
    final adapters = CommunityCompendiumAdapters();
    final commRecords = <String, dynamic>{};
    for (final entry in (importerInputs['communityMonsters'] as List)
        .cast<Map<String, dynamic>>()) {
      final id = entry['inputId'] as String;
      final monster = adapters.parseMonster(
        Map<String, dynamic>.from(entry['raw'] as Map),
      );
      commRecords[id] = _syncAndSerializeMonsterPath(monster);
    }
    expected['lib/services/importers/community_compendium_adapters.dart'] =
        commRecords;

    // 4. Dnd5eIngestionCapability
    const cap = Dnd5eIngestionCapability();
    final ingRecords = <String, dynamic>{};
    for (final entry in (importerInputs['ingestionMonsters'] as List)
        .cast<Map<String, dynamic>>()) {
      final id = entry['inputId'] as String;
      final res = cap.convertCandidate(
        _buildCandidate(
          id,
          entry['rawSource'] as String,
          Map<String, dynamic>.from(entry['fields'] as Map),
        ),
      );
      expect(res.isSuccess, isTrue,
          reason: 'Failed ingestion $id: ${res.errors}');
      ingRecords[id] = _syncAndSerializeMonsterPath(res.entity! as Monster);
    }
    expected[
            'lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart'] =
        ingRecords;

    const encoder = JsonEncoder.withIndent('  ');
    File('$dir/expected_monster_paths.json')
        .writeAsStringSync('${encoder.convert(expected)}\n');

    final totalCases =
        expected.values.fold<int>(0, (sum, m) => sum + m.length);
    stdout.writeln(
      'Wrote Fix 4.2 monster construction path expected views: '
      'paths=${expected.length}, cases=$totalCases',
    );
  });
}
