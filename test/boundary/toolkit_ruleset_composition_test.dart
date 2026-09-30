import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/rules/i_ruleset_module.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Toolkit Ruleset Package Composition Test', () {
    test('Toolkit consumes external vtt_ruleset_dnd5e package and composes correctly', () {
      // 1. Verify external ruleset module contracts are resolved via SPI
      const IRulesetModule ruleset2024 = Dnd5eRulesetModule.v2024();
      expect(ruleset2024.moduleId, equals('dnd5e_2024'));
      expect(ruleset2024.attributeSystem.attributeKeys, contains('strength'));

      const IRulesetModule ruleset2014 = Dnd5eRulesetModule.v2014();
      expect(ruleset2014.moduleId, equals('dnd5e_2014'));

      // 2. Verify toolkit ReferenceResolver implements IEntityResolver from vtt_ruleset_dnd5e
      final repo = LayeredPriorityRepository();
      final resolver = ReferenceResolver(repo);
      expect(resolver, isA<IEntityResolver>());

      // 3. Verify character evaluation executes through external ruleset engine
      const character = Character(
        id: EntityId(slug: 'composition-test-hero', ruleset: RulesetVersion.v2024),
        name: 'Sir Galahad',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'paladin',
                displayName: 'Paladin',
              ),
              level: 3,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16, dexterity: 10, constitution: 14),
        resources: CharacterResourcePool(currentHp: 28),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.abilityModifiers[AbilityType.strength], equals(3));
      expect(stats.armorClass, equals(10)); // Unarmored 10 + 0

      // 4. Verify Dnd5eScoreMath operates from vtt_ruleset_dnd5e
      expect(16.dndModifier, equals(3));
      expect(Dnd5eScoreMath.scoreToModifier(16), equals(3));
      expect(Dnd5eScoreMath.formatScoreWithModifier(16), equals('16 (+3)'));
    });
  });
}
