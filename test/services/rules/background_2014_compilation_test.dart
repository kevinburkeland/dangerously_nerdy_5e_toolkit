import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart'
    show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

void main() {
  group('2014 Background Skills, Features, and Equipment Compilation Suite',
      () {
    test(
        'SrdBackgroundsLibrary helpers extract canonical 2014 starting equipment and features',
        () {
      final equipment =
          SrdBackgroundsLibrary.extractStartingEquipment('acolyte');
      expect(equipment, isNotEmpty);
      expect(equipment, contains('Holy Symbol'));
      expect(equipment, contains('Prayer Book'));
      expect(equipment, contains('Vestments'));

      final feature = SrdBackgroundsLibrary.get2014Feature('acolyte');
      expect(feature, isNotNull);
      expect(feature!.name, equals('Shelter of the Faithful'));
      expect(
          feature.description, contains('free healing and care at a temple'));

      final hydratedBg = SrdBackgroundsLibrary.findBySlug('acolyte');
      expect(hydratedBg, isNotNull);
      expect(
          hydratedBg!.skillProficiencies, containsAll(['Insight', 'Religion']));
      expect(hydratedBg.customProperties['feature'],
          equals('Shelter of the Faithful'));
      expect(hydratedBg.customProperties['startingEquipment'],
          contains('Holy Symbol'));
    });

    test(
        'Compiling a 2014 character draft with Acolyte background grants skills, equipment, and Shelter of the Faithful feature with 0 background ASIs',
        () {
      final draft = CharacterDraft(
        characterName: 'Father Bryan',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
          customProperties: {
            'fixedAbilityBonuses': {'str': 1, 'wis': 1},
          },
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'cleric',
          displayName: 'Cleric',
        ),
        startingClassHitDie: 'd8',
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        baseScores: const AbilityScores(
          strength: 14,
          dexterity: 10,
          constitution: 13,
          intelligence: 10,
          wisdom: 15,
          charisma: 12,
        ),
        selectedSkills: {
          SkillType.medicine: SkillProficiencyLevel.proficient,
        },
      );

      // Reconcile draft
      draft.reconcile();

      // Ensure 2014 background ASIs are strictly zero
      expect(draft.backgroundBonusScores, equals(const AbilityScores.zero()));
      expect(draft.speciesBonusScores.strength, equals(1));
      expect(draft.speciesBonusScores.wisdom, equals(1));
      expect(draft.bonusScores.strength, equals(1));
      expect(draft.bonusScores.wisdom, equals(1));

      // Compile into domain Character entity
      final character = CharacterFactory.buildFromDraft(draft);

      // 1. Skill Proficiencies: Selected class skill (Medicine) + Background skills (Insight, Religion)
      expect(character.skillProficiencies[SkillType.medicine],
          equals(SkillProficiencyLevel.proficient));
      expect(character.skillProficiencies[SkillType.insight],
          equals(SkillProficiencyLevel.proficient));
      expect(character.skillProficiencies[SkillType.religion],
          equals(SkillProficiencyLevel.proficient));

      // 2. 2014 Starting Equipment: Instantiated in character.inventory
      final itemNames =
          character.inventory.map((i) => i.itemRef.displayName).toList();
      expect(itemNames, contains('Holy Symbol'));
      expect(itemNames, contains('Prayer Book'));
      expect(itemNames, contains('Vestments'));
      expect(itemNames, contains('Common Clothes'));
      expect(itemNames, contains('Pouch'));

      // 3. 2014 Background Feature: Shelter of the Faithful
      expect(character.customProperties['backgroundFeature'],
          equals('Shelter of the Faithful'));
      expect(character.customProperties['backgroundFeatureDescription'],
          contains('free healing and care at a temple'));
      expect(character.feats, isEmpty);

      // 4. Ability Scores: only species bonuses applied (+1 STR, +1 WIS)
      expect(character.bonusScores.strength, equals(1));
      expect(character.bonusScores.wisdom, equals(1));
      expect(character.bonusScores.constitution, equals(0));
      expect(character.baseScores.strength, equals(14));
      expect(character.baseScores.wisdom, equals(15));
    });

    test(
        'Compiling a 2014 character draft with arbitrary homebrew background dynamically grants skills and discovers narrative feature',
        () {
      const customBg = Background(
        id: EntityId(slug: 'custom-deepdelver', ruleset: RulesetVersion.v2014),
        name: 'Custom Deepdelver',
        skillProficiencies: ['Athletics', 'Perception'],
        descriptionMarkdown: 'You spent years exploring subterranean ruins.\n\n'
            '**Feature: Subterranean Intuition**\n'
            'You have an uncanny sense of depth and stone stability while underground.\n\n'
            '**Starting Equipment:** Miner\'s Pick, 50 feet of Hemp Rope, Common Clothes, Pouch with 10 GP',
        customProperties: {
          'backgroundFeature': 'Subterranean Intuition',
          'backgroundFeatureDescription':
              'You have an uncanny sense of depth and stone stability while underground.',
        },
      );

      SrdBackgroundsLibrary.addCustomBackground(customBg);
      addTearDown(() =>
          SrdBackgroundsLibrary.removeCustomBackground('custom-deepdelver'));

      final draft = CharacterDraft(
        characterName: 'Brogur Stonebreaker',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'fighter',
          displayName: 'Fighter',
        ),
        startingClassHitDie: 'd10',
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'custom-deepdelver',
          displayName: 'Custom Deepdelver',
          customProperties: {
            'skillProficiencies': ['Athletics', 'Perception'],
            'backgroundFeature': 'Subterranean Intuition',
            'backgroundFeatureDescription':
                'You have an uncanny sense of depth and stone stability while underground.',
          },
        ),
        baseScores: const AbilityScores(strength: 16),
        selectedSkills: {
          SkillType.intimidation: SkillProficiencyLevel.proficient,
        },
      );

      final character = CharacterFactory.buildFromDraft(draft);

      // Skills: Class skill (Intimidation) + Arbitrary background skills (Athletics, Perception)
      expect(character.skillProficiencies[SkillType.intimidation],
          equals(SkillProficiencyLevel.proficient));
      expect(character.skillProficiencies[SkillType.athletics],
          equals(SkillProficiencyLevel.proficient));
      expect(character.skillProficiencies[SkillType.perception],
          equals(SkillProficiencyLevel.proficient));

      // Dynamic Feature extraction
      expect(character.customProperties['backgroundFeature'],
          equals('Subterranean Intuition'));
      expect(character.customProperties['backgroundFeatureDescription'],
          contains('uncanny sense of depth'));
    });
  });
}
