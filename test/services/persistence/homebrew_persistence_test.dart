import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomebrewPersistenceService Tests', () {
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      persistence = HomebrewPersistenceService();
    });

    test('saves, loads, and deletes custom spells', () async {
      final spell = Spell(
        id: const EntityId(slug: 'void-lance', ruleset: RulesetVersion.homebrew),
        name: 'Void Lance',
        level: 4,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '120 feet',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires a beam of necrotic void energy.',
        damageMath: const [EvaluationMath(diceFormula: '6d8', damageType: DamageType.necrotic)],
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
      final monster = Monster(
        id: const EntityId(slug: 'void-crawler', ruleset: RulesetVersion.homebrew),
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
      final item = EquipmentItem(
        id: const EntityId(slug: 'ring-of-aether', ruleset: RulesetVersion.homebrew),
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
      final spell = Spell(
        id: const EntityId(slug: 'chaos-bolt-homebrew', ruleset: RulesetVersion.homebrew),
        name: 'Chaos Bolt (Homebrew)',
        level: 1,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '120 feet',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Chaotic blast.',
      );

      await persistence.saveCustomSpell(spell);

      final repository = LayeredPriorityRepository();
      await persistence.hydrateRepository(repository);

      final lookupResult = repository.lookup<Spell>('chaos-bolt-homebrew');
      expect(lookupResult, isNotNull);
      expect(lookupResult!.name, equals('Chaos Bolt (Homebrew)'));
    });
    test('batch deletes custom entities by slug list and cleans up storage', () async {
      final spell1 = Spell(
        id: const EntityId(slug: 'fire-dart', ruleset: RulesetVersion.homebrew),
        name: 'Fire Dart',
        level: 1,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires a dart of flame.',
      );
      final spell2 = Spell(
        id: const EntityId(slug: 'ice-spike', ruleset: RulesetVersion.homebrew),
        name: 'Ice Spike',
        level: 2,
        school: 'Evocation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: const SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Fires an icy spike.',
      );
      final spell3 = Spell(
        id: const EntityId(slug: 'arcane-ward', ruleset: RulesetVersion.homebrew),
        name: 'Arcane Ward',
        level: 3,
        school: 'Abjuration',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: 'Self',
        components: const SpellComponents(v: true, s: true),
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

    test('clearHomebrewCategory purges specific category and updates runtime library', () async {
      final monster = Monster(
        id: const EntityId(slug: 'abyssal-stalker', ruleset: RulesetVersion.homebrew),
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

      await persistence.clearHomebrewCategory(EntityType.monster);
      expect((await persistence.loadCustomMonsters()), isEmpty);
    });

    test('reparseAllHomebrew upgrades entities from raw JSON and removes exact SRD matches', () async {
      // 1. Custom feat with raw JSON
      final feat = Feat(
        id: const EntityId(slug: 'astral-touched', ruleset: RulesetVersion.homebrew),
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
      final srdFeat = Feat(
        id: const EntityId(slug: 'grappler', ruleset: RulesetVersion.homebrew),
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
  });
}
