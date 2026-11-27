import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/spell_cast_formula_resolver.dart';

EvaluatedCharacterStats _clericStats({
  RulesetEdition edition = RulesetEdition.v2024,
  int wisdom = 16,
}) {
  final character = Character(
    id: EntityId(
      slug: 'cleric-resolver-test',
      ruleset: edition == RulesetEdition.v2024
          ? RulesetVersion.v2024
          : RulesetVersion.v2014,
    ),
    name: 'Test Cleric',
    rulesEdition: edition,
    speciesRef: const EntityReference.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'cleric',
            displayName: 'Cleric',
          ),
          level: 5,
          hitDie: 'd8',
          isStartingClass: true,
        ),
      ],
    ),
    baseScores: AbilityScores(wisdom: wisdom),
    resources: const CharacterResourcePool(currentHp: 38),
  );
  return CharacterEvaluationEngine.evaluate(character);
}

Spell _inMemorySpell({
  required String slug,
  required String name,
  required String baseFormula,
}) =>
    Spell.singleEdition(
      id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
      name: name,
      level: 1,
      school: 'evocation',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      duration: const SpellDuration(type: DurationType.instantaneous),
      range: 'Touch',
      components: const SpellComponents(v: true, s: true),
      descriptionMarkdown: 'In-memory test spell.',
      damageMath: [
        EvaluationMath(
          diceFormula: baseFormula,
          damageType: DamageType.radiant,
        ),
      ],
    );

void main() {
  group('SpellCastFormulaResolver addsAbilityMod from scaling rule (Fix 1.3)',
      () {
    test(
      'scaling rule addsAbilityMod without mod in base formula adds caster modifier once',
      () {
        final stats = _clericStats(wisdom: 16); // WIS +3
        final spell = _inMemorySpell(
          slug: 'in-memory-heal-no-mod',
          name: 'In-Memory Heal No Mod',
          baseFormula: '1d8',
        );

        final plan = SpellCastFormulaResolver.resolvePlan(
          spell,
          delta: 0,
          stats: stats,
          rulesEdition: RulesetEdition.v2024,
          scalingRule: const SpellScalingFormula(
            baseDiceCount: 1,
            diceSides: 8,
            addsAbilityMod: true,
          ),
        );

        expect(plan.errorMessage, isNull);
        expect(plan.spellModContribution, equals(3));
      },
    );

    test(
      'guard: scaling rule addsAbilityMod with + mod already in base adds caster modifier once',
      () {
        final stats = _clericStats(wisdom: 16); // WIS +3
        final spell = _inMemorySpell(
          slug: 'in-memory-heal-with-mod',
          name: 'In-Memory Heal With Mod',
          baseFormula: '1d8 + mod',
        );

        final plan = SpellCastFormulaResolver.resolvePlan(
          spell,
          delta: 0,
          stats: stats,
          rulesEdition: RulesetEdition.v2024,
          scalingRule: const SpellScalingFormula(
            baseDiceCount: 1,
            diceSides: 8,
            addsAbilityMod: true,
          ),
        );

        expect(plan.errorMessage, isNull);
        expect(plan.spellModContribution, equals(3));
      },
    );
  });
}
