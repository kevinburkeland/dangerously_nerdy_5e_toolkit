import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/models/homebrew_entity.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart' as domain_rules;
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/fluff/entity_fluff_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomebrewPersistenceService Tests', () {
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      EntityFluffService().clear();
      SrdSpeciesLibrary.setCustomSpecies([]);
      SrdSpeciesLibrary.setCustomSubraces([]);
      persistence = HomebrewPersistenceService();
    });

    test('saves, loads, and deletes custom spells', () async {
      const spell = Spell(
        id: EntityId(slug: 'void-lance', ruleset: RulesetVersion.homebrew),
        name: 'Void Lance',
        level: 4,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '120 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires a beam of necrotic void energy.',
        damageMath: [EvaluationMath(diceFormula: '6d8', damageType: DamageType.necrotic)],
      );

      await persistence.saveCustomSpell(spell);

      final loaded = await persistence.loadCustomSpells();
      expect(loaded.length, equals(1));
      expect(loaded.first.name, equals('Void Lance'));
      expect(loaded.first.slug, equals('void-lance'));
      expect(loaded.first.damageMath.first.diceFormula, equals('6d8'));

      await persistence.deleteCustomSpell('void-lance');
      final afterDelete = await persistence.loadCustomSpells();
      expect(afterDelete, isEmpty);
    });

    test('saves, loads, and deletes custom monsters', () async {
      const monster = Monster(
        id: EntityId(slug: 'void-crawler', ruleset: RulesetVersion.homebrew),
        name: 'Void Crawler',
        size: 'Large',
        monsterType: 'Monstrosity',
        alignment: 'Chaotic Evil',
        armorClass: 16,
        hitPoints: 85,
        hitDieFormula: '10d10 + 30',
        challengeRating: '6',
        actionsMarkdown: '**Multiattack**: Makes three claw attacks.',
      );

      await persistence.saveCustomMonster(monster);

      final loaded = await persistence.loadCustomMonsters();
      expect(loaded.length, equals(1));
      expect(loaded.first.name, equals('Void Crawler'));
      expect(loaded.first.armorClass, equals(16));

      await persistence.deleteCustomMonster('void-crawler');
      final afterDelete = await persistence.loadCustomMonsters();
      expect(afterDelete, isEmpty);
    });

    test('saves, loads, and deletes custom equipment items', () async {
      const item = EquipmentItem(
        id: EntityId(slug: 'ring-of-aether', ruleset: RulesetVersion.homebrew),
        name: 'Ring of Aether',
        itemType: 'Ring',
        rarity: 'Very Rare',
        requiresAttunement: true,
        descriptionMarkdown: 'Grants +2 to spell save DC.',
      );

      await persistence.saveCustomItem(item);

      final loaded = await persistence.loadCustomItems();
      expect(loaded.length, equals(1));
      expect(loaded.first.name, equals('Ring of Aether'));
      expect(loaded.first.requiresAttunement, isTrue);

      await persistence.deleteCustomItem('ring-of-aether');
      final afterDelete = await persistence.loadCustomItems();
      expect(afterDelete, isEmpty);
    });

    test('hydrates LayeredPriorityRepository with saved homebrew entities', () async {
      const spell = Spell(
        id: EntityId(slug: 'chaotic-blast-homebrew', ruleset: RulesetVersion.homebrew),
        name: 'Chaotic Blast (Homebrew)',
        level: 1,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '120 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Chaotic blast.',
      );

      await persistence.saveCustomSpell(spell);

      final repository = LayeredPriorityRepository();
      await persistence.hydrateRepository(repository);

      final lookupResult = repository.lookup<Spell>('chaotic-blast-homebrew');
      expect(lookupResult, isNotNull);
      expect(lookupResult!.name, equals('Chaotic Blast (Homebrew)'));
    });
    test('batch deletes custom entities by slug list and cleans up storage', () async {
      const spell1 = Spell(
        id: EntityId(slug: 'fire-dart', ruleset: RulesetVersion.homebrew),
        name: 'Fire Dart',
        level: 1,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires a dart of flame.',
      );
      const spell2 = Spell(
        id: EntityId(slug: 'ice-spike', ruleset: RulesetVersion.homebrew),
        name: 'Ice Spike',
        level: 2,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires an icy spike.',
      );
      const spell3 = Spell(
        id: EntityId(slug: 'arcane-ward', ruleset: RulesetVersion.homebrew),
        name: 'Arcane Ward',
        level: 3,
        school: 'Abjuration',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: 'Self',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Creates an arcane ward.',
      );

      await persistence.saveCustomSpellsBatch(
        [spell1, spell2, spell3],
        rawPayloads: [
          {'name': 'Fire Dart', 'source': 'HOMEBREW', 'level': 1},
          {'name': 'Ice Spike', 'source': 'HOMEBREW', 'level': 2},
          {'name': 'Arcane Ward', 'source': 'HOMEBREW', 'level': 3},
        ],
      );

      final initial = await persistence.loadCustomSpells();
      expect(initial.length, equals(3));

      // Batch delete spell1 and spell3
      final deletedCount = await persistence.deleteCustomEntitiesBatch(
        EntityType.spell,
        ['fire-dart', 'arcane-ward'],
      );
      expect(deletedCount, equals(2));

      final remaining = await persistence.loadCustomSpells();
      expect(remaining.length, equals(1));
      expect(remaining.first.slug, equals('ice-spike'));
    });

    test('clearHomebrewCategory purges specific category from AppDatabaseService and updates runtime library', () async {
      const monster = Monster(
        id: EntityId(slug: 'abyssal-stalker', ruleset: RulesetVersion.homebrew),
        name: 'Abyssal Stalker',
        size: 'Medium',
        monsterType: 'Fiend',
        alignment: 'Chaotic Evil',
        armorClass: 15,
        hitPoints: 60,
        hitDieFormula: '8d8 + 24',
        challengeRating: '4',
        actionsMarkdown: 'Stalks from shadows.',
      );
      await persistence.saveCustomMonster(monster);
      expect((await persistence.loadCustomMonsters()).length, equals(1));
      expect(MonsterCodexLibrary.homebrewMonsters.length, equals(1));

      // Also ensure AppDatabaseService explicitly has the key
      await AppDatabaseService.instance.put(
        AppDatabaseService.boxHomebrew,
        'dn_homebrew_monsters_v1',
        [jsonEncode(monster.toMap())],
      );

      await persistence.clearHomebrewCategory(EntityType.monster);

      // Verify both persistence and AppDatabaseService box are cleared
      expect(await persistence.loadCustomMonsters(), isEmpty);
      expect(AppDatabaseService.instance.get(AppDatabaseService.boxHomebrew, 'dn_homebrew_monsters_v1'), isNull);
      expect(MonsterCodexLibrary.homebrewMonsters, isEmpty);
    });

    test('reparseAllHomebrew upgrades entities from raw JSON and removes exact SRD matches', () async {
      // 1. Custom feat with raw JSON
      const feat = Feat(
        id: EntityId(slug: 'astral-touched', ruleset: RulesetVersion.homebrew),
        name: 'Astral Touched',
        category: 'General',
        descriptionMarkdown: 'Old text',
      );
      await persistence.saveCustomFeat(
        feat,
        rawPayload: {
          'name': 'Astral Touched',
          'source': 'HOMEBREW',
          'category': 'General',
          'entries': ['You gain {@damage 1d6|force} radiant bonus damage.'],
        },
      );

      // 2. Exact SRD match (e.g. Grappler) saved as homebrew
      const srdFeat = Feat(
        id: EntityId(slug: 'grappler', ruleset: RulesetVersion.homebrew),
        name: 'Grappler',
        category: 'General',
        descriptionMarkdown: 'Old text',
      );
      await persistence.saveCustomFeat(
        srdFeat,
        rawPayload: {
          'name': 'Grappler',
          'source': 'PHB',
          'category': 'General',
          'entries': ['Advantage on attack rolls against creatures you grapple.'],
        },
      );

      final result = await persistence.reparseAllHomebrew();
      expect(result.updatedCount, greaterThanOrEqualTo(1));
      expect(result.srdRemovedCount, equals(1));

      final loadedFeats = await persistence.loadCustomFeats();
      expect(loadedFeats.any((f) => f.slug == 'grappler'), isFalse);
      final astral = loadedFeats.firstWhere((f) => f.slug == 'astral-touched');
      expect(astral.descriptionMarkdown, contains('1d6'));
    });

    test('saveHomebrewEntitiesBatch saves monsters and spells and synchronizes runtime libraries', () async {
      const monsterEntity = HomebrewEntity(
        id: 'abyssal-stalker',
        name: 'Abyssal Stalker',
        entityType: 'monster',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Abyssal Stalker',
          'cr': '4',
          'hp': 75,
          'ac': 14,
          'speed': '30 ft.',
          'str': 16,
          'dex': 14,
          'con': 14,
          'int': 8,
          'wis': 12,
          'cha': 6,
        },
      );

      const spellEntity = HomebrewEntity(
        id: 'abyssal-chains',
        name: 'Abyssal Chains',
        entityType: 'spell',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Abyssal Chains',
          'level': 2,
          'school': 'evocation',
          'time': [
            {'number': 1, 'unit': 'action'}
          ],
          'range': {
            'type': 'point',
            'distance': {'type': 'feet', 'amount': 60}
          },
        },
      );

      await persistence.saveHomebrewEntitiesBatch([monsterEntity, spellEntity]);

      final monsters = await persistence.loadCustomMonsters();
      expect(monsters.any((m) => m.name == 'Abyssal Stalker'), isTrue);

      final spells = await persistence.loadCustomSpells();
      expect(spells.any((s) => s.name == 'Abyssal Chains'), isTrue);

      // Verify synchronized into runtime libraries
      expect(MonsterCodexLibrary.allMonsters.any((m) => m.name == 'Abyssal Stalker'), isTrue);
      expect(SpellbookLibrary.allSpells.any((s) => s.name == 'Abyssal Chains'), isTrue);
    });

    test('saveHomebrewEntitiesBatch with syncLibraries: false writes to disk without updating runtime library until syncToLibraries is called', () async {
      const spellEntity = HomebrewEntity(
        id: 'cave-curse',
        name: 'Cave Curse',
        entityType: 'spell',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Cave Curse',
          'level': 1,
          'school': 'necromancy',
          'time': [
            {'number': 1, 'unit': 'action'}
          ],
        },
      );

      await persistence.saveHomebrewEntitiesBatch([spellEntity], syncLibraries: false);

      // Verify persisted to storage
      final spells = await persistence.loadCustomSpells();
      expect(spells.any((s) => s.name == 'Cave Curse'), isTrue);

      // Runtime library should NOT yet contain it
      expect(SpellbookLibrary.allSpells.any((s) => s.name == 'Cave Curse'), isFalse);

      // Explicit sync hydrates runtime library
      await persistence.syncToLibraries();
      expect(SpellbookLibrary.allSpells.any((s) => s.name == 'Cave Curse'), isTrue);
    });

    test('saveHomebrewEntitiesBatch classifies monsters with creature types or CR as monsters, not other entries', () async {
      const humanoidMonster = HomebrewEntity(
        id: 'sand-corsair-captain',
        name: 'Sand Corsair Captain',
        entityType: 'humanoid',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Sand Corsair Captain',
          'type': 'humanoid',
          'cr': '2',
          'hp': 65,
          'ac': 15,
        },
      );

      const nestedTypeMonster = HomebrewEntity(
        id: 'ancient-lich',
        name: 'Ancient Lich',
        entityType: '{type: undead, tags: [wizard]}',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Ancient Lich',
          'type': {'type': 'undead', 'tags': ['wizard']},
          'cr': '21',
          'hp': 135,
          'ac': 17,
        },
      );

      await persistence.saveHomebrewEntitiesBatch([humanoidMonster, nestedTypeMonster]);

      final monsters = await persistence.loadCustomMonsters();
      expect(monsters.any((m) => m.name == 'Sand Corsair Captain'), isTrue);
      expect(monsters.any((m) => m.name == 'Ancient Lich'), isTrue);

      final others = await persistence.loadCustomOtherEntries();
      expect(others.any((o) => o.name == 'Sand Corsair Captain'), isFalse);
      expect(others.any((o) => o.name == 'Ancient Lich'), isFalse);
    });

    test('saves, loads, and exports custom subraces and fluff', () async {
      const subrace = Subrace(
        id: EntityId(slug: 'astral-elf-variant', ruleset: RulesetVersion.homebrew),
        name: 'Astral Elf (Variant)',
        raceSlug: 'elf',
        traitsMarkdown: 'Astral magic and teleportation.',
      );

      await persistence.saveCustomSubrace(subrace);

      final loadedSubs = await persistence.loadCustomSubraces();
      expect(loadedSubs.any((s) => s.id.slug == 'astral-elf-variant'), isTrue);
      expect(SrdSpeciesLibrary.customSubraces.any((s) => s.id.slug == 'astral-elf-variant'), isTrue);

      // Save fluff
      const fluff = EntityFluff(
        entityType: 'monster',
        slug: 'abyssal-stalker',
        loreMarkdown: 'Creatures born from the fathomless deep.',
      );

      await persistence.saveCustomFluffBatch([fluff]);

      final loadedFluff = await persistence.loadCustomFluff();
      expect(loadedFluff.any((f) => f.slug == 'abyssal-stalker'), isTrue);

      // Test exportHomebrewBundle includes both subraces and fluff
      final bundle = await persistence.exportHomebrewBundle();
      expect(bundle.subraces.any((s) => s.id.slug == 'astral-elf-variant'), isTrue);
      expect(bundle.fluff.any((f) => f.slug == 'abyssal-stalker'), isTrue);

      // Test exportBundle map includes both subraces and fluff
      final bundleMap = await persistence.exportBundle();
      final subList = bundleMap['subraces'] as List;
      final fluffList = bundleMap['fluff'] as List;
      expect(subList.any((s) => s['id']['slug'] == 'astral-elf-variant'), isTrue);
      expect(fluffList.any((f) => f['slug'] == 'abyssal-stalker'), isTrue);
    });

    test('reparseAllHomebrew preserves custom items even when synced to MagicItemLibrary', () async {
      const customItem = EquipmentItem(
        id: EntityId(slug: 'chrono-dagger', ruleset: RulesetVersion.homebrew),
        name: 'Chrono Dagger',
        itemType: 'weapon',
        rarity: 'rare',
        requiresAttunement: false,
        descriptionMarkdown: 'Dagger that manipulates time.',
      );

      await persistence.saveCustomItem(customItem, rawPayload: {
        'name': 'Chrono Dagger',
        'type': 'weapon',
        'rarity': 'rare',
        'description': 'Dagger that manipulates time.',
      });

      // Synchronize to libraries
      await persistence.syncToLibraries();
      expect(MagicItemLibrary.allItems.any((i) => i.name == 'Chrono Dagger'), isTrue);

      // Reparse all homebrew
      final result = await persistence.reparseAllHomebrew();
      expect(result.srdRemovedCount, equals(0));

      // Items must NOT be eaten or purged
      final itemsAfterReparse = await persistence.loadCustomItems();
      expect(itemsAfterReparse.any((i) => i.name == 'Chrono Dagger'), isTrue);
    });

    test('reparse is idempotent: repeated reparse cycles produce identical entity hashes and payload parity', () async {
      // 1. Seed a comprehensive predefined import across all categories
      final predefinedEntities = [
        const HomebrewEntity(
          id: 'void-blast',
          name: 'Void Blast',
          entityType: 'spell',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Void Blast',
            'level': 2,
            'school': 'V',
            'time': [
              {'number': 1, 'unit': 'action'}
            ],
            'range': {
              'type': 'point',
              'distance': {'type': 'feet', 'amount': 60}
            },
            'duration': [
              {'type': 'instant'}
            ],
            'entries': ['A ray of concentrated gravity strikes the target.'],
          },
        ),
        const HomebrewEntity(
          id: 'void-stalker',
          name: 'Void Stalker',
          entityType: 'monster',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Void Stalker',
            'size': 'M',
            'type': 'aberration',
            'cr': '5',
            'hp': {'average': 85},
            'ac': [16],
          },
        ),
        const HomebrewEntity(
          id: 'starlight-blade',
          name: 'Starlight Blade',
          entityType: 'item',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Starlight Blade',
            'type': 'M',
            'rarity': 'very rare',
            'entries': ['A rapier forged from fallen star metal.'],
          },
        ),
        const HomebrewEntity(
          id: 'void-weaver',
          name: 'Void Weaver',
          entityType: 'class',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Void Weaver',
            'hd': {'number': 1, 'faces': 8},
            'proficiency': ['int', 'wis'],
            'classFeatures': [],
          },
        ),
        const HomebrewEntity(
          id: 'void-weaver-astral-path',
          name: 'Astral Path',
          entityType: 'subclass',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Astral Path',
            'className': 'Void Weaver',
            'subclassFeatures': ['Traverse the astral planar currents.'],
          },
        ),
        const HomebrewEntity(
          id: 'astral-born',
          name: 'Astral Born',
          entityType: 'race',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Astral Born',
            'entries': ['Beings manifested from astral essence.'],
          },
        ),
        const HomebrewEntity(
          id: 'mark-of-the-astral',
          name: 'Mark of the Astral',
          entityType: 'subrace',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Mark of the Astral',
            'raceName': 'human',
            'entries': ['Humans bearing the celestial mark of the astral sphere.'],
          },
        ),
        const HomebrewEntity(
          id: 'void-touched',
          name: 'Void Touched',
          entityType: 'feat',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Void Touched',
            'entries': ['You have stared into the void and gained resistance to psychic damage.'],
          },
        ),
        const HomebrewEntity(
          id: 'void-hermit',
          name: 'Void Hermit',
          entityType: 'background',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Void Hermit',
            'entries': ['You spent years meditating at the edge of planar rifts.'],
          },
        ),
        const HomebrewEntity(
          id: 'table-void-omens',
          name: 'Table of Void Omens',
          entityType: 'table',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Table of Void Omens',
            'colLabels': ['d4', 'Omen'],
            'rows': [
              ['1', 'Rifts whisper'],
              ['2', 'Shadows lengthen'],
            ],
          },
        ),
      ];

      await persistence.saveHomebrewEntitiesBatch(predefinedEntities, syncLibraries: true);

      // Save fluff
      const fluff = EntityFluff(
        entityType: 'monster',
        slug: 'void-stalker',
        loreMarkdown: 'Stalkers of the deep astral rifts.',
      );
      await persistence.saveCustomFluffBatch([fluff]);
      await persistence.syncToLibraries();

      // Cycle 1: Run reparseAllHomebrew
      final result1 = await persistence.reparseAllHomebrew();
      expect(result1.srdRemovedCount, equals(0));
      expect(result1.updatedCount, greaterThan(0));

      final export1 = await persistence.exportBundle();

      // Calculate deterministic SHA-256 hash of export content (excluding dynamic timestamp/appVersion)
      String computeContentHash(Map<String, dynamic> bundleMap) {
        final categories = [
          'spells',
          'monsters',
          'items',
          'classes',
          'subclasses',
          'races',
          'subraces',
          'feats',
          'backgrounds',
          'otherEntries',
          'fluff'
        ];
        final buffer = StringBuffer();
        for (final cat in categories) {
          final list = List<dynamic>.from(bundleMap[cat] as List? ?? []);
          final stringified = list.map((e) => json.encode(e)).toList()..sort();
          buffer.write('$cat:${stringified.join('|')};');
        }
        return CryptoUtils.sha256Hex(buffer.toString());
      }

      final hash1 = computeContentHash(export1);

      // Cycle 2: Run reparseAllHomebrew AGAIN
      final result2 = await persistence.reparseAllHomebrew();
      expect(result2.srdRemovedCount, equals(0));

      final export2 = await persistence.exportBundle();
      final hash2 = computeContentHash(export2);

      // Cryptographic hash matching assertion: Cycle 1 hash MUST be identical to Cycle 2 hash
      expect(hash1, equals(hash2));

      // Category retention assertions
      expect((export2['spells'] as List).length, equals(1));
      expect((export2['monsters'] as List).length, equals(1));
      expect((export2['items'] as List).length, equals(1));
      expect((export2['classes'] as List).length, equals(1));
      expect((export2['subclasses'] as List).length, equals(1));
      expect((export2['races'] as List).length, equals(1));
      expect((export2['subraces'] as List).length, equals(1));
      expect((export2['feats'] as List).length, equals(1));
      expect((export2['backgrounds'] as List).length, equals(1));
      expect((export2['otherEntries'] as List).length, equals(1));
      expect((export2['fluff'] as List).length, equals(1));
    });
  });
}

