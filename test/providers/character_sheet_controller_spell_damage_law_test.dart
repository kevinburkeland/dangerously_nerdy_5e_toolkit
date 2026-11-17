import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';

final _testReplica = ReplicaId('law_test_replica');

const _baseCharacter = Character(
  id: EntityId(slug: 'char-law', ruleset: RulesetVersion.v2024),
  name: 'Law Hero',
  speciesRef: EntityReference.empty(
    refType: EntityType.species,
    slug: 'human',
    displayName: 'Human',
  ),
  progression: CharacterProgression(
    classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
          refType: EntityType.classDefinition,
          slug: 'wizard',
          displayName: 'Wizard',
        ),
        level: 5,
        hitDie: 'd6',
        isStartingClass: true,
      ),
    ],
  ),
  baseScores: AbilityScores(intelligence: 16),
  resources: CharacterResourcePool(),
);

Spell _makeSpellWithFormula(String formula) {
  return Spell(
    id: const EntityId(slug: 'spell-law', ruleset: RulesetVersion.v2024),
    name: 'Law Spell',
    level: 1,
    school: 'evocation',
    castingTime: const CastingTime(
      cost: 1,
      actionType: ActionType.action,
      triggerCondition: '1 Action',
    ),
    duration: const SpellDuration(
      type: DurationType.instantaneous,
      rawText: 'Instantaneous',
    ),
    range: '60 ft.',
    components: const SpellComponents(v: true),
    descriptionMarkdown: 'Law spell testing non-dice formula behavior.',
    damageMath: [
      EvaluationMath(
        diceFormula: formula,
        damageType: DamageType.force,
      ),
    ],
  );
}

void main() {
  group('Law D17: No invented die when a formula cannot be read', () {
    test('Over >= 500 seeded generated non-dice strings, rollSpellDamage never rolls dice', () {
      final controller = CharacterSheetController(
        replicaId: _testReplica,
        character: _baseCharacter,
      );

      final rng = Random(42);
      const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ \t\n!@#\$%^&*()_+=[]{}|;:,.<>?/~`"\'0123456789';

      for (int i = 0; i < 550; i++) {
        // Generate pseudo-random string that does not contain dice notation
        final len = rng.nextInt(30);
        final chars = <String>[];
        for (int j = 0; j < len; j++) {
          final c = alphabet[rng.nextInt(alphabet.length)];
          // Avoid accidental 'd' or 'D' followed by digits
          if (c == 'd' || c == 'D') {
            chars.add('x');
          } else {
            chars.add(c);
          }
        }
        final candidate = chars.join();

        final spell = _makeSpellWithFormula(candidate);
        final result = controller.rollSpellDamage(spell);

        expect(
          result.diceEntries,
          isEmpty,
          reason: 'Seed $i with non-dice string "$candidate" must not roll any dice, but rolled: ${result.diceEntries}',
        );
      }
    });

    test('SRD Spell list check: spells with damage formulas parse cleanly', () {
      final allSpells = SpellbookLibrary.allSpells;
      expect(allSpells, isNotEmpty);

      // Verify spells with rollFormula parse cleanly
      for (final spell in allSpells) {
        final formula = spell.getRules(DmRulesEdition.v2024).rollFormula;
        if (formula != null && formula.isNotEmpty) {
          final expr = DiceExpression.tryParse(formula.trim()) ??
              DiceExpression.findAll(formula).firstOrNull?.expression;
          expect(expr, isNotNull, reason: 'Spell ${spell.id} formula "$formula" should parse');
        }
      }
    });
  });
}
