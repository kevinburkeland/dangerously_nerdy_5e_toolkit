import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_skills_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';

void main() {
  group('SRD Character Libraries Tests', () {
    test('SrdFeatsLibrary contains expected 2014 and 2024 feats', () {
      final allFeats = SrdFeatsLibrary.allFeats;
      expect(allFeats.length, greaterThanOrEqualTo(15));

      final originFeats = SrdFeatsLibrary.getOriginFeats();
      expect(originFeats.length, greaterThanOrEqualTo(10));
      expect(originFeats.any((f) => f.name == 'Alert'), isTrue);
      expect(originFeats.any((f) => f.name == 'Savage Attacker'), isTrue);
      expect(originFeats.any((f) => f.name == 'Tough'), isTrue);
      expect(originFeats.any((f) => f.name == 'Magic Initiate'), isTrue);

      final generalFeats = SrdFeatsLibrary.getGeneralFeats();
      expect(generalFeats.any((f) => f.name == 'Great Weapon Master'), isTrue);
      expect(generalFeats.any((f) => f.name == 'War Caster'), isTrue);
      expect(generalFeats.any((f) => f.name == 'Sentinel'), isTrue);

      final findBySlug = SrdFeatsLibrary.findBySlug('savage-attacker');
      expect(findBySlug, isNotNull);
      expect(findBySlug!.name, 'Savage Attacker');
    });

    test('SrdSkillsLibrary contains all 18 standard 5e skills with abilities', () {
      const allSkills = SrdSkillsLibrary.allSkills;
      expect(allSkills.length, 18);

      final ath = SrdSkillsLibrary.getDefinition(SkillType.athletics);
      expect(ath.name, 'Athletics');
      expect(ath.defaultAbility, AbilityType.strength);

      final perc = SrdSkillsLibrary.getDefinition(SkillType.perception);
      expect(perc.name, 'Perception');
      expect(perc.defaultAbility, AbilityType.wisdom);

      final stl = SrdSkillsLibrary.getDefinition(SkillType.stealth);
      expect(stl.name, 'Stealth');
      expect(stl.defaultAbility, AbilityType.dexterity);

      final dexSkills = SrdSkillsLibrary.getByAbility(AbilityType.dexterity);
      expect(dexSkills.length, 3); // Acrobatics, Sleight of Hand, Stealth
    });

    test('SrdClassesLibrary contains all 12 SRD classes with valid progression rules', () {
      final classes = SrdClassesLibrary.allClasses;
      expect(classes.length, 12);

      final fighter = SrdClassesLibrary.findBySlug('fighter');
      expect(fighter, isNotNull);
      expect(fighter!.hitDie, 'd10');
      expect(fighter.savingThrows, containsAll(['Strength', 'Constitution']));
      expect(fighter.armorProficiencies, contains('All Armor'));

      final wizard = SrdClassesLibrary.findBySlug('wizard');
      expect(wizard, isNotNull);
      expect(wizard!.hitDie, 'd6');
      expect(wizard.savingThrows, containsAll(['Intelligence', 'Wisdom']));
      expect(wizard.spellcastingAbility, 'Intelligence');

      final rogue = SrdClassesLibrary.findBySlug('rogue');
      expect(rogue, isNotNull);
      expect(rogue!.hitDie, 'd8');
      expect(rogue.savingThrows, containsAll(['Dexterity', 'Intelligence']));
    });

    test('SrdSpeciesLibrary contains core SRD species with traits', () {
      final species = SrdSpeciesLibrary.allSpecies;
      expect(species.length, greaterThanOrEqualTo(9));

      final human = SrdSpeciesLibrary.findBySlug('human');
      expect(human, isNotNull);
      expect(human!.speed, '30 ft.');

      final elf = SrdSpeciesLibrary.findBySlug('elf');
      expect(elf, isNotNull);
      expect(elf!.customProperties['hasDarkvision'], isTrue);
      expect(elf.subraces.length, greaterThanOrEqualTo(2));

      final dwarf = SrdSpeciesLibrary.findBySlug('dwarf');
      expect(dwarf, isNotNull);
      expect(dwarf!.customProperties['poisonResistance'], isTrue);
    });

    test('SrdBackgroundsLibrary contains background options with skill grants', () {
      final bgs = SrdBackgroundsLibrary.allBackgrounds;
      expect(bgs.length, greaterThanOrEqualTo(10));

      final soldier = SrdBackgroundsLibrary.findBySlug('soldier');
      expect(soldier, isNotNull);
      expect(soldier!.skillProficiencies, containsAll(['Athletics', 'Intimidation']));

      final acolyte = SrdBackgroundsLibrary.findBySlug('acolyte');
      expect(acolyte, isNotNull);
      expect(acolyte!.skillProficiencies, containsAll(['Insight', 'Religion']));

      final criminal = SrdBackgroundsLibrary.findBySlug('criminal');
      expect(criminal, isNotNull);
      expect(criminal!.skillProficiencies, containsAll(['Deception', 'Stealth']));
    });
  });
}
