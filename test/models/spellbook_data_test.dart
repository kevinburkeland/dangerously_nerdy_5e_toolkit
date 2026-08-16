import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

void main() {
  group('SpellbookLibrary & SpellItem Data Model Tests', () {
    test('contains comprehensive spells across schools and levels', () {
      const spells = SpellbookLibrary.allSpells;
      expect(spells.isNotEmpty, isTrue);

      final schools = spells.map((s) => s.school).toSet();
      expect(schools.contains(SpellSchool.abjuration), isTrue);
      expect(schools.contains(SpellSchool.divination), isTrue);
      expect(schools.contains(SpellSchool.evocation), isTrue);
      expect(schools.contains(SpellSchool.transmutation), isTrue);
      expect(schools.contains(SpellSchool.conjuration), isTrue);

      final levels = spells.map((s) => s.level).toSet();
      expect(levels.contains(0), isTrue); // Cantrips
      expect(levels.contains(1), isTrue); // 1st level
      expect(levels.contains(3), isTrue); // 3rd level
      expect(levels.contains(9), isTrue); // 9th level
    });

    test('True Strike reflects 2014 advantage vs 2024 weapon attack radiant redesign', () {
      final trueStrike = SpellbookLibrary.getSpellById('spell_true_strike');
      expect(trueStrike, isNotNull);
      expect(trueStrike!.isChangedIn2024, isTrue);

      final r2014 = trueStrike.getRules(DmRulesEdition.v2014);
      final r2024 = trueStrike.getRules(DmRulesEdition.v2024);

      expect(r2014.concentration, isTrue);
      expect(r2014.duration.contains('Concentration'), isTrue);
      expect(r2014.description.any((d) => d.contains('advantage on your first attack roll')), isTrue);

      expect(r2024.concentration, isFalse);
      expect(r2024.damageOrHealType, 'Radiant');
      expect(r2024.description.any((d) => d.contains('Radiant damage')), isTrue);
      expect(r2024.description.any((d) => d.contains('spellcasting ability modifier instead of Strength')), isTrue);
    });

    test('Cure Wounds and Healing Word reflect 2024 dice doubling buff', () {
      final cureWounds = SpellbookLibrary.getSpellById('spell_cure_wounds')!;
      expect(cureWounds.getRules(DmRulesEdition.v2014).rollFormula, '1d8 + mod');
      expect(cureWounds.getRules(DmRulesEdition.v2024).rollFormula, '2d8 + mod');

      final healingWord = SpellbookLibrary.getSpellById('spell_healing_word')!;
      expect(healingWord.getRules(DmRulesEdition.v2014).rollFormula, '1d4 + mod');
      expect(healingWord.getRules(DmRulesEdition.v2024).rollFormula, '2d4 + mod');
    });

    test('Counterspell reflects 2014 ability check vs 2024 Constitution save', () {
      final counterspell = SpellbookLibrary.getSpellById('spell_counterspell')!;
      expect(counterspell.isChangedIn2024, isTrue);

      final r2014 = counterspell.getRules(DmRulesEdition.v2014);
      final r2024 = counterspell.getRules(DmRulesEdition.v2024);

      expect(r2014.description.any((d) => d.contains('DC equals 10 + the spell’s level')), isTrue);
      expect(r2024.savingThrow, 'Constitution');
      expect(r2024.description.any((d) => d.contains('Constitution saving throw')), isTrue);
    });

    test('Divine Smite reflects 2014 class feature vs 2024 Bonus Action spell', () {
      final smite = SpellbookLibrary.getSpellById('spell_divine_smite')!;
      expect(smite.isChangedIn2024, isTrue);

      final r2014 = smite.getRules(DmRulesEdition.v2014);
      final r2024 = smite.getRules(DmRulesEdition.v2024);

      expect(r2014.castingTime.contains('No Action'), isTrue);
      expect(r2024.castingTime.contains('Bonus Action'), isTrue);
      expect(r2024.components, 'V');
    });

    test('Spiritual Weapon reflects 2014 non-concentration vs 2024 concentration', () {
      final weapon = SpellbookLibrary.getSpellById('spell_spiritual_weapon')!;
      expect(weapon.getRules(DmRulesEdition.v2014).concentration, isFalse);
      expect(weapon.getRules(DmRulesEdition.v2024).concentration, isTrue);
    });

    test('SpellItem.matches filters correctly by query, level, school, and tags', () {
      final fireball = SpellbookLibrary.getSpellById('spell_fireball')!;

      expect(fireball.matches('fire'), isTrue);
      expect(fireball.matches('guano'), isTrue);
      expect(fireball.matches('8d6'), isTrue);
      expect(fireball.matches('cleric'), isFalse);
      expect(fireball.matches('fire', levelFilter: 3), isTrue);
      expect(fireball.matches('fire', levelFilter: 2), isFalse);
      expect(fireball.matches('fire', schoolFilter: SpellSchool.evocation), isTrue);
      expect(fireball.matches('fire', schoolFilter: SpellSchool.illusion), isFalse);
    });

    test('Helper query methods return expected collections', () {
      final changed = SpellbookLibrary.getChangedSpells();
      expect(changed.isNotEmpty, isTrue);
      expect(changed.every((s) => s.isChangedIn2024), isTrue);

      final cantrips = SpellbookLibrary.getSpellsByLevel(0);
      expect(cantrips.isNotEmpty, isTrue);
      expect(cantrips.every((s) => s.level == 0), isTrue);

      final wizardSpells = SpellbookLibrary.getSpellsByClass(SpellClass.wizard);
      expect(wizardSpells.any((s) => s.id == 'spell_fireball'), isTrue);
      expect(wizardSpells.any((s) => s.id == 'spell_wish'), isTrue);
    });

    test('Summon presets link directly to SpellbookLibrary source spells', () {
      final animateObjectsSpell = SpellbookLibrary.getSpellById('spell_animate_objects');
      expect(animateObjectsSpell, isNotNull);
      expect(animateObjectsSpell!.level, 5);
      expect(animateObjectsSpell.school, SpellSchool.transmutation);

      final conjureAnimalsSpell = SpellbookLibrary.getSpellById('spell_conjure_animals');
      expect(conjureAnimalsSpell, isNotNull);
      expect(conjureAnimalsSpell!.isChangedIn2024, isTrue);

      final animateDeadSpell = SpellbookLibrary.getSpellById('spell_animate_dead');
      expect(animateDeadSpell, isNotNull);
      expect(animateDeadSpell!.school, SpellSchool.necromancy);
    });

    test('Unified SpellSchool provides canonical styling tokens and icons', () {
      for (final school in SpellSchool.values) {
        expect(school.displayName.isNotEmpty, isTrue);
        expect(school.label, school.displayName);
        expect(school.color, isNotNull);
        expect(school.icon, isNotNull);
        expect(school.getLegibleColor(true), isNotNull);
        expect(school.getLegibleColor(false), isNotNull);
      }
    });

    test('Cleric spell list includes spells across all spell levels 0 through 9', () {
      final clericSpells2014 = SpellbookLibrary.getSpellsByClass(SpellClass.cleric, edition: DmRulesEdition.v2014);
      final clericSpells2024 = SpellbookLibrary.getSpellsByClass(SpellClass.cleric, edition: DmRulesEdition.v2024);

      expect(clericSpells2014.isNotEmpty, isTrue);
      expect(clericSpells2024.isNotEmpty, isTrue);

      for (int lvl = 0; lvl <= 9; lvl++) {
        expect(clericSpells2014.any((s) => s.level == lvl), isTrue, reason: 'Missing 2014 Cleric spell at level $lvl');
        expect(clericSpells2024.any((s) => s.level == lvl), isTrue, reason: 'Missing 2024 Cleric spell at level $lvl');
      }

      // Check iconic high-level cleric spells
      expect(SpellbookLibrary.getSpellById('spell_harm'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_heroes_feast'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_divine_word'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_fire_storm'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_regenerate'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_resurrection'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_holy_aura'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_earthquake'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_mass_heal'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_true_resurrection'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_gate'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_astral_projection'), isNotNull);
    });
  });
}

