import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/rules_edition_toggle.dart';

Widget createTestApp() {
  return const MaterialApp(
    home: CharacterBuilderScreen(),
  );
}

void main() {
  group('CharacterBuilderScreen Live Sheet & Wizard UI Tests', () {
    testWidgets('Renders top RulesEditionToggle in AppBar and tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Top edition toggle
      expect(find.byType(RulesEditionToggle), findsOneWidget);
      expect(find.text('2024'), findsWidgets);
      expect(find.text('2014'), findsWidgets);

      // Tabs
      expect(find.text('Live Sheet'), findsOneWidget);
      expect(find.text('Guided Builder'), findsOneWidget);
      expect(find.text('Inventory & Loot'), findsOneWidget);
      expect(find.text('Level Up'), findsOneWidget);
    });

    testWidgets('Live sheet renders vital stats, saving throws, and skills', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Vitals
      expect(find.text('ARMOR CLASS'), findsOneWidget);
      expect(find.text('PROF BONUS'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);

      // Saving Throws Card
      expect(find.text('SAVING THROWS'), findsOneWidget);
      expect(find.text('STR'), findsWidgets);
      expect(find.text('DEX'), findsWidgets);
      expect(find.text('CON'), findsWidgets);

      // Skills Card
      expect(find.text('SKILLS & PROFICIENCIES'), findsOneWidget);
      expect(find.text('Athletics'), findsOneWidget);
      expect(find.text('Stealth'), findsOneWidget);
    });

    testWidgets('Tapping a saving throw triggers roll feedback', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap STR saving throw tile
      final strSaveTile = find.byKey(const ValueKey('save_tile_strength'));
      await tester.tap(strSaveTile);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify SnackBar with roll result appeared
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Saving Throw'), findsOneWidget);
    });

    testWidgets('Switching to Guided Builder tab displays 8-step wizard', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Guided Builder Tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1: Character Identity & Edition'), findsOneWidget);
      expect(find.text('Next Step'), findsOneWidget);

      // Tap Next Step to Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species
      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);
      expect(find.text('Human'), findsOneWidget);
      expect(find.text('Elf'), findsOneWidget);

      // Tap Next Step to Step 3: Class
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
    });

    testWidgets('Toggling RulesEditionToggle updates edition state', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Switch to 2014
      await tester.tap(find.text('2014').first);
      await tester.pumpAndSettle();

      expect(find.text('2014 CLASSIC'), findsOneWidget);

      // Switch back to 2024
      await tester.tap(find.text('2024').first);
      await tester.pumpAndSettle();

      expect(find.text('2024 REVISED'), findsOneWidget);
    });
  });
}
