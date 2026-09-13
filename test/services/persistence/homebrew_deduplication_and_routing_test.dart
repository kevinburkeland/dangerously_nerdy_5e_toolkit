import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/models/homebrew_entity.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart' as domain_rules;
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homebrew Deduplication and Routing Tests', () {
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      persistence = HomebrewPersistenceService();
    });

    test('saveHomebrewEntitiesBatch drops exact SRD matches and preserves homebrew entities', () async {
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
            'time': [{'number': 1, 'unit': 'action'}],
            'range': {'type': 'point', 'distance': {'type': 'self'}},
            'duration': [{'type': 'timed', 'duration': {'type': 'round', 'amount': 1}}],
            'entries': ['You extend your hand and trace a sigil of warding in the air.'],
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
            'time': [{'number': 1, 'unit': 'action'}],
            'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 60}},
            'duration': [{'type': 'instant'}],
            'entries': ['A ripple of temporal force distorts space around the target.'],
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

    test('saveHomebrewEntitiesBatch routes baseitem and magicvariant to items category', () async {
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

    test('saveHomebrewEntitiesBatch routes subrace into races category', () async {
      final batch = [
        const HomebrewEntity(
          id: 'stellar-elf',
          name: 'Stellar Elf',
          entityType: 'subrace',
          ruleset: domain_rules.RulesetVersion.srd2014,
          rawPayload: {
            'name': 'Stellar Elf',
            'raceName': 'Starfolk',
            'entries': ['Stellar elves hail from astral observatories high in the sky.'],
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

    test('reparseAllHomebrew purges SRD duplicates and writes cleaned data to AppDatabaseService and SharedPreferences', () async {
      // Seed directly with an SRD spell and a homebrew spell
      final srdPayload = {
        'name': 'Blade Ward',
        'level': 0,
        'school': 'A',
        'time': [{'number': 1, 'unit': 'action'}],
        'range': {'type': 'point', 'distance': {'type': 'self'}},
        'duration': [{'type': 'timed', 'duration': {'type': 'round', 'amount': 1}}],
        'entries': ['You extend your hand and trace a sigil of warding in the air.'],
      };
      final homebrewPayload = {
        'name': 'Void Lance',
        'level': 4,
        'school': 'V',
        'time': [{'number': 1, 'unit': 'action'}],
        'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 120}},
        'duration': [{'type': 'instant'}],
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

    test('reparseAllHomebrew deduplicates subclasses across class-prefixed and suffix slugs', () async {
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
      expect(exported.subclasses.first.id.slug, equals('fighter-astral-striker'));
    });

    test('saveHomebrewEntitiesBatch merges multiple subraces under parent race without duplicate races', () async {
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

    test('reparseAllHomebrew preserves categories for Table, Vehicle, Trap, and Hazard in otherEntries', () async {
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
      expect(others.firstWhere((o) => o.name == 'Table of Astral Omens').category, equals('Table'));
      expect(others.firstWhere((o) => o.name == 'Sand Crawler').category, equals('Vehicle'));
      expect(others.firstWhere((o) => o.name == 'Glyph of Blinding').category, equals('Trap'));

      await persistence.reparseAllHomebrew();

      others = await persistence.loadCustomOtherEntries();
      expect(others.firstWhere((o) => o.name == 'Table of Astral Omens').category, equals('Table'));
      expect(others.firstWhere((o) => o.name == 'Sand Crawler').category, equals('Vehicle'));
      expect(others.firstWhere((o) => o.name == 'Glyph of Blinding').category, equals('Trap'));
    });
  });
}
