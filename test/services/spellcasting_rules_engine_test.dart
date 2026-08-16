import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

void main() {
  group('MulticlassSlotMatrix & PactMagicPool Tests', () {
    test('Calculates standard single-class full caster slots accurately', () {
      final level1Slots = MulticlassSlotMatrix.getSpellSlots(1);
      expect(level1Slots, [2, 0, 0, 0, 0, 0, 0, 0, 0]);

      final level5Slots = MulticlassSlotMatrix.getSpellSlots(5);
      expect(level5Slots, [4, 3, 2, 0, 0, 0, 0, 0, 0]);

      final level20Slots = MulticlassSlotMatrix.getSpellSlots(20);
      expect(level20Slots, [4, 3, 3, 3, 3, 2, 2, 1, 1]);
    });

    test('Calculates multiclass effective caster level and slots', () {
      // Level 6 Paladin (3) + Level 4 Sorcerer (4) = Effective Level 7
      final effectiveLevel = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
        fullCasterLevels: 4,
        paladinLevels: 6,
      );
      expect(effectiveLevel, 7);

      final slots = MulticlassSlotMatrix.getSpellSlots(effectiveLevel);
      expect(slots, [4, 3, 3, 1, 0, 0, 0, 0, 0]);
    });

    test('Artificer multiclass rounding (ceil(level / 2))', () {
      // Level 3 Artificer (ceil(3/2) = 2) + Level 2 Wizard (2) = Effective Level 4
      final effectiveLevel = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
        fullCasterLevels: 2,
        artificerLevels: 3,
      );
      expect(effectiveLevel, 4);

      final slots = MulticlassSlotMatrix.getSpellSlots(effectiveLevel);
      expect(slots, [4, 3, 0, 0, 0, 0, 0, 0, 0]);
    });

    test('Pact Magic pool progression by Warlock level', () {
      final warlock1 = PactMagicPool.fromWarlockLevel(1);
      expect(warlock1.totalSlots, 1);
      expect(warlock1.slotLevel, 1);

      final warlock2 = PactMagicPool.fromWarlockLevel(2);
      expect(warlock2.totalSlots, 2);
      expect(warlock2.slotLevel, 1);

      final warlock5 = PactMagicPool.fromWarlockLevel(5);
      expect(warlock5.totalSlots, 2);
      expect(warlock5.slotLevel, 3);

      final warlock9 = PactMagicPool.fromWarlockLevel(9);
      expect(warlock9.totalSlots, 2);
      expect(warlock9.slotLevel, 5);

      final warlock11 = PactMagicPool.fromWarlockLevel(11);
      expect(warlock11.totalSlots, 3);
      expect(warlock11.slotLevel, 5);

      final warlock17 = PactMagicPool.fromWarlockLevel(17);
      expect(warlock17.totalSlots, 4);
      expect(warlock17.slotLevel, 5);
    });
  });

  group('CasterPreparationRules Tests', () {
    test('Calculates full caster max prepared spells (Level + Mod)', () {
      final prep = CasterPreparationRules.calculateMaxPreparedSpells(
        spellClass: SpellClass.wizard,
        classLevel: 5,
        abilityModifier: 3,
      );
      expect(prep, 8);
    });

    test('Calculates half caster max prepared spells (floor(Level/2) + Mod)', () {
      final prep = CasterPreparationRules.calculateMaxPreparedSpells(
        spellClass: SpellClass.paladin,
        classLevel: 7,
        abilityModifier: 3,
      );
      expect(prep, 6); // floor(7/2) + 3 = 3 + 3 = 6
    });

    test('Spontaneous casters return 0 prepared spells ceiling', () {
      final prep = CasterPreparationRules.calculateMaxPreparedSpells(
        spellClass: SpellClass.sorcerer,
        classLevel: 10,
        abilityModifier: 5,
      );
      expect(prep, 0);
    });

    test('Wizard transcription gold and time cost calculations', () {
      // 3rd-level Evocation spell copied by Evoker Wizard (halved)
      final specialized = CasterPreparationRules.calculateWizardCopyCost(
        spellLevel: 3,
        spellSchool: SpellSchool.evocation,
        wizardSchoolSpecialization: SpellSchool.evocation,
      );
      expect(specialized.goldCostGp, 75);
      expect(specialized.timeInHours, 3);

      // 3rd-level Evocation spell copied by Necromancer Wizard (full cost)
      final nonSpecialized = CasterPreparationRules.calculateWizardCopyCost(
        spellLevel: 3,
        spellSchool: SpellSchool.evocation,
        wizardSchoolSpecialization: SpellSchool.necromancy,
      );
      expect(nonSpecialized.goldCostGp, 150);
      expect(nonSpecialized.timeInHours, 6);
    });
  });

  group('CantripScalingEngine & Upcasting Math Tests', () {
    test('Cantrip tier multiplier across character levels', () {
      expect(CantripScalingEngine.getMultiplier(1), 1);
      expect(CantripScalingEngine.getMultiplier(4), 1);
      expect(CantripScalingEngine.getMultiplier(5), 2);
      expect(CantripScalingEngine.getMultiplier(10), 2);
      expect(CantripScalingEngine.getMultiplier(11), 3);
      expect(CantripScalingEngine.getMultiplier(16), 3);
      expect(CantripScalingEngine.getMultiplier(17), 4);
      expect(CantripScalingEngine.getMultiplier(20), 4);
    });

    test('Scales cantrip formula by character level', () {
      expect(CantripScalingEngine.scaleCantripFormula('1d10', 1), '1d10');
      expect(CantripScalingEngine.scaleCantripFormula('1d10', 5), '2d10');
      expect(CantripScalingEngine.scaleCantripFormula('1d10', 11), '3d10');
      expect(CantripScalingEngine.scaleCantripFormula('1d10', 17), '4d10');
    });

    test('SpellScalingFormula evaluates dynamic upcasting', () {
      // Fireball: 8d6 base, +1d6 per slot above 3rd
      const fireballScaling = SpellScalingFormula(baseDiceCount: 8, diceSides: 6, dicePerSlotLevel: 1);
      expect(fireballScaling.getFormulaForSlot(3, 3), '8d6');
      expect(fireballScaling.getFormulaForSlot(3, 5), '10d6');
      expect(fireballScaling.getFormulaForSlot(3, 9), '14d6');

      // 2024 Cure Wounds: 2d8 + mod base, +2d8 per slot above 1st
      const cureWoundsScaling = SpellScalingFormula(
        baseDiceCount: 2,
        diceSides: 8,
        dicePerSlotLevel: 2,
        addsAbilityMod: true,
      );
      expect(cureWoundsScaling.getFormulaForSlot(1, 1), '2d8 + mod');
      expect(cureWoundsScaling.getFormulaForSlot(1, 3), '6d8 + mod');

      // Spiritual Weapon: 1d8 + mod base, +1d8 per TWO slots above 2nd (step: 2)
      const spiritualWeaponScaling = SpellScalingFormula(
        baseDiceCount: 1,
        diceSides: 8,
        dicePerSlotLevel: 1,
        slotStep: 2,
        addsAbilityMod: true,
      );
      expect(spiritualWeaponScaling.getFormulaForSlot(2, 2), '1d8 + mod');
      expect(spiritualWeaponScaling.getFormulaForSlot(2, 3), '1d8 + mod');
      expect(spiritualWeaponScaling.getFormulaForSlot(2, 4), '2d8 + mod');
    });

    test('SpellRollEngine evaluates formulas and adds modifiers', () {
      final roll1 = SpellRollEngine.roll(formula: '8d6');
      expect(roll1.individualDice.length, 8);
      expect(roll1.modifier, 0);
      expect(roll1.total, greaterThanOrEqualTo(8));
      expect(roll1.total, lessThanOrEqualTo(48));

      final roll2 = SpellRollEngine.roll(formula: '2d8 + mod', abilityModifier: 4);
      expect(roll2.individualDice.length, 2);
      expect(roll2.modifier, 4);
      expect(roll2.total, greaterThanOrEqualTo(6));
      expect(roll2.total, lessThanOrEqualTo(20));
      expect(roll2.formulaDescription, '2d8 + 4');
    });
  });

  group('ConcentrationRules & ActionEconomyValidator Tests', () {
    test('Concentration save DC calculation', () {
      expect(ConcentrationRules.calculateSaveDc(0), 10);
      expect(ConcentrationRules.calculateSaveDc(8), 10);
      expect(ConcentrationRules.calculateSaveDc(20), 10);
      expect(ConcentrationRules.calculateSaveDc(22), 11);
      expect(ConcentrationRules.calculateSaveDc(50), 25);
    });

    test('2014 Bonus Action spell casting validation', () {
      // Casting 1-Action Cantrip after Bonus Action spell is valid
      final check1 = ActionEconomySpellValidator.validateBonusActionCasting(
        hasCastBonusActionSpell: true,
        incomingSpellLevel: 0,
        incomingCastingTime: '1 Action',
        edition: DmRulesEdition.v2014,
      );
      expect(check1.isValid, isTrue);

      // Casting Leveled spell after Bonus Action spell is invalid
      final check2 = ActionEconomySpellValidator.validateBonusActionCasting(
        hasCastBonusActionSpell: true,
        incomingSpellLevel: 3,
        incomingCastingTime: '1 Action',
        edition: DmRulesEdition.v2014,
      );
      expect(check2.isValid, isFalse);
      expect(check2.warningMessage, contains('RAW 2014 Restriction'));
    });

    test('2024 Spell Slot turn limitation validation', () {
      final checkLeveled = ActionEconomySpellValidator.validateBonusActionCasting(
        hasCastBonusActionSpell: true,
        incomingSpellLevel: 2,
        incomingCastingTime: '1 Action',
        edition: DmRulesEdition.v2024,
      );
      expect(checkLeveled.isValid, isFalse);
      expect(checkLeveled.warningMessage, contains('RAW 2024 Restriction'));
    });
  });

  group('SRD Spell Catalog Model Integrity Tests', () {
    test('Cure Wounds and Healing Word have edition-accurate schools', () {
      final cureWounds = SpellbookLibrary.getSpellById('spell_cure_wounds')!;
      expect(cureWounds.getSchool(DmRulesEdition.v2014), SpellSchool.evocation);
      expect(cureWounds.getSchool(DmRulesEdition.v2024), SpellSchool.abjuration);

      final healingWord = SpellbookLibrary.getSpellById('spell_healing_word')!;
      expect(healingWord.getSchool(DmRulesEdition.v2014), SpellSchool.evocation);
      expect(healingWord.getSchool(DmRulesEdition.v2024), SpellSchool.abjuration);
    });

    test('Create Undead has costly material component marked', () {
      final createUndead = SpellbookLibrary.getSpellById('spell_create_undead')!;
      final mat2014 = createUndead.rules2014.materialDetails;
      expect(mat2014, isNotNull);
      expect(mat2014!.hasCost, isTrue);
      expect(mat2014.costInGp, 150);
      expect(mat2014.canBeReplacedByFocus, isFalse);
    });

    test('Reaction spells have formatted triggers', () {
      final shield = SpellbookLibrary.getSpellById('spell_shield')!;
      expect(shield.rules2014.reactionTrigger, isNotNull);

      final counterspell = SpellbookLibrary.getSpellById('spell_counterspell')!;
      expect(counterspell.rules2014.reactionTrigger, isNotNull);
    });

    test('All spell levels 0 through 9 are present in library', () {
      for (int lvl = 0; lvl <= 9; lvl++) {
        // Skip 0 if tested as cantrip
        final spellsAtLevel = SpellbookLibrary.getSpellsByLevel(lvl);
        expect(spellsAtLevel.isNotEmpty, isTrue, reason: 'Level $lvl spells should not be empty');
      }
    });

    test('Costly material components consume flags and costs are accurate', () {
      final revivify = SpellbookLibrary.getSpellById('spell_revivify')!;
      expect(revivify.rules2014.materialDetails?.costInGp, 300);
      expect(revivify.rules2014.materialDetails?.isConsumed, isTrue);

      final greaterRestoration = SpellbookLibrary.getSpellById('spell_greater_restoration')!;
      expect(greaterRestoration.rules2014.materialDetails?.costInGp, 100);
      expect(greaterRestoration.rules2014.materialDetails?.isConsumed, isTrue);

      final forcecage = SpellbookLibrary.getSpellById('spell_forcecage')!;
      expect(forcecage.rules2014.materialDetails?.isConsumed, isFalse);
      expect(forcecage.rules2024.materialDetails?.isConsumed, isTrue);
    });

    test('Spell filters by class return expected results', () {
      final wizardSpells = SpellbookLibrary.getSpellsByClass(SpellClass.wizard);
      expect(wizardSpells.any((s) => s.name == 'Fireball'), isTrue);
      expect(wizardSpells.any((s) => s.name == 'Wish'), isTrue);

      final clericSpells = SpellbookLibrary.getSpellsByClass(SpellClass.cleric);
      expect(clericSpells.any((s) => s.name == 'Spirit Guardians'), isTrue);
      expect(clericSpells.any((s) => s.name == 'Heal'), isTrue);
    });
  });
}
