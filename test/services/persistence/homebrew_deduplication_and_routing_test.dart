import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/models/homebrew_entity.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart' as domain_rules;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/srd_equivalence_index.dart';
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

      final debugResult = SrdEquivalenceIndex().checkEntity(
        slug: 'blade-ward',
        name: 'Blade Ward',
        type: EntityType.spell,
      );
      // print for test diagnosis
      expect(debugResult, equals(SrdMatchResult.exactSrdMatch));

      final parsed = CompendiumSpellParser().parseSpell(srdPayload);
      expect(parsed.name, equals('Blade Ward'));
      expect(parsed.id.slug, equals('blade-ward'));
      final srdRes = SrdEquivalenceIndex().checkEntity(
        slug: parsed.id.slug,
        name: parsed.name,
        type: EntityType.spell,
      );
      expect(srdRes, equals(SrdMatchResult.exactSrdMatch));

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
  });
}
