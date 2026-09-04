import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/classes/class_detail_dialog.dart';

void main() {
  group('ClassDetailDialog Spells & Subclass Spells UI Tests', () {
    late CharacterClass testCasterClass;

    setUp(() {
      testCasterClass = CharacterClass(
        id: const EntityId(slug: 'cleric', ruleset: RulesetVersion.v2024),
        name: 'Cleric',
        hitDie: 'd8',
        spellcastingAbility: 'Wisdom',
        primaryAbility: 'Wisdom',
        featuresMarkdown: '### Spellcasting\nAs a conduit for divine power, you can cast cleric spells.',
        subclasses: [
          Subclass(
            id: const EntityId(slug: 'life-domain', ruleset: RulesetVersion.v2024),
            name: 'Life Domain',
            classSlug: 'cleric',
            featuresMarkdown: '### Disciple of Life\nHealing spells are more effective.',
            grants: [
              FeatureGrant.bonusSpell(
                grantId: 'sub-life-bless',
                slug: 'bless',
                displayName: 'Bless',
              ),
              FeatureGrant.bonusSpell(
                grantId: 'sub-life-cure-wounds',
                slug: 'cure-wounds',
                displayName: 'Cure Wounds',
              ),
            ],
          ),
        ],
      );
    });

    testWidgets('Renders Class Features, Subclasses, and Spells tabs for spellcasters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassDetailDialog(
              characterClass: testCasterClass,
              isPinned: false,
              onTogglePin: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Class Features'), findsOneWidget);
      expect(find.text('Subclasses (1)'), findsOneWidget);
      expect(find.textContaining('Spells ('), findsOneWidget);
      expect(find.text('Lore & Notes'), findsOneWidget);
    });

    testWidgets('Subclasses tab displays SUBCLASS / BONUS SPELLS chips for granted spells', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassDetailDialog(
              characterClass: testCasterClass,
              isPinned: false,
              onTogglePin: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Subclasses tab
      await tester.tap(find.text('Subclasses (1)'));
      await tester.pumpAndSettle();

      expect(find.text('SUBCLASS / BONUS SPELLS'), findsOneWidget);
      expect(find.text('Bless'), findsOneWidget);
      expect(find.text('Cure Wounds'), findsOneWidget);
    });

    testWidgets('Spells tab displays search bar, level chips, and spell items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassDetailDialog(
              characterClass: testCasterClass,
              isPinned: false,
              onTogglePin: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Spells tab
      await tester.tap(find.textContaining('Spells ('));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.text('Cantrip'), findsWidgets);
    });
  });
}
