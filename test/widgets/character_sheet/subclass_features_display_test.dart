import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/features_traits_section.dart';

void main() {
  group('FeaturesTraitsSection Subclass Features Display Tests', () {
    testWidgets('Barbarian with Path of the Berserker displays both Class and Subclass features', (tester) async {
      const barbarianChar = Character(
        id: EntityId(slug: 'barbarian-hero', ruleset: RulesetVersion.v2024),
        name: 'Grom',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'barbarian',
                displayName: 'Barbarian',
              ),
              subclassRef: EntityReference<DomainEntity>(
                refType: EntityType.subclass,
                slug: 'path-of-the-berserker',
                displayName: 'Path of the Berserker',
              ),
              level: 3,
              hitDie: 'd12',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16),
      );

      final controller = CharacterSheetController(character: barbarianChar);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturesTraitsSection(controller: controller),
            ),
          ),
        ),
      );

      // Verify core class features chip is displayed
      expect(find.text('Barbarian Features (Lvl 3)'), findsOneWidget);

      // Verify subclass feature is displayed as a dedicated character feature chip!
      expect(find.text('Frenzy'), findsOneWidget);
      expect(find.textContaining('Path of the Berserker'), findsWidgets);

      // Tap on Frenzy to open detail sheet
      await tester.tap(find.text('Frenzy'));
      await tester.pumpAndSettle();

      // Verify modal content
      expect(find.textContaining('make a bonus melee attack or deal extra frenzy damage'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('Subclass features respect character level gating', (tester) async {
      // Register custom subclass with level 3 and level 7 features
      const testSub = Subclass(
        id: EntityId(slug: 'test-guardian', ruleset: RulesetVersion.v2024),
        name: 'Iron Guardian',
        classSlug: 'fighter',
        featuresMarkdown: '''
### Shield Intercept (Level 3)
When an ally within 5 feet is attacked, you can use your reaction to impose disadvantage.

### Adamantine Bastion (Level 7)
You gain resistance to critical hits and cannot be moved against your will.
''',
      );
      SrdClassesLibrary.addCustomSubclass(testSub);

      // Character is level 3
      const fighterLevel3 = Character(
        id: EntityId(slug: 'fighter-hero', ruleset: RulesetVersion.v2024),
        name: 'Vael',
        rulesEdition: DmRulesEdition.v2024,
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
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
              subclassRef: EntityReference<DomainEntity>(
                refType: EntityType.subclass,
                slug: 'test-guardian',
                displayName: 'Iron Guardian',
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16),
      );

      final controller = CharacterSheetController(character: fighterLevel3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturesTraitsSection(controller: controller),
            ),
          ),
        ),
      );

      // Level 3 feature must be displayed
      expect(find.text('Shield Intercept'), findsOneWidget);

      // Level 7 feature must NOT be displayed at Level 3
      expect(find.text('Adamantine Bastion'), findsNothing);

      // Tap on Shield Intercept to open detail sheet
      await tester.tap(find.text('Shield Intercept'));
      await tester.pumpAndSettle();

      expect(find.textContaining('use your reaction to impose disadvantage'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });
}
