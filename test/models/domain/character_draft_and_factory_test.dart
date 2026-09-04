import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

void main() {
  group('CharacterDraft Model & Validation Tests', () {
    test('Draft initializes with clean null references and empty collections', () {
      final draft = CharacterDraft();

      expect(draft.characterName, isNull);
      expect(draft.speciesRef, isNull);
      expect(draft.startingClassRef, isNull);
      expect(draft.backgroundRef, isNull);
      expect(draft.baseScores, isNull);
      expect(draft.bonusScores, equals(const AbilityScores.zero()));
      expect(draft.rulesEdition, equals(DmRulesEdition.v2024));
      expect(draft.selectedSkills, isEmpty);
      expect(draft.cantrips, isEmpty);
      expect(draft.spellsKnown, isEmpty);
      expect(draft.spellsPrepared, isEmpty);

      // Validation flags
      expect(draft.hasValidSpecies, isFalse);
      expect(draft.hasValidClass, isFalse);
      expect(draft.hasValidBackground, isFalse);
      expect(draft.hasValidScores, isFalse);
      expect(draft.isReadyForCompilation, isFalse);
    });

    test('Draft accepts mutations in arbitrary out-of-order sequence', () {
      final draft = CharacterDraft();

      // Step 1: Assign Class first (Modern 2024 order)
      draft.startingClassRef = const EntityReference(
        refType: EntityType.classDefinition,
        slug: 'fighter',
        displayName: 'Fighter',
      );
      draft.startingClassHitDie = 'd10';
      expect(draft.hasValidClass, isTrue);
      expect(draft.hasValidSpecies, isFalse);
      expect(draft.isReadyForCompilation, isFalse);

      // Step 2: Assign Background second
      draft.backgroundRef = const EntityReference(
        refType: EntityType.background,
        slug: 'soldier',
        displayName: 'Soldier',
      );
      expect(draft.hasValidBackground, isTrue);
      expect(draft.isReadyForCompilation, isFalse);

      // Step 3: Assign Species third
      draft.speciesRef = const EntityReference(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      );
      expect(draft.hasValidSpecies, isTrue);
      expect(draft.isReadyForCompilation, isFalse);

      // Step 4: Assign Ability Scores fourth
      draft.baseScores = const AbilityScores(
        strength: 15,
        dexterity: 13,
        constitution: 14,
        intelligence: 10,
        wisdom: 12,
        charisma: 8,
      );
      expect(draft.hasValidScores, isTrue);
      expect(draft.isReadyForCompilation, isFalse); // Still missing name

      // Step 5: Assign Character Name
      draft.characterName = 'Thorin Ironshield';
      expect(draft.isReadyForCompilation, isTrue);
    });

    test('isReadyForCompilation requires non-empty name string', () {
      final draft = CharacterDraft(
        characterName: '   ',
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'wizard',
          displayName: 'Wizard',
        ),
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'sage',
          displayName: 'Sage',
        ),
        baseScores: const AbilityScores(),
      );

      expect(draft.hasValidSpecies, isTrue);
      expect(draft.hasValidClass, isTrue);
      expect(draft.hasValidBackground, isTrue);
      expect(draft.hasValidScores, isTrue);
      expect(draft.isReadyForCompilation, isFalse);

      draft.characterName = 'Eldrin';
      expect(draft.isReadyForCompilation, isTrue);
    });
  });

  group('CharacterFactory.buildFromDraft Tests', () {
    test('buildFromDraft throws StateError with informative message on incomplete draft', () {
      final incompleteDraft = CharacterDraft(
        characterName: 'Incomplete Hero',
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        // missing class, background, scores
      );

      expect(
        () => CharacterFactory.buildFromDraft(incompleteDraft),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Missing mandatory field(s): Class, Background, Base Scores'),
        )),
      );
    });

    test('buildFromDraft compiles complete draft into valid Character entity', () {
      final draft = CharacterDraft(
        characterName: 'Valeros',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'fighter',
          displayName: 'Fighter',
        ),
        startingClassHitDie: 'd10',
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'soldier',
          displayName: 'Soldier',
        ),
        baseScores: const AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 13,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        bonusScores: const AbilityScores(
          strength: 2,
          constitution: 1,
          dexterity: 0,
          intelligence: 0,
          wisdom: 0,
          charisma: 0,
        ),
        selectedSkills: {
          SkillType.athletics: SkillProficiencyLevel.proficient,
          SkillType.intimidation: SkillProficiencyLevel.proficient,
        },
        savingThrowProficiencies: {
          AbilityType.strength,
          AbilityType.constitution,
        },
        languages: const ['Common', 'Orc'],
        originFeats: [
          const EntityReference(
            refType: EntityType.feat,
            slug: 'alert',
            displayName: 'Alert',
          ),
        ],
      );

      final character = CharacterFactory.buildFromDraft(draft);

      expect(character.name, equals('Valeros'));
      expect(character.rulesEdition, equals(DmRulesEdition.v2024));
      expect(character.speciesRef.slug, equals('human'));
      expect(character.backgroundRef?.slug, equals('soldier'));
      expect(character.progression.classes.length, equals(1));
      expect(character.progression.classes.first.classRef.slug, equals('fighter'));
      expect(character.progression.classes.first.level, equals(1));

      // Ability Scores: base + bonus
      expect(character.rawAbilityScores.strength, equals(17)); // 15 + 2
      expect(character.rawAbilityScores.constitution, equals(14)); // 13 + 1
      expect(character.rawAbilityScores.dexterity, equals(14));

      // Level 1 Fighter HP: d10 (10) + CON mod (+2) = 12
      expect(character.resources.currentHp, equals(12));

      // Proficiencies & Features
      expect(character.skillProficiencies[SkillType.athletics], equals(SkillProficiencyLevel.proficient));
      expect(character.savingThrowProficiencies, contains(AbilityType.strength));
      expect(character.feats.length, equals(1));
      expect(character.feats.first.slug, equals('alert'));
      expect(character.languages, contains('Orc'));
    });

    test('buildFromDraft populates spellcasting fields for casters', () {
      final draft = CharacterDraft(
        characterName: 'Malygos',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'wizard',
          displayName: 'Wizard',
        ),
        startingClassHitDie: 'd6',
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'sage',
          displayName: 'Sage',
        ),
        baseScores: const AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 14,
          intelligence: 15,
          wisdom: 12,
          charisma: 10,
        ),
        bonusScores: const AbilityScores(
          intelligence: 2,
          constitution: 1,
          strength: 0,
          dexterity: 0,
          wisdom: 0,
          charisma: 0,
        ),
        cantrips: [
          const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'fire-bolt',
            displayName: 'Fire Bolt',
          ),
          const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'mage-hand',
            displayName: 'Mage Hand',
          ),
          const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'light',
            displayName: 'Light',
          ),
        ],
        spellsKnown: [
          const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'magic-missile',
            displayName: 'Magic Missile',
          ),
          const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'shield',
            displayName: 'Shield',
          ),
        ],
      );

      final character = CharacterFactory.buildFromDraft(draft);

      expect(character.cantrips.length, equals(3));
      expect(character.cantrips.map((c) => c.slug), containsAll(['fire-bolt', 'mage-hand', 'light']));
      expect(character.spellsKnown.length, equals(2));
      expect(character.spellsKnown.map((s) => s.slug), containsAll(['magic-missile', 'shield']));
      // Wizard level 1 has 2 1st-level spell slots
      expect(character.resources.spellSlots.maxSlots[1], equals(2));
    });
  });
}
