import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_homebrew_validator.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/missing_homebrew_warning_widget.dart';

void main() {
  group('MissingHomebrewWarningWidget Tests', () {
    late Character testCharacter;

    setUp(() {
      testCharacter = const Character(
        id: EntityId(slug: 'gandalf_custom', ruleset: RulesetVersion.v2024),
        name: 'Gandalf the Homebrewed',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'custom_maiar',
          displayName: 'Maiar',
          rulesetPreferred: RulesetVersion.homebrew,
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'custom_istar',
                displayName: 'Istar',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 5,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(
          currentHp: 30,
          spellSlots: SpellSlotPool(),
        ),
      );
    });

    testWidgets('MissingHomebrewBanner renders when homebrew is missing and opens dialog on tap', (tester) async {
      const report = MissingHomebrewReport(
        missingItems: [
          MissingHomebrewItem(
            type: HomebrewEntityType.classType,
            slug: 'custom_istar',
            name: 'Istar',
            details: 'Required class not installed',
          ),
          MissingHomebrewItem(
            type: HomebrewEntityType.speciesType,
            slug: 'custom_maiar',
            name: 'Maiar',
            details: 'Required species not installed',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissingHomebrewBanner(
              character: testCharacter,
              report: report,
            ),
          ),
        ),
      );

      expect(find.text('Missing Homebrew Content'), findsOneWidget);
      expect(find.text('2 missing'), findsOneWidget);
      expect(find.byKey(const Key('missing_homebrew_banner_details_btn')), findsOneWidget);

      // Tap Details button to open dialog
      await tester.tap(find.byKey(const Key('missing_homebrew_banner_details_btn')));
      await tester.pumpAndSettle();

      // Verify dialog is open and shows missing details
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Character: Gandalf the Homebrewed'), findsOneWidget);
      expect(find.text('Istar'), findsOneWidget);
      expect(find.text('Maiar'), findsOneWidget);
      expect(find.text('Identifier: custom_istar'), findsOneWidget);
      expect(find.text('Identifier: custom_maiar'), findsOneWidget);
      expect(find.text('How to resolve:'), findsOneWidget);

      // Tap Dismiss button
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('MissingHomebrewBanner does not render when no homebrew is missing', (tester) async {
      const report = MissingHomebrewReport(missingItems: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissingHomebrewBanner(
              character: testCharacter,
              report: report,
            ),
          ),
        ),
      );

      expect(find.text('Missing Homebrew Content'), findsNothing);
      expect(find.byType(MissingHomebrewBanner), findsOneWidget);
      // SizedBox.shrink inside
      expect(find.text('Details'), findsNothing);
    });

    testWidgets('MissingHomebrewBadge renders on roster card and opens dialog on tap', (tester) async {
      const report = MissingHomebrewReport(
        missingItems: [
          MissingHomebrewItem(
            type: HomebrewEntityType.spellType,
            slug: 'custom_meteor',
            name: 'Custom Meteor',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissingHomebrewBadge(
              character: testCharacter,
              report: report,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('missing_homebrew_badge_gandalf_custom')), findsOneWidget);
      expect(find.text('Missing Homebrew (1)'), findsOneWidget);

      // Tap badge
      await tester.tap(find.byKey(const ValueKey('missing_homebrew_badge_gandalf_custom')));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Custom Meteor'), findsOneWidget);
      expect(find.text('Identifier: custom_meteor'), findsOneWidget);
    });
  });
}
