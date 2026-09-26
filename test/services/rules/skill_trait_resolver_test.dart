import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';

void main() {
  group('SkillTraitResolver RAW Tests', () {
    test(
        'Skill collision detection: Acolyte Cleric overlaps Insight and Religion',
        () {
      final report = SkillTraitResolver.resolveSkills(
        speciesSlug: 'human',
        backgroundSlug: 'acolyte', // grants Insight & Religion
        classSlug: 'cleric',
        requestedClassSkills: {
          SkillType.insight,
          SkillType.religion
        }, // collisions!
        compensatoryPicks: {SkillType.perception, SkillType.history},
        edition: DmRulesEdition.v2024,
      );

      expect(report.collidingSkills, contains(SkillType.insight));
      expect(report.collidingSkills, contains(SkillType.religion));
      expect(report.compensatoryPicksEarned, 2);
      expect(
          report.resolvedProficiencies.containsKey(SkillType.insight), isTrue);
      expect(
          report.resolvedProficiencies.containsKey(SkillType.religion), isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.perception),
          isTrue);
      expect(
          report.resolvedProficiencies.containsKey(SkillType.history), isTrue);
    });

    test(
        'Species fixed skill: Elf gains Perception and detects collision with Sailor background',
        () {
      final report = SkillTraitResolver.resolveSkills(
        speciesSlug: 'elf', // grants Perception
        backgroundSlug:
            'sailor', // grants Athletics and Perception -> collision!
        classSlug: 'rogue',
        requestedClassSkills: {SkillType.stealth, SkillType.acrobatics},
        compensatoryPicks: {SkillType.investigation},
        edition: DmRulesEdition.v2024,
      );

      expect(report.collidingSkills, contains(SkillType.perception));
      expect(report.compensatoryPicksEarned, 1);
      expect(report.resolvedProficiencies.containsKey(SkillType.perception),
          isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.investigation),
          isTrue);
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

    test('Species physical traits propagation (Speed, Darkvision, HP bonus)',
        () {
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

    test('Subrace skill grant and collision detection with background', () {
      // Register custom subrace that grants Stealth
      final testSubrace = Subrace(
        id: const EntityId(
            slug: 'shadow-elf', ruleset: RulesetVersion.homebrew),
        name: 'Shadow Elf',
        raceSlug: 'elf',
        traitsMarkdown: 'Born in shadow.',
        abilityScoreSummary: '+1 CHA',
        fixedAbilityBonuses: const {'charisma': 1},
        grants: [
          FeatureGrant.skillProficiency('stealth',
              grantId: 'shadow-elf-stealth'),
        ],
        speed: '35 ft.',
        darkvision: 120,
      );
      SrdSpeciesLibrary.addCustomSubrace(testSubrace);

      // Urchin background grants Sleight of Hand and Stealth -> collision on Stealth!
      final report = SkillTraitResolver.resolveSkills(
        speciesSlug: 'elf',
        subraceSlug: 'shadow-elf',
        backgroundSlug: 'urchin',
        classSlug: 'fighter',
        requestedClassSkills: {SkillType.athletics, SkillType.survival},
        compensatoryPicks: {SkillType.acrobatics},
      );

      expect(report.collidingSkills, contains(SkillType.stealth));
      expect(report.compensatoryPicksEarned, 1);
      expect(
          report.resolvedProficiencies.containsKey(SkillType.stealth), isTrue);
      expect(report.resolvedProficiencies.containsKey(SkillType.perception),
          isTrue); // from Elf
      expect(report.resolvedProficiencies.containsKey(SkillType.acrobatics),
          isTrue); // compensatory

      // Check speed and darkvision resolution from custom subrace
      final traits = SkillTraitResolver.getSpeciesTraits(
        speciesSlug: 'elf',
        subraceSlug: 'shadow-elf',
      );
      expect(traits.baseSpeedFeet, 35);
      expect(traits.darkvisionFeet, 120);

      // Cleanup
      SrdSpeciesLibrary.removeCustomSubrace('shadow-elf');
    });

    test('Subrace dynamic innate spells resolution', () {
      final magicSubrace = Subrace(
        id: const EntityId(
            slug: 'mystic-elf', ruleset: RulesetVersion.homebrew),
        name: 'Mystic Elf',
        raceSlug: 'elf',
        traitsMarkdown: 'Mystic lore.',
        grants: [
          FeatureGrant.bonusSpell(
            grantId: 'mystic-spell-guidance',
            slug: 'guidance',
            displayName: 'Guidance',
          ),
        ],
        customProperties: {
          'additionalSpells': [
            {
              'innate': {
                '1': ['shield#c'],
                '3': ['misty-step'],
              },
            },
          ],
        },
      );
      SrdSpeciesLibrary.addCustomSubrace(magicSubrace);

      final lvl1 = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'elf',
        subraceSlug: 'mystic-elf',
        totalCharacterLevel: 1,
      );
      expect(lvl1.any((s) => s.spellRef.slug == 'guidance'), isTrue);
      expect(lvl1.any((s) => s.spellRef.slug == 'shield'), isTrue);

      final lvl3 = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'elf',
        subraceSlug: 'mystic-elf',
        totalCharacterLevel: 3,
      );
      expect(lvl3.any((s) => s.spellRef.slug == 'misty-step'), isTrue);

      // Cleanup
      SrdSpeciesLibrary.removeCustomSubrace('mystic-elf');
    });
  });
}
