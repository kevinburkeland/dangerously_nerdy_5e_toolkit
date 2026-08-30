import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spell_allocation_validator.dart';

void main() {
  group('SpellAllocationValidator RAW Tests', () {
    test('Wizard Level 1 spell limits and spellbook initial scribe quota', () {
      final limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'wizard',
        classLevel: 1,
        abilityModifier: 3, // 16 INT -> +3
        edition: DmRulesEdition.v2024,
      );

      expect(limits.isSpellcaster, isTrue);
      expect(limits.maxCantrips, 3);
      expect(limits.maxSpellsPrepared, 4); // 1 + 3 = 4
      expect(limits.maxSpellbookInitialScribe, 6);
      expect(limits.maxSpellbookLevelUpScribe, 2);
      expect(limits.maxSpellSlotLevel, 1);
    });

    test('Wizard Level 1 validates exactly 6 spellbook spells', () {
      final cantrips = [
        EntityReference<Spell>(refType: EntityType.spell, slug: 'fire-bolt', displayName: 'Fire Bolt'),
        EntityReference<Spell>(refType: EntityType.spell, slug: 'mage-hand', displayName: 'Mage Hand'),
        EntityReference<Spell>(refType: EntityType.spell, slug: 'light', displayName: 'Light'),
      ];

      final spellbookValid = List.generate(
        6,
        (i) => EntityReference<Spell>(refType: EntityType.spell, slug: 'spell-$i', displayName: 'Spell $i'),
      );

      final preparedValid = spellbookValid.take(4).toList();

      final result = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'wizard',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        cantrips: cantrips,
        spellsKnown: spellbookValid,
        spellsPrepared: preparedValid,
        edition: DmRulesEdition.v2024,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);

      // Invalid: Only 5 spells in spellbook
      final invalidResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'wizard',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        cantrips: cantrips,
        spellsKnown: spellbookValid.take(5).toList(),
        spellsPrepared: preparedValid,
        edition: DmRulesEdition.v2024,
      );

      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.first, contains('6 1st-level spells'));
    });

    test('Sorcerer Spells Known progression across levels', () {
      final lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'sorcerer',
        classLevel: 1,
        abilityModifier: 3,
      );
      expect(lvl1.maxCantrips, 4);
      expect(lvl1.maxSpellsKnown, 2);
      expect(lvl1.maxSpellSlotLevel, 1);

      final lvl5 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'sorcerer',
        classLevel: 5,
        abilityModifier: 4,
      );
      expect(lvl5.maxCantrips, 5);
      expect(lvl5.maxSpellsKnown, 6);
      expect(lvl5.maxSpellSlotLevel, 3);
    });

    test('Paladin spellcasting starts at Level 2 in 2014, Level 1 in 2024', () {
      final paladin2014Lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 2,
        edition: DmRulesEdition.v2014,
      );
      expect(paladin2014Lvl1.isSpellcaster, isFalse);
      expect(paladin2014Lvl1.maxSpellSlotLevel, 0);

      final paladin2024Lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 2,
        edition: DmRulesEdition.v2024,
      );
      expect(paladin2024Lvl1.isSpellcaster, isTrue);
      expect(paladin2024Lvl1.maxSpellSlotLevel, 1);
      expect(paladin2024Lvl1.maxSpellsPrepared, 3); // ((1+1)~/2) + 2 = 3
    });

    test('Max tier gating prevents selecting higher level spells', () {
      final tierLvl3Wizard = SpellAllocationValidator.getMaxSpellTierForClass(
        classSlug: 'wizard',
        classLevel: 3,
      );
      expect(tierLvl3Wizard, 2); // 3rd level wizard can cast up to 2nd level spells

      final tierLvl5Ranger2014 = SpellAllocationValidator.getMaxSpellTierForClass(
        classSlug: 'ranger',
        classLevel: 5,
        edition: DmRulesEdition.v2014,
      );
      expect(tierLvl5Ranger2014, 2);
    });
  });
}
