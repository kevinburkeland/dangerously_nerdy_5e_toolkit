import 'dart:convert';
import 'dart:io';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_doubles/hive_test_harness.dart';
import 'catalog_golden_serializer.dart';

List<Spell> _buildStoredFormatTestSpells() {
  return [
    // 1. Spell with every optional field set
    Spell.singleEdition(
      id: const EntityId(slug: 'hb-solar-flare', ruleset: RulesetVersion.homebrew),
      name: 'Solar Flare',
      level: 3,
      school: 'evocation',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      range: '120 feet',
      components: const SpellComponents(
        v: true,
        s: true,
        m: true,
        materialDescription: 'a pinch of sunstone dust',
      ),
      duration: const SpellDuration(
        type: DurationType.timed,
        durationSeconds: 60,
        requiresConcentration: true,
        rawText: 'Concentration, up to 1 minute',
      ),
      descriptionMarkdown: 'A burst of radiant fire erupts in a 20-foot sphere.',
      higherLevelsMarkdown: 'When cast using a 4th-level slot or higher, damage increases by 1d6.',
      damageMath: const [
        EvaluationMath(
          diceFormula: '6d6',
          damageType: DamageType.radiant,
          scalingFormula: '+1d6 per slot above 3rd',
          requiresSave: true,
        ),
      ],
      customProperties: const {
        'classes': ['Wizard', 'Cleric'],
        'ritual': true,
        'savingThrow': ['dexterity'],
        'areaTags': ['S'],
        'miscTags': ['SGT'],
        'source': 'HB-SOLAR',
      },
    ),
    // 2. Spell with minimal/no optional fields
    Spell.singleEdition(
      id: const EntityId(slug: 'hb-quiet-spark', ruleset: RulesetVersion.homebrew),
      name: 'Quiet Spark',
      level: 0,
      school: 'conjuration',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.bonusAction),
      range: '30 feet',
      components: const SpellComponents(v: true, s: false, m: false),
      duration: const SpellDuration(type: DurationType.instantaneous),
      descriptionMarkdown: 'Creates a tiny silent spark.',
    ),
    // 3. Spell with unknown school text (defaults to evocation in spellToSpellItem)
    Spell.singleEdition(
      id: const EntityId(slug: 'hb-chrono-step', ruleset: RulesetVersion.homebrew),
      name: 'Chrono Step',
      level: 2,
      school: 'chronomancy',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.reaction),
      range: 'Self',
      components: const SpellComponents(v: true, s: true, m: false),
      duration: const SpellDuration(type: DurationType.special),
      descriptionMarkdown: 'Step briefly sideways in time.',
      customProperties: const {
        'meta': {'ritual': false},
        'savingThrow': 'wisdom',
      },
    ),
    // 4. Spell with classes in fromClassList / fromClassListVariant / fromSubclass Map shape
    Spell.singleEdition(
      id: const EntityId(slug: 'hb-astral-weave', ruleset: RulesetVersion.homebrew),
      name: 'Astral Weave',
      level: 4,
      school: 'abjuration',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      range: '60 feet',
      components: const SpellComponents(v: true, s: true, m: false),
      duration: const SpellDuration(type: DurationType.permanent),
      descriptionMarkdown: 'Weaves a protective veil of starlight.',
      customProperties: const {
        'classes': {
          'fromClassList': [
            {'name': 'Bard', 'source': 'SRD'},
          ],
          'fromClassListVariant': [
            {'name': 'Sorcerer', 'source': 'SRD'},
          ],
          'fromSubclass': [
            {
              'class': {'name': 'Druid', 'source': 'SRD'},
              'subclass': {'name': 'Land'},
            },
          ],
        },
      },
    ),
    // 5. Spell with classes in nested customProperties.customProperties.classes shape
    Spell.singleEdition(
      id: const EntityId(slug: 'hb-nested-ward', ruleset: RulesetVersion.homebrew),
      name: 'Nested Ward',
      level: 1,
      school: 'abjuration',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      range: 'Touch',
      components: const SpellComponents(v: true, s: false, m: false),
      duration: const SpellDuration(type: DurationType.timed, durationSeconds: 600),
      descriptionMarkdown: 'Wards a touched creature.',
      customProperties: const {
        'customProperties': {
          'classes': ['Paladin', 'Warlock'],
        },
      },
    ),
  ];
}

List<EquipmentItem> _buildStoredFormatTestItems() {
  final specs = <({String slug, String name, String itemType, String rarity, bool attune, Map<String, dynamic> custom, String desc})>[
    (slug: 'hb-item-weapon', name: 'Sunblade Prototype', itemType: 'Weapon (longsword)', rarity: 'rare', attune: true, custom: {'cost': '2500 gp', 'rawJson': {'reqAttune': 'by a paladin'}}, desc: '# Heading\nA gleaming radiant blade.\nSecond line.'),
    (slug: 'hb-item-armor', name: 'Mithral Scale', itemType: 'Armor (medium)', rarity: 'uncommon', attune: false, custom: {'cost': '400 gp'}, desc: 'Lightweight interwoven scales.'),
    (slug: 'hb-item-potion', name: 'Elixir of Clarity', itemType: 'Potion', rarity: 'common', attune: false, custom: {}, desc: 'Clears the mind for 1 hour.'),
    (slug: 'hb-item-ring', name: 'Ring of Echoes', itemType: 'Ring', rarity: 'very rare', attune: true, custom: {}, desc: 'Repeats the last spoken spell.'),
    (slug: 'hb-item-rod', name: 'Rod of Steadiness', itemType: 'Rod', rarity: 'legendary', attune: true, custom: {}, desc: 'Grants unshakeable footing.'),
    (slug: 'hb-item-scroll', name: 'Scroll of Dawn', itemType: 'Scroll', rarity: 'uncommon', attune: false, custom: {}, desc: 'Contains a written incantation.'),
    (slug: 'hb-item-staff', name: 'Staff of Tides', itemType: 'Staff', rarity: 'artifact', attune: true, custom: {}, desc: 'Commands ocean currents.'),
    (slug: 'hb-item-wand', name: 'Wand of Sparks', itemType: 'Wand', rarity: 'common', attune: false, custom: {}, desc: 'Emits harmless sparks.'),
    (slug: 'hb-item-gem', name: 'Star Sapphire Gem', itemType: 'Gemstone', rarity: 'none', attune: false, custom: {'cost': '500 gp'}, desc: 'A finely cut star sapphire.'),
    (slug: 'hb-item-art', name: 'Gilded Chalice', itemType: 'Art Object', rarity: 'none', attune: false, custom: {'cost': '250 gp'}, desc: 'An ornate silver chalice.'),
    // Item type containing "art" that is NOT art (today's converter maps this to artObject!)
    (slug: 'hb-item-cartographer', name: "Master Cartographer's Kit", itemType: "Cartographer's Tools", rarity: 'none', attune: false, custom: {'cost': '15 gp'}, desc: 'Quills, ink, compass, and parchment.'),
    (slug: 'hb-item-trinket', name: 'Brass Compass Trinket', itemType: 'Trinket', rarity: 'none', attune: false, custom: {}, desc: 'Always points toward the nearest tavern.'),
    (slug: 'hb-item-gear', name: 'Climber Harness', itemType: 'Adventuring Gear', rarity: 'none', attune: false, custom: {'cost': '25 gp'}, desc: 'Sturdy hemp climbing harness.'),
    (slug: 'hb-item-wondrous', name: 'Cloak of Mist', itemType: 'Wondrous Item', rarity: 'rare', attune: true, custom: {}, desc: 'Shrouds the wearer in faint mist.'),
  ];

  return specs
      .map(
        (s) => EquipmentItem.singleEdition(
          id: EntityId(slug: s.slug, ruleset: RulesetVersion.homebrew),
          name: s.name,
          itemType: s.itemType,
          rarity: s.rarity,
          requiresAttunement: s.attune,
          descriptionMarkdown: s.desc,
          customProperties: s.custom,
        ),
      )
      .toList();
}

/// Explicit opt-in generator for Step 4 catalog and stored-format fixtures.
/// Run with:
///   UPDATE_STEP4_FIXTURES=1 flutter test test/support/generate_step4_fixtures.dart
void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await hive.setUpInMemory();
  });

  tearDown(() async {
    SpellbookLibrary.setHomebrewSpells(const []);
    MagicItemLibrary.setHomebrewItems(const []);
    await hive.tearDown();
  });

  test('generate Step 4 catalog goldens and stored-format fixtures', () async {
    if (Platform.environment['UPDATE_STEP4_FIXTURES'] != '1') {
      fail('Set UPDATE_STEP4_FIXTURES=1 to regenerate Step 4 fixtures.');
    }

    const encoder = JsonEncoder.withIndent('  ');

    // === Fix 4.1: Catalog & rules-view goldens ===
    final catalogDir = Directory('test/fixtures/catalog_goldens')
      ..createSync(recursive: true);

    final spellCatalog = buildSpellCatalogGoldenMap();
    File('${catalogDir.path}/spell_catalog_golden.json')
        .writeAsStringSync('${encoder.convert(spellCatalog)}\n');

    final itemCatalog = buildItemCatalogGoldenMap();
    File('${catalogDir.path}/item_catalog_golden.json')
        .writeAsStringSync('${encoder.convert(itemCatalog)}\n');

    final lookups = buildCatalogLookupsGoldenMap();
    File('${catalogDir.path}/catalog_lookups_golden.json')
        .writeAsStringSync('${encoder.convert(lookups)}\n');

    final rulesView = buildItemRulesViewGoldenMap();
    File('${catalogDir.path}/item_rules_view_golden.json')
        .writeAsStringSync('${encoder.convert(rulesView)}\n');

    stdout.writeln(
      'Wrote Fix 4.1 catalog goldens: spells=${spellCatalog['count']}, items=${itemCatalog['count']}, rulesView=${rulesView['count']}',
    );

    // === Fix 4.2: Stored homebrew, backup, and bundle formats ===
    final storedDir = Directory('test/fixtures/stored_formats')
      ..createSync(recursive: true);

    final svc = HomebrewPersistenceService();
    await svc.clearAllHomebrew();

    final spells = _buildStoredFormatTestSpells();
    final spellRawPayloads = spells
        .map((s) => <String, dynamic>{
              'name': s.name,
              'source': 'HB',
              'level': s.level,
              'school': s.school,
            })
        .toList();
    await svc.saveCustomSpellsBatch(spells, rawPayloads: spellRawPayloads);

    final items = _buildStoredFormatTestItems();
    final itemRawPayloads = items
        .map((i) => <String, dynamic>{
              'name': i.name,
              'source': 'HB',
              'type': i.itemType,
              'rarity': i.rarity,
            })
        .toList();
    await svc.saveCustomItemsBatch(items, rawPayloads: itemRawPayloads);

    // Capture exact stored JSON strings from AppDatabaseService
    final db = AppDatabaseService();
    final storedSpellJsonList = List<String>.from(
      (db.get(AppDatabaseService.boxHomebrew, 'dn_homebrew_spells_v1') as List?) ??
          const [],
    );
    final storedItemJsonList = List<String>.from(
      (db.get(AppDatabaseService.boxHomebrew, 'dn_homebrew_items_v1') as List?) ??
          const [],
    );
    final storedSpellRaws = await svc.loadRawPayloads(EntityType.spell);
    final storedItemRaws = await svc.loadRawPayloads(EntityType.equipment);

    File('${storedDir.path}/homebrew_spells_stored.json').writeAsStringSync(
      '${encoder.convert({'storedJsonList': storedSpellJsonList, 'rawPayloads': storedSpellRaws})}\n',
    );
    File('${storedDir.path}/homebrew_items_stored.json').writeAsStringSync(
      '${encoder.convert({'storedJsonList': storedItemJsonList, 'rawPayloads': storedItemRaws})}\n',
    );

    // Export both bundle formats
    final hbBundle = await svc.exportHomebrewBundle(
      bundleName: 'Step 4 Stored Format Bundle',
      author: 'Test Harness',
    );
    final hbBundleMap = hbBundle.toMap();
    hbBundleMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    File('${storedDir.path}/exported_homebrew_bundle.json')
        .writeAsStringSync('${encoder.convert(hbBundleMap)}\n');

    final rawBundleMap = await svc.exportBundle(
      bundleName: 'Step 4 Raw Export Bundle',
      author: 'Test Harness',
    );
    if (rawBundleMap['exportedAt'] != null) {
      rawBundleMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    }
    File('${storedDir.path}/exported_bundle.json')
        .writeAsStringSync('${encoder.convert(rawBundleMap)}\n');

    // Export App backup and DM backup
    final appBackupJson =
        await AppBackupService().exportFullBackupJson(const AppSettings());
    final appBackupMap = jsonDecode(appBackupJson) as Map<String, dynamic>;
    appBackupMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    File('${storedDir.path}/app_backup.json')
        .writeAsStringSync('${encoder.convert(appBackupMap)}\n');

    final dmBackupJson = await DmBackupService().exportFullSystemSnapshot();
    final dmBackupMap = jsonDecode(dmBackupJson) as Map<String, dynamic>;
    if (dmBackupMap['exportedAt'] != null) {
      dmBackupMap['exportedAt'] = '2026-01-01T00:00:00.000Z';
    }
    if (dmBackupMap['timestamp'] != null) {
      dmBackupMap['timestamp'] = '2026-01-01T00:00:00.000Z';
    }
    File('${storedDir.path}/dm_backup.json')
        .writeAsStringSync('${encoder.convert(dmBackupMap)}\n');

    // Sync to libraries and record expected loaded values
    await svc.syncToLibraries();
    final loadedSpells = await svc.loadCustomSpells();
    final loadedItems = await svc.loadCustomItems();

    final expectedLoaded = {
      'spells': loadedSpells.map((s) {
        final item = SpellbookLibrary.getSpellById(s.id.slug)!;
        return {
          'slug': s.id.slug,
          'name': s.name,
          'level': s.level,
          'school': s.school,
          'libraryView': serializeSpellForCatalogGolden(item),
        };
      }).toList(),
      'items': loadedItems.map((i) {
        final item = MagicItemLibrary.findById(i.id.slug)!;
        return {
          'slug': i.id.slug,
          'name': i.name,
          'itemType': i.itemType,
          'rarity': i.rarity,
          'requiresAttunement': i.requiresAttunement,
          'libraryView': serializeItemForCatalogGolden(item),
        };
      }).toList(),
    };
    File('${storedDir.path}/expected_loaded_values.json')
        .writeAsStringSync('${encoder.convert(expectedLoaded)}\n');

    stdout.writeln(
      'Wrote Fix 4.2 stored-format fixtures: spells=${loadedSpells.length}, items=${loadedItems.length}',
    );
  });
}
