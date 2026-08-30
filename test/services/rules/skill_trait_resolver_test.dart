import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';

void main() {
  group('SkillTraitResolver RAW Tests', () {
    test('Skill collision detection: Soldier Fighter overlaps Athletics and Intimidation', () {
      final report = SkillTraitResolver.resolveSkills(
        speciesSlug: 'human',
        backgroundSlug: 'soldier', // grants Athletics & Intimidation
        classSlug: 'fighter',
        requestedClassSkills: {SkillType.athletics, SkillType.intimidation}, // collisions!
        compensatoryPicks: {SkillType.perception, SkillType.survival},
        edition: DmRulesEdition.v2024,
      );

      expect(report.collidingSkills, contains(SkillType.athletics));
      expect(report.collidingSkills, contains(SkillType.intimidation));
      expect(report.compensatoryPicksEarned, 2);
      expect(report.resolvedProficiencies.containsKey(SkillType.athletics), isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.intimidation), isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.perception), isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.survival), isTrue);
    });

    test('Species fixed skill: Elf gains Perception and detects collision with Sailor background', () {
      final report = SkillTraitResolver.resolveSkills(
        speciesSlug: 'elf', // grants Perception
        backgroundSlug: 'sailor', // grants Athletics and Perception -> collision!
        classSlug: 'rogue',
        requestedClassSkills: {SkillType.stealth, SkillType.acrobatics},
        compensatoryPicks: {SkillType.investigation},
        edition: DmRulesEdition.v2024,
      );

      expect(report.collidingSkills, contains(SkillType.perception));
      expect(report.compensatoryPicksEarned, 1);
      expect(report.resolvedProficiencies.containsKey(SkillType.perception), isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.investigation), isTrue);
    });

    test('Tiefling native innate spell progression scales with level', () {
      final lvl1Spells = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'tiefling',
        subraceSlug: null,
        totalCharacterLevel: 1,
      );
      expect(lvl1Spells.length, 1);
      expect(lvl1Spells[0].spellRef.slug, 'thaumaturgy');

      final lvl3Spells = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'tiefling',
        subraceSlug: null,
        totalCharacterLevel: 3,
      );
      expect(lvl3Spells.length, 2);
      expect(lvl3Spells[1].spellRef.slug, 'hellish-rebuke');

      final lvl5Spells = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'tiefling',
        subraceSlug: null,
        totalCharacterLevel: 5,
      );
      expect(lvl5Spells.length, 3);
      expect(lvl5Spells[2].spellRef.slug, 'darkness');
    });

    test('Species physical traits propagation (Speed, Darkvision, HP bonus)', () {
      final woodElf = SkillTraitResolver.getSpeciesTraits(
        speciesSlug: 'elf',
        subraceSlug: 'wood-elf',
      );
      expect(woodElf.baseSpeedFeet, 35);
      expect(woodElf.darkvisionFeet, 60);

      final drow = SkillTraitResolver.getSpeciesTraits(
        speciesSlug: 'elf',
        subraceSlug: 'drow',
      );
      expect(drow.darkvisionFeet, 120);

      final hillDwarf = SkillTraitResolver.getSpeciesTraits(
        speciesSlug: 'dwarf',
        subraceSlug: 'hill-dwarf',
      );
      expect(hillDwarf.hpPerLevelBonus, 1);
    });
  });
}
