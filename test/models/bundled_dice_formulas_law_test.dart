import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

List<String> validateSpellDiceFormulas(
  List<SpellItem> spells,
  List<DmRulesEdition> editions,
) {
  final problems = <String>[];

  for (final spell in spells) {
    for (final edition in editions) {
      final rules = spell.getRules(edition);
      final raw = rules.rollFormula?.trim();
      if (raw == null || raw.isEmpty || raw.toLowerCase() == 'none') {
        continue;
      }

      // 1. Base roll formula
      try {
        DiceExpression.parse(raw);
      } on FormatException catch (e) {
        problems.add(
          'Spell "${spell.id}" ($edition) base rollFormula "$raw": ${e.message}',
        );
      }

      // 2. Cantrip scaling formulas
      if (spell.level == 0) {
        for (final lvl in [1, 5, 11, 17]) {
          final scaled =
              CantripScalingEngine.scaleCantripFormula(raw, lvl);
          try {
            DiceExpression.parse(scaled);
          } on FormatException catch (e) {
            problems.add(
              'Spell "${spell.id}" ($edition) cantrip scale lvl $lvl "$scaled": ${e.message}',
            );
          }
        }
      }

      // 3. Leveled spell upcast scaling formulas
      if (rules.scalingFormula != null) {
        for (var slot = spell.level; slot <= 9; slot++) {
          final slotFormula =
              rules.scalingFormula!.getFormulaForSlot(spell.level, slot);
          try {
            DiceExpression.parse(slotFormula);
          } on FormatException catch (e) {
            problems.add(
              'Spell "${spell.id}" ($edition) slot $slot "$slotFormula": ${e.message}',
            );
          }
        }
      }
    }
  }

  return problems;
}

void main() {
  group('Bundled Dice Formulas Laws (BF1 & BF1c)', () {
    test('BF1c (control): detects invalid dice formula in synthetic spell', () {
      const syntheticDetails = SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S',
        duration: 'Instantaneous',
        description: ['A fiery burst.'],
        classes: [SpellClass.wizard],
        rollFormula: '4d6 fire',
      );

      const badSpell = SpellItem(
        id: 'bad_test_spell',
        name: 'Bad Fire Spell',
        level: 1,
        school: SpellSchool.evocation,
        rules2014: syntheticDetails,
        rules2024: syntheticDetails,
      );

      final problems = validateSpellDiceFormulas(
        [badSpell],
        [DmRulesEdition.v2014],
      );

      expect(problems, hasLength(1));
      expect(problems.first, contains('bad_test_spell'));
      expect(problems.first, contains('4d6 fire'));
    });

    test('BF1 (data law): every bundled spell roll formula parses in both editions', () {
      const spells = SpellbookLibrary.srdSpells;
      final problems = validateSpellDiceFormulas(
        spells,
        const [DmRulesEdition.v2014, DmRulesEdition.v2024],
      );

      expect(
        problems,
        isEmpty,
        reason: 'All bundled spell roll formulas must strictly conform to dice expression grammar:\n'
            '${problems.join("\n")}',
      );
    });
  });
}
