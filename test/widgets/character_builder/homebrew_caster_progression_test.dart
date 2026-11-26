import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up/level_up_wizard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/steps/builder_step_order.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_doubles/hive_test_harness.dart';

void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    await hive.setUpInMemory();
    SrdClassesLibrary.setCustomClasses(const []);
  });

  tearDown(() async {
    SrdClassesLibrary.setCustomClasses(const []);
    await hive.tearDown();
  });

  group('Fix 3.2: Homebrew caster classes use their own ability and progression', () {
    test(
      'imported homebrew Intelligence full caster gets builder spells step with INT and level 4->5 offers 3rd-level spells',
      () async {
        final parser = CompendiumClassParser();
        final hbClass = parser.parseClass(
          <String, dynamic>{
            'name': 'Chronomancer',
            'source': 'HB',
            'hd': {'faces': 6},
            'spellcastingAbility': 'int',
            'casterProgression': 'full',
          },
          forceRuleset: RulesetVersion.v2024,
        );

        await HomebrewPersistenceService().saveCustomClass(hbClass);

        // 1. Builder path: step order includes 'spells' and casting ability is Intelligence
        final steps = computeWizardStepTypes(
          selectedSpecies: 'human',
          selectedClass: hbClass.id.slug,
          selectedRuleset: RulesetVersion.v2024,
          preset: WizardOrderingPreset.classic2014,
        );
        expect(
          steps,
          contains('spells'),
          reason:
              'Homebrew Intelligence full caster "${hbClass.id.slug}" must show a spells step in builder',
        );

        final builderProfile = resolveBuilderCasterProfile(
          hbClass.id.slug,
          RulesetVersion.v2024,
        );
        expect(builderProfile.isSpellcaster, isTrue);
        expect(builderProfile.castingAbility, equals(AbilityType.intelligence));

        // 2. Level-up wizard path at level 4 -> 5: offers 3rd-level spells
        final lvl4Hero = Character(
          id: const EntityId(
            slug: 'hb-chrono-hero',
            ruleset: RulesetVersion.v2024,
          ),
          name: 'Talia',
          speciesRef: const EntityReference.empty(
            refType: EntityType.species,
            slug: 'human',
            displayName: 'Human',
          ),
          baseScores: const AbilityScores(
            strength: 8,
            dexterity: 12,
            constitution: 14,
            intelligence: 16,
            wisdom: 10,
            charisma: 10,
          ),
          progression: CharacterProgression(
            classes: [
              ClassLevelProgression(
                classRef: EntityReference.empty(
                  refType: EntityType.classDefinition,
                  slug: hbClass.id.slug,
                  displayName: hbClass.name,
                ),
                level: 4,
                hitDie: 'd6',
                isStartingClass: true,
              ),
            ],
          ),
        );

        final ctrl = LevelUpWizardController(character: lvl4Hero);
        expect(ctrl.targetClassNewLevel, equals(5));
        expect(
          ctrl.isSpellcaster,
          isTrue,
          reason: 'Level 4->5 homebrew full caster must be recognized as spellcaster',
        );
        expect(
          ctrl.maxAccessibleSpellLevel,
          equals(3),
          reason: 'Level 4->5 homebrew full caster must offer 3rd-level spells',
        );
        expect(
          ctrl.casterProfile.castingAbility,
          equals(AbilityType.intelligence),
        );
        expect(ctrl.getCastingModifier(hbClass.id.slug), equals(3));
      },
    );

    test(
      'imported homebrew class with casting ability but no progression shows no spells step',
      () async {
        final parser = CompendiumClassParser();
        final noProgClass = parser.parseClass(
          <String, dynamic>{
            'name': 'Runeblade',
            'source': 'HB',
            'hd': {'faces': 10},
            'spellcastingAbility': 'int',
          },
          forceRuleset: RulesetVersion.v2024,
        );

        await HomebrewPersistenceService().saveCustomClass(noProgClass);

        final steps = computeWizardStepTypes(
          selectedSpecies: 'human',
          selectedClass: noProgClass.id.slug,
          selectedRuleset: RulesetVersion.v2024,
          preset: WizardOrderingPreset.classic2014,
        );
        expect(
          steps,
          isNot(contains('spells')),
          reason:
              'Homebrew class with ability but no progression must not show a spells step',
        );
        final profile = resolveBuilderCasterProfile(
          noProgClass.id.slug,
          RulesetVersion.v2024,
        );
        expect(profile.isSpellcaster, isFalse);
      },
    );
  });
}
