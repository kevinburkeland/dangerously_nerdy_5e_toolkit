import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/homebrew/models/homebrew_entity.dart';
import 'package:vtt_engine_core/homebrew/value_objects/ruleset_version.dart'
    as domain_rules;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_other_category.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/srd_tables_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homebrew Deduplication and Routing Tests', () {
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      persistence = HomebrewPersistenceService();
    });

    test(
        'saveHomebrewEntitiesBatch drops exact SRD matches and preserves homebrew entities',
        () async {
      final batch = [
        // SRD Spell to be dropped
        const HomebrewEntity(
          id: 'blade-ward',
          name: 'Blade Ward',
          entityType: 'spell',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Blade Ward',
            'level': 0,
            'school': 'A',
            'time': [
              {'number': 1, 'unit': 'action'}
            ],
            'range': {
              'type': 'point',
              'distance': {'type': 'self'}
            },
            'duration': [
              {
                'type': 'timed',
                'duration': {'type': 'round', 'amount': 1}
              }
            ],
            'entries': [
              'You extend your hand and trace a sigil of warding in the air.'
            ],
          },
        ),
        // Homebrew Spell to be preserved
        const HomebrewEntity(
          id: 'chronoblast',
          name: 'Chronoblast',
          entityType: 'spell',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Chronoblast',
            'level': 3,
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
            'entries': [
              'A ripple of temporal force distorts space around the target.'
            ],
          },
        ),
        // SRD Class to be dropped
        const HomebrewEntity(
          id: 'barbarian',
          name: 'Barbarian',
          entityType: 'class',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Barbarian',
            'hd': {'number': 1, 'faces': 12},
            'proficiency': ['str', 'con'],
            'classFeatures': [],
          },
        ),
        // Homebrew Class to be preserved
        const HomebrewEntity(
          id: 'aether-weaver',
          name: 'Aether Weaver',
          entityType: 'class',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Aether Weaver',
            'hd': {'number': 1, 'faces': 8},
            'proficiency': ['int', 'wis'],
            'classFeatures': [],
          },
        ),
        // SRD Monster to be dropped
        const HomebrewEntity(
          id: 'goblin',
          name: 'Goblin',
          entityType: 'monster',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Goblin',
            'size': 'S',
            'type': 'humanoid',
            'cr': '1/4',
            'hp': {'average': 7},
            'ac': [15],
          },
        ),
        // Homebrew Monster to be preserved
        const HomebrewEntity(
          id: 'cinder-drake',
          name: 'Cinder Drake',
          entityType: 'monster',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Cinder Drake',
            'size': 'M',
            'type': 'dragon',
            'cr': '4',
            'hp': {'average': 68},
            'ac': [16],
          },
        ),
      ];

      await persistence.saveHomebrewEntitiesBatch(batch, excludeSrdCanon: true);

      final spells = await persistence.loadCustomSpells();
      expect(spells.any((s) => s.name == 'Blade Ward'), isFalse);
      expect(spells.any((s) => s.name == 'Chronoblast'), isTrue);

      final classes = await persistence.loadCustomClasses();
      expect(classes.any((c) => c.name == 'Barbarian'), isFalse);
      expect(classes.any((c) => c.name == 'Aether Weaver'), isTrue);

      final monsters = await persistence.loadCustomMonsters();
      expect(monsters.any((m) => m.name == 'Goblin'), isFalse);
      expect(monsters.any((m) => m.name == 'Cinder Drake'), isTrue);
    });

    test(
        'saveHomebrewEntitiesBatch routes baseitem and magicvariant to items category',
        () async {
      final batch = [
        const HomebrewEntity(
          id: 'crystal-staff-focus',
          name: 'Crystal Staff Focus',
          entityType: 'baseitem',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Crystal Staff Focus',
            'type': 'SCF',
            'weight': 4,
            'entries': ['A resonant arcane focus carved from quartz.'],
          },
        ),
        const HomebrewEntity(
          id: 'solarflare-blade',
          name: 'Solarflare Blade',
          entityType: 'magicvariant',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Solarflare Blade',
            'type': 'M',
            'rarity': 'rare',
            'entries': ['Emits a blinding radiant burst on critical hit.'],
          },
        ),
      ];

      await persistence.saveHomebrewEntitiesBatch(batch);

      final items = await persistence.loadCustomItems();
      expect(items.any((i) => i.name == 'Crystal Staff Focus'), isTrue);
      expect(items.any((i) => i.name == 'Solarflare Blade'), isTrue);

      final others = await persistence.loadCustomOtherEntries();
      expect(others.any((o) => o.name == 'Crystal Staff Focus'), isFalse);
      expect(others.any((o) => o.name == 'Solarflare Blade'), isFalse);
    });

    test('saveHomebrewEntitiesBatch routes subrace into races category',
        () async {
      final batch = [
        const HomebrewEntity(
          id: 'stellar-elf',
          name: 'Stellar Elf',
          entityType: 'subrace',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Stellar Elf',
            'raceName': 'Starfolk',
            'entries': [
              'Stellar elves hail from astral observatories high in the sky.'
            ],
          },
        ),
      ];

      await persistence.saveHomebrewEntitiesBatch(batch);

      final races = await persistence.loadCustomRaces();
      expect(races.isNotEmpty, isTrue);
      final parentRace = races.firstWhere((r) => r.id.slug == 'starfolk');
      expect(parentRace.subraces.any((s) => s.name == 'Stellar Elf'), isTrue);

      final others = await persistence.loadCustomOtherEntries();
      expect(others.any((o) => o.name == 'Stellar Elf'), isFalse);
    });

    test(
        'reparseAllHomebrew purges SRD duplicates and writes cleaned data to AppDatabaseService and SharedPreferences',
        () async {
      // Seed directly with an SRD spell and a homebrew spell
      final srdPayload = {
        'name': 'Blade Ward',
        'level': 0,
        'school': 'A',
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'self'}
        },
        'duration': [
          {
            'type': 'timed',
            'duration': {'type': 'round', 'amount': 1}
          }
        ],
        'entries': [
          'You extend your hand and trace a sigil of warding in the air.'
        ],
      };
      final homebrewPayload = {
        'name': 'Void Lance',
        'level': 4,
        'school': 'V',
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 120}
        },
        'duration': [
          {'type': 'instant'}
        ],
        'entries': ['Fires a beam of necrotic void energy.'],
      };

      // Force save both without SRD exclusion
      await persistence.saveHomebrewEntitiesBatch(
        [
          HomebrewEntity(
            id: 'blade-ward',
            name: 'Blade Ward',
            entityType: 'spell',
            ruleset: domain_rules.RulesetVersion.srd2014,
            rawPayload: srdPayload,
          ),
          HomebrewEntity(
            id: 'void-lance',
            name: 'Void Lance',
            entityType: 'spell',
            ruleset: domain_rules.RulesetVersion.srd2014,
            rawPayload: homebrewPayload,
          ),
        ],
        excludeSrdCanon: false,
      );

      // Verify both are currently present
      var spells = await persistence.loadCustomSpells();
      expect(spells.length, equals(2));
      expect(spells.any((s) => s.name == 'Blade Ward'), isTrue);
      expect(spells.any((s) => s.name == 'Void Lance'), isTrue);

      // Run reparse
      final result = await persistence.reparseAllHomebrew();

      expect(result.srdRemovedCount, greaterThanOrEqualTo(1));
      expect(result.updatedCount, greaterThanOrEqualTo(1));

      // Check loaded custom spells from persistence
      spells = await persistence.loadCustomSpells();
      expect(spells.length, equals(1));
      expect(spells.any((s) => s.name == 'Blade Ward'), isFalse);
      expect(spells.any((s) => s.name == 'Void Lance'), isTrue);

      // Check exportHomebrewBundle reflects the pruned data
      final exportedBundle = await persistence.exportHomebrewBundle();
      expect(exportedBundle.spells.length, equals(1));
      expect(exportedBundle.spells.first.name, equals('Void Lance'));
    });

    test(
        'reparseAllHomebrew deduplicates subclasses across class-prefixed and suffix slugs',
        () async {
      final subclassPayload = {
        'name': 'Astral Striker',
        'className': 'Fighter',
        'source': 'HOMEBREW',
        'subclassFeatures': ['Channel astral energy into weapon attacks.'],
      };

      await persistence.saveHomebrewEntitiesBatch([
        HomebrewEntity(
          id: 'fighter-astral-striker',
          name: 'Astral Striker',
          entityType: 'subclass',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: subclassPayload,
        ),
      ]);

      var subs = await persistence.loadCustomSubclasses();
      expect(subs.length, equals(1));
      expect(subs.first.id.slug, equals('fighter-astral-striker'));

      final reparseResult = await persistence.reparseAllHomebrew();
      expect(reparseResult.updatedCount, greaterThanOrEqualTo(1));

      subs = await persistence.loadCustomSubclasses();
      expect(subs.length, equals(1));
      expect(subs.first.name, equals('Astral Striker'));
      expect(subs.first.id.slug, equals('fighter-astral-striker'));

      final exported = await persistence.exportHomebrewBundle();
      expect(exported.subclasses.length, equals(1));
      expect(
          exported.subclasses.first.id.slug, equals('fighter-astral-striker'));
    });

    test(
        'saveHomebrewEntitiesBatch merges multiple subraces under parent race without duplicate races',
        () async {
      const subrace1 = HomebrewEntity(
        id: 'aurora-gnome',
        name: 'Aurora Gnome',
        entityType: 'subrace',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Aurora Gnome',
          'raceName': 'Star Gnomes',
          'entries': ['Dwellers of glacial tundras.'],
        },
      );
      const subrace2 = HomebrewEntity(
        id: 'nebula-gnome',
        name: 'Nebula Gnome',
        entityType: 'subrace',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Nebula Gnome',
          'raceName': 'Star Gnomes',
          'entries': ['Sky dwellers of cosmic mists.'],
        },
      );

      await persistence.saveHomebrewEntitiesBatch([subrace1, subrace2]);

      var races = await persistence.loadCustomRaces();
      expect(races.length, equals(1));
      expect(races.first.id.slug, equals('star-gnomes'));
      expect(races.first.subraces.length, equals(2));

      await persistence.reparseAllHomebrew();

      races = await persistence.loadCustomRaces();
      expect(races.length, equals(1));
      expect(races.first.id.slug, equals('star-gnomes'));
      expect(races.first.subraces.length, equals(2));
    });

    test(
        'reparseAllHomebrew preserves categories for Table, Vehicle, Trap, and Hazard in otherEntries',
        () async {
      final entries = [
        const HomebrewEntity(
          id: 'table-astral-omens',
          name: 'Table of Astral Omens',
          entityType: 'table',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Table of Astral Omens',
            'entityType': 'table',
            'colLabels': ['d6', 'Omen'],
            'rows': [
              ['1', 'A falling star'],
              ['2', 'Aurora ribbon'],
            ],
          },
        ),
        const HomebrewEntity(
          id: 'vehicle-sand-crawler',
          name: 'Sand Crawler',
          entityType: 'vehicle',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Sand Crawler',
            'entityType': 'vehicle',
            'vehicleType': 'land',
            'entries': ['An armored rolling land ship.'],
          },
        ),
        const HomebrewEntity(
          id: 'trap-glyph-of-blinding',
          name: 'Glyph of Blinding',
          entityType: 'trap',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Glyph of Blinding',
            'entityType': 'trap',
            'trapType': 'magical',
            'entries': ['Flashes radiant light when triggered.'],
          },
        ),
      ];

      await persistence.saveHomebrewEntitiesBatch(entries);

      var others = await persistence.loadCustomOtherEntries();
      expect(
          others.firstWhere((o) => o.name == 'Table of Astral Omens').category,
          equals('Table'));
      expect(others.firstWhere((o) => o.name == 'Sand Crawler').category,
          equals('Vehicle'));
      expect(others.firstWhere((o) => o.name == 'Glyph of Blinding').category,
          equals('Trap'));

      await persistence.reparseAllHomebrew();

      others = await persistence.loadCustomOtherEntries();
      expect(
          others.firstWhere((o) => o.name == 'Table of Astral Omens').category,
          equals('Table'));
      expect(others.firstWhere((o) => o.name == 'Sand Crawler').category,
          equals('Vehicle'));
      expect(others.firstWhere((o) => o.name == 'Glyph of Blinding').category,
          equals('Trap'));
    });

    test(
        'reparseAllHomebrew preserves Deities without misclassifying as eldritch invocations',
        () async {
      const deity = HomebrewEntity(
        id: 'solas-the-dawnbringer',
        name: 'Solas the Dawnbringer',
        entityType: 'deity',
        ruleset: domain_rules.RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Solas the Dawnbringer',
          'source': 'HOMEBREW',
          'pantheon': 'Solar Covenant',
          'alignment': ['L', 'G'],
          'title': 'The Guiding Light',
          'domains': ['Light', 'Life'],
          'symbol': 'A blazing sun rising above twin silver peaks',
          'entityType': 'deity',
        },
      );

      await persistence.saveHomebrewEntitiesBatch([deity]);

      var others = await persistence.loadCustomOtherEntries();
      expect(others.length, equals(1));
      expect(others.first.name, equals('Solas the Dawnbringer'));
      expect(others.first.category, equals('Deity'));

      final result = await persistence.reparseAllHomebrew();
      expect(result.updatedCount, equals(1));
      expect(result.srdRemovedCount, equals(0));

      others = await persistence.loadCustomOtherEntries();
      expect(others.length, equals(1));
      expect(others.first.name, equals('Solas the Dawnbringer'));
      expect(others.first.category, equals('Deity'));
      expect(others.first.descriptionMarkdown, contains('Solar Covenant'));
      expect(others.first.descriptionMarkdown, contains('Light, Life'));
    });

    test(
        'HomebrewOtherCategory.classify accurately maps diverse compendium categories',
        () {
      // Tables
      expect(
        HomebrewOtherCategory.classify(
            category: 'Table', name: 'Critical Hit Table'),
        equals(HomebrewOtherCategory.tables),
      );
      expect(
        HomebrewOtherCategory.classify(
            category: 'Generic',
            name: 'Random Loot',
            customProperties: {'rows': []}),
        equals(HomebrewOtherCategory.tables),
      );

      // Deities (ensuring d-ei-ty does not classify as invocation!)
      expect(
        HomebrewOtherCategory.classify(
            category: 'Deity', name: 'Solas the Dawnbringer'),
        equals(HomebrewOtherCategory.deities),
      );
      expect(
        HomebrewOtherCategory.classify(
            category: 'Divine',
            name: 'Aurelia',
            customProperties: {'pantheon': 'Solar'}),
        equals(HomebrewOtherCategory.deities),
      );

      // Vehicles
      expect(
        HomebrewOtherCategory.classify(
            category: 'Vehicle', name: 'Sand Crawler'),
        equals(HomebrewOtherCategory.vehicles),
      );
      expect(
        HomebrewOtherCategory.classify(
            category: 'Equipment',
            name: 'Sky Skiff',
            customProperties: {'vehicleType': 'Air'}),
        equals(HomebrewOtherCategory.vehicles),
      );

      // Traps & Hazards
      expect(
        HomebrewOtherCategory.classify(category: 'Trap', name: 'Pit of Spikes'),
        equals(HomebrewOtherCategory.trapsAndHazards),
      );
      expect(
        HomebrewOtherCategory.classify(category: 'Hazard', name: 'Acidic Mist'),
        equals(HomebrewOtherCategory.trapsAndHazards),
      );

      // Invocations & Pact Boons
      expect(
        HomebrewOtherCategory.classify(
            category: 'Eldritch Invocation', name: 'Gaze of the Abyss'),
        equals(HomebrewOtherCategory.invocationsAndPacts),
      );
      expect(
        HomebrewOtherCategory.classify(
            category: 'Pact Boon', name: 'Pact of the Star'),
        equals(HomebrewOtherCategory.invocationsAndPacts),
      );
      expect(
        HomebrewOtherCategory.classify(
            category: 'ei', name: 'Whispering Shadows'),
        equals(HomebrewOtherCategory.invocationsAndPacts),
      );

      // Infusions
      expect(
        HomebrewOtherCategory.classify(
            category: 'Infusion', name: 'Replicating Dynamo'),
        equals(HomebrewOtherCategory.infusions),
      );

      // Charms & Rewards
      expect(
        HomebrewOtherCategory.classify(
            category: 'Charm', name: 'Charm of the North Star'),
        equals(HomebrewOtherCategory.charmsAndRewards),
      );
      expect(
        HomebrewOtherCategory.classify(
            category: 'Reward', name: 'Boon of the Storm'),
        equals(HomebrewOtherCategory.charmsAndRewards),
      );

      // Conditions & Diseases
      expect(
        HomebrewOtherCategory.classify(
            category: 'Disease', name: 'Sewer Plague Variant'),
        equals(HomebrewOtherCategory.conditionsAndDiseases),
      );

      // Character Options
      expect(
        HomebrewOtherCategory.classify(
            category: 'Character Option', name: 'Arcane Maneuver'),
        equals(HomebrewOtherCategory.characterOptions),
      );

      // Rules & Reference
      expect(
        HomebrewOtherCategory.classify(
            category: 'Rule', name: 'Underwater Combat Variant'),
        equals(HomebrewOtherCategory.rulesAndReference),
      );
    });

    test(
        'loadOtherCategoryCounts and clearOtherEntriesByCategories perform selective subcategory deletion',
        () async {
      final entries = [
        const HomebrewCompendiumEntry(
          id: EntityId(slug: 'table-loot-a', ruleset: RulesetVersion.homebrew),
          name: 'Table Loot A',
          category: 'Table',
          descriptionMarkdown: 'Table A',
        ),
        const HomebrewCompendiumEntry(
          id: EntityId(slug: 'table-loot-b', ruleset: RulesetVersion.homebrew),
          name: 'Table Loot B',
          category: 'Table',
          descriptionMarkdown: 'Table B',
        ),
        const HomebrewCompendiumEntry(
          id: EntityId(
              slug: 'solas-dawnbringer', ruleset: RulesetVersion.homebrew),
          name: 'Solas the Dawnbringer',
          category: 'Deity',
          descriptionMarkdown: 'A solar deity',
          customProperties: {'pantheon': 'Solar Covenant'},
        ),
        const HomebrewCompendiumEntry(
          id: EntityId(slug: 'sand-crawler', ruleset: RulesetVersion.homebrew),
          name: 'Sand Crawler',
          category: 'Vehicle',
          descriptionMarkdown: 'Desert vessel',
          customProperties: {'vehicleType': 'Land'},
        ),
        const HomebrewCompendiumEntry(
          id: EntityId(slug: 'pit-of-spikes', ruleset: RulesetVersion.homebrew),
          name: 'Pit of Spikes',
          category: 'Trap',
          descriptionMarkdown: 'Concealed pit trap',
          customProperties: {'trapType': 'Mechanical'},
        ),
      ];

      await persistence.saveCustomOtherEntriesBatch(entries);

      // Verify category counts
      final counts = await persistence.loadOtherCategoryCounts();
      expect(counts[HomebrewOtherCategory.tables], equals(2));
      expect(counts[HomebrewOtherCategory.deities], equals(1));
      expect(counts[HomebrewOtherCategory.vehicles], equals(1));
      expect(counts[HomebrewOtherCategory.trapsAndHazards], equals(1));
      expect(counts[HomebrewOtherCategory.invocationsAndPacts], equals(0));

      // Selectively delete only Deities and Vehicles
      final deletedCount = await persistence.clearOtherEntriesByCategories({
        HomebrewOtherCategory.deities,
        HomebrewOtherCategory.vehicles,
      });

      expect(deletedCount, equals(2));

      // Re-query remaining entries
      final remaining = await persistence.loadCustomOtherEntries();
      expect(remaining.length, equals(3));
      expect(remaining.any((r) => r.name == 'Solas the Dawnbringer'), isFalse);
      expect(remaining.any((r) => r.name == 'Sand Crawler'), isFalse);
      expect(remaining.any((r) => r.name == 'Table Loot A'), isTrue);
      expect(remaining.any((r) => r.name == 'Table Loot B'), isTrue);
      expect(remaining.any((r) => r.name == 'Pit of Spikes'), isTrue);

      final updatedCounts = await persistence.loadOtherCategoryCounts();
      expect(updatedCounts[HomebrewOtherCategory.tables], equals(2));
      expect(updatedCounts[HomebrewOtherCategory.deities], equals(0));
      expect(updatedCounts[HomebrewOtherCategory.vehicles], equals(0));
      expect(updatedCounts[HomebrewOtherCategory.trapsAndHazards], equals(1));
    });

    test(
        'HomebrewOtherCategory differentiates rolling tables from static data/reference tables',
        () {
      // Rolling Table with dice column
      final rollTable = HomebrewOtherCategory.classify(
        category: 'Table',
        name: 'Wild Magic Table',
        customProperties: {
          'colLabels': ['d100', 'Effect'],
          'rows': [
            ['01-02', 'Surge A'],
            ['03-04', 'Surge B'],
          ],
        },
      );
      expect(rollTable, equals(HomebrewOtherCategory.tables));

      // Rolling Table with numeric range first column
      final numericRollTable = HomebrewOtherCategory.classify(
        category: 'Table',
        name: 'Carousing Complications',
        customProperties: {
          'colLabels': ['Result', 'Complication'],
          'rows': [
            [1, 'Arrested'],
            [2, 'Lost pouch'],
          ],
        },
      );
      expect(numericRollTable, equals(HomebrewOtherCategory.tables));

      // Data / Reference Table with non-dice headers and non-numeric rows
      final dataTable = HomebrewOtherCategory.classify(
        category: 'Table',
        name: 'Armor Donning & Doffing',
        customProperties: {
          'colLabels': ['Armor Type', 'Don Time', 'Doff Time'],
          'rows': [
            ['Light Armor', '1 minute', '1 minute'],
            ['Medium Armor', '5 minutes', '1 minute'],
            ['Heavy Armor', '10 minutes', '5 minutes'],
          ],
        },
      );
      expect(dataTable, equals(HomebrewOtherCategory.dataTables));

      // Data / Reference Table explicitly indicated by name/matrix
      final matrixTable = HomebrewOtherCategory.classify(
        category: 'Table',
        name: 'Weapon Masteries Matrix',
        customProperties: {
          'colLabels': ['Mastery', 'Prerequisite', 'Effect'],
          'rows': [
            [
              'Cleave',
              'Melee, Heavy',
              'Make extra attack against adjacent target'
            ],
          ],
        },
      );
      expect(matrixTable, equals(HomebrewOtherCategory.dataTables));
    });

    test(
        'HomebrewOtherCategory accurately parses compendium list-based featureType values',
        () {
      // Eldritch Invocation with array featureType ["EI"]
      expect(
        HomebrewOtherCategory.classify(
          category: 'Optional Feature',
          name: 'Agonizing Blast',
          customProperties: {
            'featureType': ['EI']
          },
        ),
        equals(HomebrewOtherCategory.invocationsAndPacts),
      );

      // Pact Boon with array featureType ["PB"]
      expect(
        HomebrewOtherCategory.classify(
          category: 'Optional Feature',
          name: 'Pact of the Tome',
          customProperties: {
            'featureType': ['PB']
          },
        ),
        equals(HomebrewOtherCategory.invocationsAndPacts),
      );

      // Artificer Infusion with array featureType ["AI"]
      expect(
        HomebrewOtherCategory.classify(
          category: 'Optional Feature',
          name: 'Enhanced Defense',
          customProperties: {
            'featureType': ['AI']
          },
        ),
        equals(HomebrewOtherCategory.infusions),
      );

      // Metamagic with array featureType ["MM"]
      expect(
        HomebrewOtherCategory.classify(
          category: 'Optional Feature',
          name: 'Quickened Spell',
          customProperties: {
            'featureType': ['MM']
          },
        ),
        equals(HomebrewOtherCategory.characterOptions),
      );

      // Battle Master Maneuver with array featureType ["MV:B"]
      expect(
        HomebrewOtherCategory.classify(
          category: 'Optional Feature',
          name: 'Riposte',
          customProperties: {
            'featureType': ['MV:B']
          },
        ),
        equals(HomebrewOtherCategory.characterOptions),
      );
    });

    test(
        'syncToLibraries propagates both rolling tables and data tables to DmScreenLibrary',
        () async {
      const rollEntry = HomebrewCompendiumEntry(
        id: EntityId(slug: 'madness-table', ruleset: RulesetVersion.homebrew),
        name: 'Short-Term Madness Homebrew',
        category: 'Table',
        descriptionMarkdown:
            '| d100 | Effect |\n| :--- | :--- |\n| 01-20 | Character faints. |\n| 21-100 | Character screams. |',
        customProperties: {
          'colLabels': ['d100', 'Effect'],
          'rows': [
            ['01-20', 'Character faints.'],
            ['21-100', 'Character screams.'],
          ],
        },
      );

      const dataEntry = HomebrewCompendiumEntry(
        id: EntityId(
            slug: 'material-hardness', ruleset: RulesetVersion.homebrew),
        name: 'Material Hardness & AC Reference',
        category: 'Table',
        descriptionMarkdown:
            '| Material | AC |\n| :--- | :--- |\n| Glass | 13 |\n| Adamantine | 23 |',
        customProperties: {
          'colLabels': ['Material', 'AC'],
          'rows': [
            ['Glass', '13'],
            ['Adamantine', '23'],
          ],
        },
      );

      final persistence = HomebrewPersistenceService();
      await persistence.saveCustomOtherEntriesBatch([rollEntry, dataEntry]);
      await persistence.syncToLibraries();

      // Check DmScreenLibrary
      final refItems = DmScreenLibrary.allItems;
      final rollItem = refItems.firstWhere((i) => i.id == 'madness-table');
      expect(rollItem.category, equals(DmCategory.tables));
      expect(rollItem.subCategory, equals('Rollable Tables'));
      expect(rollItem.linkedTableQuery, equals('Short-Term Madness Homebrew'));
      expect(rollItem.linkedTableLabel, equals('Roll on Table'));

      final dataItem = refItems.firstWhere((i) => i.id == 'material-hardness');
      expect(dataItem.category, equals(DmCategory.tables));
      expect(dataItem.subCategory, equals('Data & Reference Tables'));
      expect(dataItem.linkedTableQuery, isNull);

      // Check SrdTablesLibrary (only rollable table should be registered)
      final rollTable = SrdTablesLibrary.getTableById('madness-table');
      expect(rollTable, isNotNull);
      expect(rollTable!.name, equals('Short-Term Madness Homebrew'));

      final dataTableInRoller =
          SrdTablesLibrary.getTableById('material-hardness');
      expect(dataTableInRoller, isNull);
    });
  });
}
