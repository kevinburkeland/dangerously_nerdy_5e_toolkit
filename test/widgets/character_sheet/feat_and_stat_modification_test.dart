import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/add_feat_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/modify_ability_scores_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feat & Stat Modification on Character Sheet Tests', () {
    late Character baseCharacter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      baseCharacter = const Character(
        id: EntityId(slug: 'hero-bob', ruleset: RulesetVersion.v2024),
        name: 'Bob the Hero',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        baseScores: AbilityScores(
          strength: 14,
          dexterity: 12,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        bonusScores: AbilityScores(
          strength: 0,
          dexterity: 0,
          constitution: 0,
          intelligence: 0,
          wisdom: 0,
          charisma: 0,
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 3,
              hitDie: 'd10',
              hitPointsRolled: [6, 6],
              isStartingClass: true,
            ),
          ],
        ),
        resources: CharacterResourcePool(
          currentHp: 28,
          tempHp: 0,
          currentHitDice: {'d10': 3},
        ),
      );
    });

    test('Direct Ability Score Modification on CharacterSheetController updates stats', () async {
      final controller = CharacterSheetController(character: baseCharacter);

      expect(controller.character.baseScores.strength, equals(14));
      expect(controller.stats.effectiveScores.strength, equals(14));

      // Modify base score
      await controller.modifyAbilityScore(AbilityType.strength, 16, isBaseScore: true);
      expect(controller.character.baseScores.strength, equals(16));
      expect(controller.stats.effectiveScores.strength, equals(16));

      // Modify bonus score (e.g. permanent +1 CON potion)
      await controller.modifyAbilityScore(AbilityType.constitution, 1, isBaseScore: false);
      expect(controller.character.bonusScores.constitution, equals(1));
      expect(controller.stats.effectiveScores.constitution, equals(15));
    });

    test('Adding a Feat updates character feats and applies ability score boost', () async {
      final controller = CharacterSheetController(character: baseCharacter);

      expect(controller.character.feats.isEmpty, isTrue);

      const athleteRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'athlete',
        displayName: 'Athlete',
      );

      await controller.addFeat(
        athleteRef,
        abilityBonus: AbilityType.strength,
        bonusAmount: 1,
        reason: 'DM reward for tournament victory',
      );

      expect(controller.character.feats.length, equals(1));
      expect(controller.character.feats.first.slug, equals('athlete'));
      expect(controller.character.bonusScores.strength, equals(1));
      expect(controller.stats.effectiveScores.strength, equals(15));
    });

    test('Removing a Feat removes it and reverses associated ability bonuses', () async {
      final controller = CharacterSheetController(character: baseCharacter);

      const athleteRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'athlete',
        displayName: 'Athlete',
      );

      await controller.addFeat(
        athleteRef,
        abilityBonus: AbilityType.strength,
        bonusAmount: 1,
      );
      expect(controller.character.feats.length, equals(1));
      expect(controller.character.bonusScores.strength, equals(1));

      await controller.removeFeat('athlete', reason: 'Retrained feat');
      expect(controller.character.feats.isEmpty, isTrue);
      expect(controller.character.bonusScores.strength, equals(0));
      expect(controller.stats.effectiveScores.strength, equals(14));
    });

    test('Skill Expert feat: supports selecting the same skill for proficiency and expertise', () async {
      final controller = CharacterSheetController(character: baseCharacter);

      // Initially character has no athletics proficiency
      expect(controller.character.skillProficiencies[SkillType.athletics], isNull);

      const skillExpertRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'skill-expert',
        displayName: 'Skill Expert',
      );

      // Add Skill Expert granting +1 CON, Athletics as skill grant, and Athletics as expertise grant
      await controller.addFeat(
        skillExpertRef,
        abilityBonus: AbilityType.constitution,
        bonusAmount: 1,
        skillGrant: SkillType.athletics,
        expertiseGrant: SkillType.athletics,
        reason: 'Bonus feat from guild mentor',
      );

      expect(controller.character.feats.any((f) => f.slug == 'skill-expert'), isTrue);
      expect(controller.character.bonusScores.constitution, equals(1));
      expect(controller.stats.effectiveScores.constitution, equals(15));

      // Both went to Athletics -> resulting in Expertise!
      expect(
        controller.character.skillProficiencies[SkillType.athletics],
        equals(SkillProficiencyLevel.expertise),
      );
    });

    test('Campaign audit log tracks stat and feat changes when character is part of a campaign', () async {
      // 1. Set up a campaign containing Bob's character ID
      final profile = CampaignProfile.defaultProfile(
        id: 'camp-123',
        name: 'The Lost Mines',
      ).copyWith(partyCharacterIds: ['hero-bob']);
      await CampaignProfileService().saveProfileImmediate(profile);

      final controller = CharacterSheetController(character: baseCharacter);

      // 2. Modify ability score
      await controller.modifyAbilityScore(
        AbilityType.constitution,
        1,
        isBaseScore: false,
        reason: 'Drank Potion of Constitution',
      );

      // 3. Add a feat
      const toughRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'tough',
        displayName: 'Tough',
      );
      await controller.addFeat(
        toughRef,
        reason: 'Awarded by DM',
      );

      // 4. Remove a feat
      await controller.removeFeat(
        'tough',
        reason: 'Removed by player',
      );

      // 5. Verify the campaign profile's changeLog recorded all three actions!
      final profiles = await CampaignProfileService().loadAllProfiles();
      final updatedProfile = profiles.firstWhere((p) => p.id == 'camp-123');

      expect(updatedProfile.changeLog.length, equals(3));

      // Verify stat modification event
      final statEvt = updatedProfile.changeLog.firstWhere((e) => e.type == 'statModified');
      expect(statEvt.playerName, equals('Bob the Hero'));
      expect(statEvt.details, contains('Constitution'));
      expect(statEvt.details, contains('Drank Potion of Constitution'));

      // Verify feat added event
      final featAddEvt = updatedProfile.changeLog.firstWhere((e) => e.type == 'featAdded');
      expect(featAddEvt.playerName, equals('Bob the Hero'));
      expect(featAddEvt.details, contains('Tough'));
      expect(featAddEvt.details, contains('Awarded by DM'));

      // Verify feat removed event
      final featRemEvt = updatedProfile.changeLog.firstWhere((e) => e.type == 'featRemoved');
      expect(featRemEvt.playerName, equals('Bob the Hero'));
      expect(featRemEvt.details, contains('Tough'));
      expect(featRemEvt.details, contains('Removed by player'));
    });

    testWidgets('ModifyAbilityScoresDialog renders and allows adjusting scores', (tester) async {
      final controller = CharacterSheetController(character: baseCharacter);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModifyAbilityScoresDialog.show(context, controller: controller),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Modify Ability Scores'), findsOneWidget);
      expect(find.text('STR'), findsOneWidget);
      expect(find.text('CON'), findsOneWidget);

      // Find + button for Strength
      final plusButtons = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
      expect(plusButtons, findsWidgets);

      // Tap the first plus button to increment strength
      await tester.tap(plusButtons.first);
      await tester.pumpAndSettle();

      // Tap Apply Changes
      await tester.tap(find.text('Apply Changes'));
      await tester.pumpAndSettle();

      // Controller should have updated strength score
      expect(controller.character.baseScores.strength, equals(15));
    });

    testWidgets('AddFeatDialog renders search and custom feat option', (tester) async {
      final controller = CharacterSheetController(character: baseCharacter);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddFeatDialog.show(context, controller),
                child: const Text('Open Add Feat'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Add Feat'));
      await tester.pumpAndSettle();

      expect(find.text('Add Feat / Bonus Feat'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Search feats by name or keyword...'), findsOneWidget);
    });
  });
}
