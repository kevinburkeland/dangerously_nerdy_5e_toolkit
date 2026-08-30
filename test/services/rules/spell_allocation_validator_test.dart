import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart' show SpellClass;
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
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'fire-bolt', displayName: 'Fire Bolt'),
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'mage-hand', displayName: 'Mage Hand'),
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'light', displayName: 'Light'),
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

    test('Bard 2014 Magical Secrets progression at levels 10, 14, 18', () {
      final l10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 10,
        abilityModifier: 4,
        edition: DmRulesEdition.v2014,
      );
      expect(l10.magicalSecretsCount, 2);
      expect(l10.allowedMagicalSecretClasses.length, greaterThanOrEqualTo(8));

      final l14 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 14,
        abilityModifier: 4,
        edition: DmRulesEdition.v2014,
      );
      expect(l14.magicalSecretsCount, 4);

      final l18 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 18,
        abilityModifier: 5,
        edition: DmRulesEdition.v2014,
      );
      expect(l18.magicalSecretsCount, 6);
    });

    test('Lore Bard Additional Magical Secrets at Level 6 (2014 vs 2024)', () {
      final lore2014 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        subclassSlug: 'college_of_lore',
        classLevel: 6,
        abilityModifier: 3,
        edition: DmRulesEdition.v2014,
      );
      expect(lore2014.magicalSecretsCount, 2);
      expect(lore2014.allowedMagicalSecretClasses.length, greaterThanOrEqualTo(8));

      final lore2024 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        subclassSlug: 'college_of_lore',
        classLevel: 6,
        abilityModifier: 3,
        edition: DmRulesEdition.v2024,
      );
      expect(lore2024.magicalSecretsCount, 2);
      expect(lore2024.allowedMagicalSecretClasses, containsAll([SpellClass.wizard, SpellClass.cleric, SpellClass.druid]));
    });

    test('Bard 2024 Level 10 Magical Secrets unlocks Cleric, Druid, and Wizard spell lists', () {
      final bard2024L10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 10,
        abilityModifier: 4,
        edition: DmRulesEdition.v2024,
      );
      expect(bard2024L10.allowedMagicalSecretClasses, containsAll([
        SpellClass.bard,
        SpellClass.cleric,
        SpellClass.druid,
        SpellClass.wizard,
      ]));
    });

    test('Warlock Mystic Arcanum milestones at levels 11, 13, 15, 17', () {
      final w10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 10,
        abilityModifier: 4,
      );
      expect(w10.mysticArcanumLevel, 0);

      final w11 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 11,
        abilityModifier: 4,
      );
      expect(w11.mysticArcanumLevel, 6);

      final w13 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 13,
        abilityModifier: 4,
      );
      expect(w13.mysticArcanumLevel, 7);

      final w15 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 15,
        abilityModifier: 4,
      );
      expect(w15.mysticArcanumLevel, 8);

      final w17 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 17,
        abilityModifier: 4,
      );
      expect(w17.mysticArcanumLevel, 9);
    });

    test('Cleric Life Domain always-prepared spells are exempt from maxSpellsPrepared validation', () {
      final limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'cleric',
        subclassSlug: 'life_domain',
        classLevel: 3,
        abilityModifier: 3,
      );
      // Level 3 + 3 WIS = 6 prepared spells quota
      expect(limits.maxSpellsPrepared, 6);
      // Life domain grants 4 spells at level 3 (Bless, Cure Wounds, Lesser Restoration, Spiritual Weapon)
      expect(limits.alwaysPreparedSubclassCount, 4);

      // Character prepares 6 regular spells + 4 domain spells = 10 total
      final regularPrepared = List.generate(
        6,
        (i) => EntityReference<Spell>(refType: EntityType.spell, slug: 'reg-spell-$i', displayName: 'Reg Spell $i'),
      );
      final domainSpells = [
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'bless', displayName: 'Bless'),
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'cure-wounds', displayName: 'Cure Wounds'),
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'lesser-restoration', displayName: 'Lesser Restoration'),
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'spiritual-weapon', displayName: 'Spiritual Weapon'),
      ];

      final result = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'cleric',
        targetClassLevel: 3,
        castingAbilityModifier: 3,
        subclassSlug: 'life_domain',
        cantrips: const [],
        spellsKnown: const [],
        spellsPrepared: [...regularPrepared, ...domainSpells],
        alwaysPreparedSpellIds: ['bless', 'cure-wounds', 'lesser-restoration', 'spiritual-weapon'],
        edition: DmRulesEdition.v2024,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });
}

