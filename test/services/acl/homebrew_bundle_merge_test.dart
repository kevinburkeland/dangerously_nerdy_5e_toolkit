import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_bundle.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  group('Homebrew Bundle Import/Export & Deduplication Tests', () {
    test('round-trip serialization of HomebrewBundle with all categories', () {
      final spell = Spell(
        id: const EntityId(slug: 'frost-blast', ruleset: RulesetVersion.homebrew),
        name: 'Frost Blast',
        level: 2,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '60 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'A cone of cold blasts forth.',
        customProperties: {'flavor': 'Chilling effect'},
      );

      final monster = Monster(
        id: const EntityId(slug: 'void-crawler', ruleset: RulesetVersion.homebrew),
        name: 'Void Crawler',
        size: 'Small',
        monsterType: 'Aberration',
        alignment: 'Neutral Evil',
        armorClass: 13,
        hitPoints: 22,
        hitDieFormula: '4d6 + 8',
        challengeRating: '1/2',
        actionsMarkdown: 'Bite: +4 to hit, 5 piercing damage.',
        customProperties: {'habitat': 'The Void'},
      );

      final bundle = HomebrewBundle(
        appVersion: '1.0.0',
        exportedAt: DateTime.parse('2026-08-30T10:00:00.000Z'),
        bundleName: 'Cosmic Horrors Pack',
        author: 'DM Kevin',
        description: 'Chilling spells and void beasts.',
        spells: [spell],
        monsters: [monster],
      );

      final map = bundle.toMap();
      final jsonStr = json.encode(map);
      final decodedMap = json.decode(jsonStr) as Map<String, dynamic>;
      final reloaded = HomebrewBundle.fromMap(decodedMap);

      expect(reloaded.bundleName, equals('Cosmic Horrors Pack'));
      expect(reloaded.author, equals('DM Kevin'));
      expect(reloaded.description, equals('Chilling spells and void beasts.'));
      expect(reloaded.spells.length, equals(1));
      expect(reloaded.spells.first.name, equals('Frost Blast'));
      expect(reloaded.spells.first.customProperties['flavor'], equals('Chilling effect'));
      expect(reloaded.monsters.length, equals(1));
      expect(reloaded.monsters.first.name, equals('Void Crawler'));
      expect(reloaded.monsters.first.customProperties['habitat'], equals('The Void'));
    });

    test('HomebrewMergeResolver correctly classifies Novel, Identical, and Collision entities', () {
      final existingSpell = Spell(
        id: const EntityId(slug: 'fire-whip', ruleset: RulesetVersion.homebrew),
        name: 'Fire Whip',
        level: 1,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.timed, durationSeconds: 60),
        range: '15 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Original local version: 1d6 fire damage.',
      );

      final incomingNovelSpell = Spell(
        id: const EntityId(slug: 'ice-spike', ruleset: RulesetVersion.homebrew),
        name: 'Ice Spike',
        level: 1,
        school: 'Conjuration',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '60 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Shoots a piercing spike of ice.',
      );

      final incomingIdenticalSpell = Spell(
        id: const EntityId(slug: 'fire-whip', ruleset: RulesetVersion.homebrew),
        name: 'Fire Whip',
        level: 1,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.timed, durationSeconds: 60),
        range: '15 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Original local version: 1d6 fire damage.',
      );

      final incomingConflictingSpell = Spell(
        id: const EntityId(slug: 'fire-whip', ruleset: RulesetVersion.homebrew),
        name: 'Fire Whip (Updated)',
        level: 2, // Changed level
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.bonusAction), // Changed action
        duration: const SpellDuration(type: DurationType.timed, durationSeconds: 60),
        range: '30 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Updated version with 2d6 fire damage.',
      );

      const resolver = HomebrewMergeResolver();

      // Case 1: Novel + Identical
      final result1 = resolver.analyzeBundle(
        incomingBundle: HomebrewBundle(
          appVersion: '1.0.0',
          exportedAt: DateTime.now(),
          spells: [incomingNovelSpell, incomingIdenticalSpell],
        ),
        localSpells: [existingSpell],
      );

      expect(result1.novelCount, equals(1));
      expect(result1.identicalCount, equals(1));
      expect(result1.collisionCount, equals(0));
      expect(result1.spells[0].disposition, equals(ImportDisposition.novel));
      expect(result1.spells[0].isSelected, isTrue);
      expect(result1.spells[1].disposition, equals(ImportDisposition.identical));
      expect(result1.spells[1].isSelected, isFalse);

      // Case 2: Collision
      final result2 = resolver.analyzeBundle(
        incomingBundle: HomebrewBundle(
          appVersion: '1.0.0',
          exportedAt: DateTime.now(),
          spells: [incomingConflictingSpell],
        ),
        localSpells: [existingSpell],
      );

      expect(result2.collisionCount, equals(1));
      expect(result2.spells[0].disposition, equals(ImportDisposition.collision));
      expect(result2.spells[0].diffSummary, contains('level'));
      expect(result2.spells[0].isSelected, isTrue);
    });

    test('importResolvedBundle correctly handles Overwrite vs Duplicate Rename', () async {
      final persistence = HomebrewPersistenceService();

      final existingSpell = Spell(
        id: const EntityId(slug: 'shadow-blade-custom', ruleset: RulesetVersion.homebrew),
        name: 'Shadow Blade Custom',
        level: 2,
        school: 'Illusion',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.bonusAction),
        duration: const SpellDuration(type: DurationType.timed, durationSeconds: 60),
        range: 'Self',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Version 1.0',
      );

      await persistence.saveCustomSpell(existingSpell);

      final incomingSpell = Spell(
        id: const EntityId(slug: 'shadow-blade-custom', ruleset: RulesetVersion.homebrew),
        name: 'Shadow Blade Custom',
        level: 3,
        school: 'Illusion',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.bonusAction),
        duration: const SpellDuration(type: DurationType.timed, durationSeconds: 60),
        range: 'Self',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Version 2.0 (Upgraded)',
      );

      const resolver = HomebrewMergeResolver();
      final analysis = resolver.analyzeBundle(
        incomingBundle: HomebrewBundle(
          appVersion: '1.0.0',
          exportedAt: DateTime.now(),
          spells: [incomingSpell],
        ),
        localSpells: await persistence.loadCustomSpells(),
      );

      expect(analysis.collisionCount, equals(1));

      // Test Duplicate/Rename resolution
      analysis.spells.first.resolution = CollisionResolution.duplicateRename;
      await persistence.importResolvedBundle(analysis);

      final allSpells = await persistence.loadCustomSpells();
      expect(allSpells.length, equals(2));
      expect(allSpells.any((s) => s.id.slug == 'shadow-blade-custom' && s.level == 2), isTrue);
      expect(allSpells.any((s) => s.id.slug == 'shadow-blade-custom-copy' && s.level == 3), isTrue);
    });

    test('applyResolutionToAllCollisions updates all colliding entities across categories', () {
      final existingSpell = Spell(
        id: const EntityId(slug: 'spell-a', ruleset: RulesetVersion.homebrew),
        name: 'Spell A',
        level: 1,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '30 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Local A',
      );
      final incomingSpell = Spell(
        id: const EntityId(slug: 'spell-a', ruleset: RulesetVersion.homebrew),
        name: 'Spell A Modified',
        level: 2,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '30 ft.',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Incoming A',
      );

      final existingMonster = Monster(
        id: const EntityId(slug: 'beast-b', ruleset: RulesetVersion.homebrew),
        name: 'Beast B',
        size: 'Medium',
        monsterType: 'Beast',
        alignment: 'Unaligned',
        armorClass: 12,
        hitPoints: 15,
        hitDieFormula: '2d8 + 4',
        challengeRating: '1/4',
        actionsMarkdown: 'Bite',
      );
      final incomingMonster = Monster(
        id: const EntityId(slug: 'beast-b', ruleset: RulesetVersion.homebrew),
        name: 'Beast B Alpha',
        size: 'Large',
        monsterType: 'Beast',
        alignment: 'Unaligned',
        armorClass: 14,
        hitPoints: 30,
        hitDieFormula: '4d10 + 8',
        challengeRating: '1',
        actionsMarkdown: 'Multiattack',
      );

      const resolver = HomebrewMergeResolver();
      final analysis = resolver.analyzeBundle(
        incomingBundle: HomebrewBundle(
          appVersion: '1.0.0',
          exportedAt: DateTime.now(),
          spells: [incomingSpell],
          monsters: [incomingMonster],
        ),
        localSpells: [existingSpell],
        localMonsters: [existingMonster],
      );

      expect(analysis.collisionCount, equals(2));
      expect(analysis.spells.first.resolution, equals(CollisionResolution.overwrite));
      expect(analysis.monsters.first.resolution, equals(CollisionResolution.overwrite));

      // Apply bulk resolution
      analysis.applyResolutionToAllCollisions(CollisionResolution.keepLocal);
      expect(analysis.spells.first.resolution, equals(CollisionResolution.keepLocal));
      expect(analysis.monsters.first.resolution, equals(CollisionResolution.keepLocal));

      analysis.applyResolutionToAllCollisions(CollisionResolution.duplicateRename);
      expect(analysis.spells.first.resolution, equals(CollisionResolution.duplicateRename));
      expect(analysis.monsters.first.resolution, equals(CollisionResolution.duplicateRename));
    });
  });
}
