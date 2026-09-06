import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';

Character _createTestChar({
  required String slug,
  required String name,
  required List<ClassLevelProgression> classes,
  List<EntityReference<DomainEntity>> feats = const [],
  AbilityScores baseScores = const AbilityScores(),
}) {
  return Character(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2014),
    name: name,
    speciesRef: const EntityReference<DomainEntity>(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    baseScores: baseScores,
    progression: CharacterProgression(classes: classes),
    feats: feats,
    resources: const CharacterResourcePool(),
  );
}

const mockHomebrewInvocationFeat = Feat(
  id: EntityId(slug: 'homebrew-invocation-adept', ruleset: RulesetVersion.v2014),
  name: 'Homebrew Invocation Adept',
  category: 'General',
  descriptionMarkdown: 'Grants one Eldritch Invocation option of your choice.',
  customProperties: {
    'featureType': ['EI'],
    'optionalfeatureProgression': [
      {
        'name': 'Eldritch Invocations',
        'featureType': ['EI'],
        'progression': {'*': 1},
      }
    ],
  },
);

const mockHomebrewFightingStyleFeat = Feat(
  id: EntityId(slug: 'homebrew-fighting-style-initiate', ruleset: RulesetVersion.v2014),
  name: 'Homebrew Fighting Style Initiate',
  category: 'General',
  descriptionMarkdown: 'Grants one Fighting Style option of your choice.',
  customProperties: {
    'featureType': ['FS:F'],
    'optionalfeatureProgression': [
      {
        'name': 'Fighting Style',
        'featureType': ['FS:F'],
        'progression': {'*': 1},
      }
    ],
  },
);

void main() {
  group('Feat Feature Options (Homebrew & Optional Feature Progressions)', () {
    test('FeatAsiExtension identifies invocation and fighting style choices on homebrew feats', () {
      expect(mockHomebrewInvocationFeat.hasInvocationChoice, isTrue);
      expect(mockHomebrewInvocationFeat.invocationChoiceCount, equals(1));
      expect(mockHomebrewInvocationFeat.hasFightingStyleChoice, isFalse);

      expect(mockHomebrewFightingStyleFeat.hasFightingStyleChoice, isTrue);
      expect(mockHomebrewFightingStyleFeat.hasInvocationChoice, isFalse);
    });

    test('Homebrew feats with generic optionalfeatureProgression are recognized', () {
      const homebrewFeat = Feat(
        id: EntityId(slug: 'custom-invoker', ruleset: RulesetVersion.v2014),
        name: 'Custom Invoker',
        category: 'General',
        descriptionMarkdown: 'Grants an invocation.',
        customProperties: {
          'optionalfeatureProgression': [
            {
              'name': 'Eldritch Invocations',
              'featureType': ['EI'],
              'progression': {'*': 1},
            }
          ]
        },
      );
      expect(homebrewFeat.hasInvocationChoice, isTrue);
      expect(homebrewFeat.invocationChoiceCount, equals(1));
    });

    test('RAW prerequisite evaluation for invocation granting feats', () {
      final armorOfShadows = SrdFeatureOptions.warlockInvocations
          .firstWhere((i) => i.id == 'armor_of_shadows');
      final agonizingBlast = SrdFeatureOptions.warlockInvocations
          .firstWhere((i) => i.id == 'agonizing_blast');
      final ascendantStep = SrdFeatureOptions.warlockInvocations
          .firstWhere((i) => i.id == 'ascendant_step'); // requires 9th level

      // 1. Non-warlock
      final nonWarlockArmor = mockHomebrewInvocationFeat.evaluateInvocationPrerequisite(
        armorOfShadows,
        isWarlock: false,
        warlockLevel: 0,
      );
      expect(nonWarlockArmor.isMet, isTrue, reason: 'Armor of Shadows has no prerequisites');

      final nonWarlockAgonizing = mockHomebrewInvocationFeat.evaluateInvocationPrerequisite(
        agonizingBlast,
        isWarlock: false,
        warlockLevel: 0,
        knownSpellSlugs: ['eldritch-blast'],
      );
      expect(nonWarlockAgonizing.isMet, isFalse,
          reason: 'Non-warlock cannot choose invocation with prerequisites even if they know cantrip');

      // 2. Warlock meeting prerequisite
      final warlockAgonizingMet = mockHomebrewInvocationFeat.evaluateInvocationPrerequisite(
        agonizingBlast,
        isWarlock: true,
        warlockLevel: 2,
        knownSpellSlugs: ['eldritch-blast'],
      );
      expect(warlockAgonizingMet.isMet, isTrue);

      final warlockAgonizingUnmet = mockHomebrewInvocationFeat.evaluateInvocationPrerequisite(
        agonizingBlast,
        isWarlock: true,
        warlockLevel: 2,
        knownSpellSlugs: ['fire-bolt'],
      );
      expect(warlockAgonizingUnmet.isMet, isFalse);

      // 3. Warlock level requirement
      final warlockAscendantLowLevel = mockHomebrewInvocationFeat.evaluateInvocationPrerequisite(
        ascendantStep,
        isWarlock: true,
        warlockLevel: 5,
      );
      expect(warlockAscendantLowLevel.isMet, isFalse);

      final warlockAscendantHighLevel = mockHomebrewInvocationFeat.evaluateInvocationPrerequisite(
        ascendantStep,
        isWarlock: true,
        warlockLevel: 9,
      );
      expect(warlockAscendantHighLevel.isMet, isTrue);
    });

    test('getAllSelectedFeatureOptions aggregates feat- prefixed option keys', () {
      const progression = CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 4,
            hitDie: 'd6',
            selectedFeatureOptions: {
              'feat-homebrew-invocation-adept': ['armor_of_shadows'],
              'feat-homebrew-fighting-style-initiate': ['defense'],
              'unrelated-invalid-key': ['foo'],
            },
          ),
        ],
      );

      final allOptions = progression.getAllSelectedFeatureOptions();
      expect(allOptions['feat-homebrew-invocation-adept'], equals(['armor_of_shadows']));
      expect(allOptions['feat-homebrew-fighting-style-initiate'], equals(['defense']));
      expect(allOptions.containsKey('unrelated-invalid-key'), isFalse);
    });

    test('Character hasCapabilityFlag detects feat-granted invocation capability', () {
      final char = _createTestChar(
        slug: 'test-char',
        name: 'Occult Scholar',
        classes: [
          const ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 4,
            hitDie: 'd6',
            selectedFeatureOptions: {
              'feat-homebrew-invocation-adept': ['agonizing_blast'],
            },
          ),
        ],
        feats: const [
          EntityReference(
            refType: EntityType.feat,
            slug: 'homebrew-invocation-adept',
            displayName: 'Homebrew Invocation Adept',
          ),
        ],
      );

      expect(char.hasCapabilityFlag('eldritchBlastChaDamage'), isTrue);
      expect(char.hasCapabilityFlag('agonizing_blast'), isTrue);
    });

    test('CharacterActionsResolver extracts action from feat-granted invocation', () {
      final char = _createTestChar(
        slug: 'test-warlock',
        name: 'Occult Scholar',
        classes: [
          const ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 4,
            hitDie: 'd10',
            selectedFeatureOptions: {
              'feat-homebrew-invocation-adept': ['armor_of_shadows'],
            },
          ),
        ],
        feats: const [
          EntityReference(
            refType: EntityType.feat,
            slug: 'homebrew-invocation-adept',
            displayName: 'Homebrew Invocation Adept',
          ),
        ],
      );

      final controller = CharacterSheetController(character: char);
      final stats = CharacterEvaluationEngine.evaluate(char);
      final resolved = CharacterActionsResolver.resolve(
        character: char,
        stats: stats,
        controller: controller,
      );
      final allActions = [...resolved.actions, ...resolved.bonusActions, ...resolved.reactions];
      final armorAction = allActions
          .where((a) => a.name.toLowerCase().contains('armor of shadows') || a.name.toLowerCase().contains('mage armor'))
          .firstOrNull;
      expect(armorAction, isNotNull);
    });

    test('CharacterProgressionEngine merges featureOptionGrants during level up', () {
      final baseChar = _createTestChar(
        slug: 'test-fighter',
        name: 'Eldritch Knight',
        classes: [
          const ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 3,
            hitDie: 'd10',
            selectedFeatureOptions: {
              'fighting-style': ['defense'],
            },
          ),
        ],
      );

      const levelUpRequest = LevelUpRequest(
        targetClassSlug: 'fighter',
        asiOrFeat: AsiOrFeatChoice.feat(
          EntityReference(
            refType: EntityType.feat,
            slug: 'homebrew-invocation-adept',
            displayName: 'Homebrew Invocation Adept',
          ),
          featureOptionGrants: {
            'feat-homebrew-invocation-adept': ['armor_of_shadows'],
          },
        ),
      );

      final updatedChar = CharacterProgressionEngine.applyLevelUp(baseChar, levelUpRequest);
      expect(updatedChar.totalLevel, equals(4));
      expect(updatedChar.feats.any((f) => f.slug == 'homebrew-invocation-adept'), isTrue);

      final allOptions = updatedChar.progression.getAllSelectedFeatureOptions();
      expect(allOptions['feat-homebrew-invocation-adept'], equals(['armor_of_shadows']));
      expect(allOptions['fighting-style'], equals(['defense']));
    });

    test('CharacterSheetController.addFeat saves feat options and removeFeat cleans them up', () async {
      final baseChar = _createTestChar(
        slug: 'test-wizard',
        name: 'Gondor',
        classes: [
          const ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 4,
            hitDie: 'd6',
          ),
        ],
      );

      final controller = CharacterSheetController(character: baseChar);

      await controller.addFeat(
        const EntityReference(
          refType: EntityType.feat,
          slug: 'homebrew-invocation-adept',
          displayName: 'Homebrew Invocation Adept',
        ),
        featureOptions: ['armor_of_shadows'],
      );

      expect(controller.character.feats.any((f) => f.slug == 'homebrew-invocation-adept'), isTrue);
      final optionsAfterAdd = controller.character.progression.getAllSelectedFeatureOptions();
      expect(optionsAfterAdd['feat-homebrew-invocation-adept'], equals(['armor_of_shadows']));

      await controller.removeFeat('homebrew-invocation-adept');
      expect(controller.character.feats.any((f) => f.slug == 'homebrew-invocation-adept'), isFalse);
      final optionsAfterRemove = controller.character.progression.getAllSelectedFeatureOptions();
      expect(optionsAfterRemove.containsKey('feat-homebrew-invocation-adept'), isFalse);
    });
  });
}
