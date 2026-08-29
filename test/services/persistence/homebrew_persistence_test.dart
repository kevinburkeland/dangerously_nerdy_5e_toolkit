import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
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
  });
}
