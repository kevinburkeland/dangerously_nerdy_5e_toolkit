import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/features_traits_section.dart';

void main() {
  group('FeaturesTraitsSection 2014 RAW Background & Feats Tests', () {
    testWidgets('2014 Acolyte displays Shelter of the Faithful and omits Origin Feat & Ability Scores', (tester) async {
      const character2014 = Character(
        id: EntityId(slug: 'cleric-2014', ruleset: RulesetVersion.v2014),
        name: 'Brother Thomas',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: EntityReference<DomainEntity>(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'cleric',
                displayName: 'Cleric',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(wisdom: 16),
        feats: [
          EntityReference<DomainEntity>(
            refType: EntityType.feat,
            slug: 'alert',
            displayName: 'Alert',
          ),
        ],
      );

      final controller = CharacterSheetController(character: character2014);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturesTraitsSection(controller: controller),
            ),
          ),
        ),
      );

      // Verify Background chip exists
      expect(find.text('Acolyte'), findsOneWidget);

      // Tap on Background chip to open reference modal
      await tester.tap(find.text('Acolyte'));
      await tester.pumpAndSettle();

      // Verify 2014 canonical feature is present
      expect(find.textContaining('Shelter of the Faithful'), findsOneWidget);

      // Crucially verify NO Origin Feat or Ability Scores text is present in the modal
      expect(find.textContaining('Origin Feat'), findsNothing);
      expect(find.textContaining('Ability Scores:'), findsNothing);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Check Feats section on 2014 character: Alert feat should have category "Feat", NOT "Origin Feat"
      expect(find.text('Origin Feat'), findsNothing);
      expect(find.text('Feat'), findsOneWidget);

      // Tap on Alert feat chip
      await tester.tap(find.text('Alert'));
      await tester.pumpAndSettle();

      // Modal badge should say FEAT, not ORIGIN FEAT
      expect(find.text('FEAT'), findsOneWidget);
      expect(find.text('ORIGIN FEAT'), findsNothing);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap on Human Species chip
      await tester.tap(find.text('Human Traits'));
      await tester.pumpAndSettle();

      // In 2014, human traits modal should NOT contain 2024 Origin Feat
      expect(find.textContaining('Origin Feat'), findsNothing);
    });

    testWidgets('2014 Soldier displays Military Rank without Origin Feat', (tester) async {
      const character2014 = Character(
        id: EntityId(slug: 'fighter-2014', ruleset: RulesetVersion.v2014),
        name: 'Captain Marcus',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        backgroundRef: EntityReference<DomainEntity>(
          refType: EntityType.background,
          slug: 'soldier',
          displayName: 'Soldier',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16),
      );

      final controller = CharacterSheetController(character: character2014);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturesTraitsSection(controller: controller),
            ),
          ),
        ),
      );

      // Tap Soldier chip
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Military Rank'), findsOneWidget);
      expect(find.textContaining('Origin Feat'), findsNothing);
      expect(find.textContaining('Ability Scores:'), findsNothing);
    });

    testWidgets('2024 Acolyte still displays 2024 Origin Feat & Ability Scores', (tester) async {
      const character2024 = Character(
        id: EntityId(slug: 'cleric-2024', ruleset: RulesetVersion.v2024),
        name: 'Sister Sarah',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        backgroundRef: EntityReference<DomainEntity>(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'cleric',
                displayName: 'Cleric',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(wisdom: 16),
      );

      final controller = CharacterSheetController(character: character2024);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturesTraitsSection(controller: controller),
            ),
          ),
        ),
      );

      // Tap on Acolyte chip
      await tester.tap(find.text('Acolyte'));
      await tester.pumpAndSettle();

      // Under 2024 rules, Origin Feat and Ability Scores are present
      expect(find.textContaining('Origin Feat: Magic Initiate'), findsOneWidget);
      expect(find.textContaining('Ability Scores: +2 WIS'), findsOneWidget);
    });
  });
}
