import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dnd_5e_rules_engine.dart';

void main() {
  group('Dnd5eRulesEngine Tests', () {
    test('Ability Modifier calculation matches 5e RAW floor((score-10)/2)', () {
      expect(Dnd5eRulesEngine.calculateModifier(1), -5);
      expect(Dnd5eRulesEngine.calculateModifier(3), -4);
      expect(Dnd5eRulesEngine.calculateModifier(8), -1);
      expect(Dnd5eRulesEngine.calculateModifier(9), -1);
      expect(Dnd5eRulesEngine.calculateModifier(10), 0);
      expect(Dnd5eRulesEngine.calculateModifier(11), 0);
      expect(Dnd5eRulesEngine.calculateModifier(12), 1);
      expect(Dnd5eRulesEngine.calculateModifier(13), 1);
      expect(Dnd5eRulesEngine.calculateModifier(14), 2);
      expect(Dnd5eRulesEngine.calculateModifier(18), 4);
      expect(Dnd5eRulesEngine.calculateModifier(20), 5);
      expect(Dnd5eRulesEngine.calculateModifier(24), 7);
      expect(Dnd5eRulesEngine.calculateModifier(30), 10);
    });

    test('Proficiency Bonus scales correctly from Level 1 to 20', () {
      // Level 1-4: +2
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(1), 2);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(4), 2);

      // Level 5-8: +3
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(5), 3);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(8), 3);

      // Level 9-12: +4
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(9), 4);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(12), 4);

      // Level 13-16: +5
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(13), 5);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(16), 5);

      // Level 17-20: +6
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(17), 6);
      expect(Dnd5eRulesEngine.calculateProficiencyBonus(20), 6);
    });

    test('Non-stacking Armor Class resolves correctly across formulas', () {
      // Barbarian Unarmored Defense: 10 + Dex (3) + Con (4) + Shield (2) = 19
      final barbarianAc = Dnd5eRulesEngine.calculateArmorClass(
        armorType: ArmorType.unarmored,
        dexModifier: 3,
        conModifier: 4,
        isBarbarianUnarmored: true,
        hasShield: true,
      );
      expect(barbarianAc, 19);

      // Monk Unarmored Defense: 10 + Dex (4) + Wis (3) = 17 (Shield not allowed)
      final monkAcNoShield = Dnd5eRulesEngine.calculateArmorClass(
        armorType: ArmorType.unarmored,
        dexModifier: 4,
        wisModifier: 3,
        isMonkUnarmored: true,
        hasShield: false,
      );
      expect(monkAcNoShield, 17);

      // Monk with Shield falls back to 10 + Dex (4) + Shield (2) = 16
      final monkAcWithShield = Dnd5eRulesEngine.calculateArmorClass(
        armorType: ArmorType.unarmored,
        dexModifier: 4,
        wisModifier: 3,
        isMonkUnarmored: true,
        hasShield: true,
      );
      expect(monkAcWithShield, 16);

      // Mage Armor: 13 + Dex (3) + Shield (2) = 18
      final mageArmorAc = Dnd5eRulesEngine.calculateArmorClass(
        armorType: ArmorType.unarmored,
        dexModifier: 3,
        hasMageArmor: true,
        hasShield: true,
      );
      expect(mageArmorAc, 18);

      // Medium Armor (Breastplate 14, Dex +3 capped at +2, Shield +2) = 18
      final mediumArmorAc = Dnd5eRulesEngine.calculateArmorClass(
        armorType: ArmorType.medium,
        baseArmorAc: 14,
        dexModifier: 3,
        hasShield: true,
      );
      expect(mediumArmorAc, 18);

      // Heavy Armor (Plate 18, Dex ignored, Shield +2, Ring of Protection +1) = 21
      final heavyArmorAc = Dnd5eRulesEngine.calculateArmorClass(
        armorType: ArmorType.heavy,
        baseArmorAc: 18,
        dexModifier: -1,
        hasShield: true,
        magicItemAcBonus: 1,
      );
      expect(heavyArmorAc, 21);
    });

    test('Multiclass Spellcaster Table calculates effective caster levels and slots', () {
      // Single class Wizard level 5 -> 3rd level slots (4, 3, 2)
      final wizardSlots = Dnd5eRulesEngine.calculateMulticlassSpellSlots(fullCasterLevels: 5);
      expect(wizardSlots[1], 4);
      expect(wizardSlots[2], 3);
      expect(wizardSlots[3], 2);
      expect(wizardSlots[4], 0);

      // Paladin 6 (half = 3) + Sorcerer 4 (full = 4) -> Effective Level 7 (4, 3, 3, 1)
      final paladinSorcererSlots = Dnd5eRulesEngine.calculateMulticlassSpellSlots(
        fullCasterLevels: 4,
        halfCasterLevels: 6,
      );
      expect(paladinSorcererSlots[1], 4);
      expect(paladinSorcererSlots[2], 3);
      expect(paladinSorcererSlots[3], 3);
      expect(paladinSorcererSlots[4], 1);
      expect(paladinSorcererSlots[5], 0);

      // Artificer 3 (ceil(3/2) = 2) + Wizard 2 (full = 2) -> Effective Level 4 (4, 3) per TCoE
      final artificerWizard = Dnd5eRulesEngine.calculateMulticlassSpellSlots(
        fullCasterLevels: 2,
        artificerLevels: 3,
      );
      expect(artificerWizard[1], 4);
      expect(artificerWizard[2], 3);
      expect(artificerWizard[3], 0);

      // Single class Artificer level 5 (ceil(5/2) = 3) -> 2nd level slots (4, 2)
      final singleArtificer = Dnd5eRulesEngine.calculateMulticlassSpellSlots(
        artificerLevels: 5,
      );
      expect(singleArtificer[1], 4);
      expect(singleArtificer[2], 2);
      expect(singleArtificer[3], 0);
    });

    test('Pact Magic slot calculator tracks slots distinctly from Spellcasting', () {
      expect(Dnd5eRulesEngine.calculatePactMagicSlots(1), (slotLevel: 1, slotCount: 1));
      expect(Dnd5eRulesEngine.calculatePactMagicSlots(2), (slotLevel: 1, slotCount: 2));
      expect(Dnd5eRulesEngine.calculatePactMagicSlots(5), (slotLevel: 3, slotCount: 2));
      expect(Dnd5eRulesEngine.calculatePactMagicSlots(9), (slotLevel: 5, slotCount: 2));
      expect(Dnd5eRulesEngine.calculatePactMagicSlots(11), (slotLevel: 5, slotCount: 3));
      expect(Dnd5eRulesEngine.calculatePactMagicSlots(17), (slotLevel: 5, slotCount: 4));
    });

    test('Mystic Arcanum unlocks single daily uses of 6th-9th level spells', () {
      final lvl10 = Dnd5eRulesEngine.calculateMysticArcanum(10);
      expect(lvl10[6], 0);

      final lvl11 = Dnd5eRulesEngine.calculateMysticArcanum(11);
      expect(lvl11[6], 1);
      expect(lvl11[7], 0);

      final lvl13 = Dnd5eRulesEngine.calculateMysticArcanum(13);
      expect(lvl13[6], 1);
      expect(lvl13[7], 1);
      expect(lvl13[8], 0);

      final lvl17 = Dnd5eRulesEngine.calculateMysticArcanum(17);
      expect(lvl17[6], 1);
      expect(lvl17[7], 1);
      expect(lvl17[8], 1);
      expect(lvl17[9], 1);
    });

    test('Hit Dice Long Rest Recovery recovers up to half total max HD (min 1)', () {
      expect(Dnd5eRulesEngine.calculateRecoveredHitDice(1), 1);
      expect(Dnd5eRulesEngine.calculateRecoveredHitDice(3), 1);
      expect(Dnd5eRulesEngine.calculateRecoveredHitDice(4), 2);
      expect(Dnd5eRulesEngine.calculateRecoveredHitDice(5), 2);
      expect(Dnd5eRulesEngine.calculateRecoveredHitDice(10), 5);
      expect(Dnd5eRulesEngine.calculateRecoveredHitDice(20), 10);
    });
  });
}
