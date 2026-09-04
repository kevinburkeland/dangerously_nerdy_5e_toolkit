import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_builder_controller.dart';

void main() {
  group('CharacterDraft Model Tests', () {
    test('Empty initial draft has null properties and invalid flags', () {
      final draft = CharacterDraft();

      expect(draft.characterName, isNull);
      expect(draft.rulesEdition, equals(DmRulesEdition.v2024));
      expect(draft.speciesRef, isNull);
      expect(draft.backgroundRef, isNull);
      expect(draft.startingClassRef, isNull);
      expect(draft.startingClassHitDie, isNull);
      expect(draft.baseScores, isNull);
      expect(draft.selectedSkills, isEmpty);

      expect(draft.hasValidSpecies, isFalse);
      expect(draft.hasValidClass, isFalse);
      expect(draft.hasValidBackground, isFalse);
      expect(draft.hasValidScores, isFalse);
      expect(draft.isReadyForCompilation, isFalse);
    });

    test('Out-of-order population correctly updates granular validation getters', () {
      final draft = CharacterDraft();

      // Step: Assign scores first (Attributes First preset)
      draft.baseScores = const AbilityScores(
        strength: 15,
        dexterity: 14,
        constitution: 13,
        intelligence: 12,
        wisdom: 10,
        charisma: 8,
      );
      expect(draft.hasValidScores, isTrue);
      expect(draft.hasValidClass, isFalse);
      expect(draft.hasValidSpecies, isFalse);
      expect(draft.hasValidBackground, isFalse);
      expect(draft.isReadyForCompilation, isFalse);

      // Step: Assign class second
      draft.startingClassRef = const EntityReference(
        refType: EntityType.classDefinition,
        slug: 'fighter',
        displayName: 'Fighter',
      );
      draft.startingClassHitDie = 'd10';
      expect(draft.hasValidClass, isTrue);
      expect(draft.isReadyForCompilation, isFalse);

      // Step: Assign species third
      draft.speciesRef = const EntityReference(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      );
      expect(draft.hasValidSpecies, isTrue);
      expect(draft.isReadyForCompilation, isFalse);

      // Step: Assign background fourth
      draft.backgroundRef = const EntityReference(
        refType: EntityType.background,
        slug: 'soldier',
        displayName: 'Soldier',
      );
      expect(draft.hasValidBackground, isTrue);
      expect(draft.isReadyForCompilation, isFalse); // Name still empty

      // Step: Assign name
      draft.characterName = 'Valen';
      expect(draft.isReadyForCompilation, isTrue);
    });
  });

  group('CharacterFactory.buildFromDraft Tests', () {
    test('Throws StateError if draft is incomplete with descriptive message', () {
      final draft = CharacterDraft();
      expect(
        () => CharacterFactory.buildFromDraft(draft),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Species, Class, Background, Base Scores, Character Name'),
          ),
        ),
      );

      // Partially filled
      draft.speciesRef = const EntityReference(
        refType: EntityType.species,
        slug: 'elf',
        displayName: 'Elf',
      );
      expect(
        () => CharacterFactory.buildFromDraft(draft),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            isNot(contains('Species')),
          ),
        ),
      );
    });

    test('Compiles complete draft into valid Character domain entity', () {
      final draft = CharacterDraft()
        ..characterName = 'Gildor Inglorion'
        ..rulesEdition = DmRulesEdition.v2024
        ..speciesRef = const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        )
        ..backgroundRef = const EntityReference(
          refType: EntityType.background,
          slug: 'sage',
          displayName: 'Sage',
        )
        ..startingClassRef = const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'wizard',
          displayName: 'Wizard',
        )
        ..startingClassHitDie = 'd6'
        ..baseScores = const AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 13,
          intelligence: 15,
          wisdom: 12,
          charisma: 10,
        )
        ..bonusScores = const AbilityScores(
          intelligence: 2,
          constitution: 1,
        )
        ..savingThrowProficiencies = {AbilityType.intelligence, AbilityType.wisdom}
        ..selectedSkills = {
          SkillType.arcana: SkillProficiencyLevel.proficient,
          SkillType.history: SkillProficiencyLevel.proficient,
        };

      final character = CharacterFactory.buildFromDraft(draft);

      expect(character.name, equals('Gildor Inglorion'));
      expect(character.speciesRef.slug, equals('elf'));
      expect(character.backgroundRef?.slug, equals('sage'));
      expect(character.baseScores.intelligence, equals(15));
      expect(character.bonusScores.intelligence, equals(2));
      expect(character.progression.classes.length, equals(1));
      expect(character.progression.classes.first.classRef.slug, equals('wizard'));
      expect(character.progression.classes.first.level, equals(1));
      expect(character.progression.classes.first.hitDie, equals('d6'));
      expect(character.skillProficiencies[SkillType.arcana], equals(SkillProficiencyLevel.proficient));
      expect(character.savingThrowProficiencies, contains(AbilityType.intelligence));
      expect(character.savingThrowProficiencies, contains(AbilityType.wisdom));
      expect(character.resources.currentHp, greaterThan(0));
    });
  });

  group('CharacterBuilderController Draft Encapsulation Tests', () {
    test('Controller initial draft is clean and mutators update state', () {
      final controller = CharacterBuilderController();

      expect(controller.draft.speciesRef, isNull);
      expect(controller.draft.startingClassRef, isNull);
      expect(controller.draft.backgroundRef, isNull);
      expect(controller.draft.characterName, isNull);

      const elfRef = EntityReference(
        refType: EntityType.species,
        slug: 'elf',
        displayName: 'Elf',
      );
      const wizardRef = EntityReference(
        refType: EntityType.classDefinition,
        slug: 'wizard',
        displayName: 'Wizard',
      );
      const sageRef = EntityReference(
        refType: EntityType.background,
        slug: 'sage',
        displayName: 'Sage',
      );

      controller.setName('Eldrin');
      controller.setSpecies(elfRef);
      controller.setClass(wizardRef, hitDie: 'd6');
      controller.setBackground(sageRef);

      expect(controller.hasValidSpecies, isTrue);
      expect(controller.hasValidClass, isTrue);
      expect(controller.hasValidBackground, isTrue);
      expect(controller.draft.characterName, equals('Eldrin'));
      expect(controller.draft.speciesRef?.slug, equals('elf'));
      expect(controller.draft.startingClassRef?.slug, equals('wizard'));
      expect(controller.draft.backgroundRef?.slug, equals('sage'));
    });
  });
}
