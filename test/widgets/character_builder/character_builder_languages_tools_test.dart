import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';

void main() {
  group('CharacterBuilderScreen Languages and Tools Tests', () {
    testWidgets('Step 2 displays Dwarf tool proficiency choice when Dwarf is selected', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab
      final guidedTab = find.text('Guided Builder');
      expect(guidedTab, findsOneWidget);
      await tester.tap(guidedTab);
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Dwarf
      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);
      final dwarfTile = find.widgetWithText(ListTile, 'Dwarf');
      await tester.scrollUntilVisible(dwarfTile, 150, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(dwarfTile);
      await tester.pumpAndSettle();

      // Scroll down to reveal Dwarf Tool Proficiency
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify Dwarf Tool Proficiency prompt is displayed
      expect(find.text('Dwarf Tool Proficiency:'), findsOneWidget);
      expect(find.text("Smith's Tools"), findsOneWidget);
      expect(find.text("Brewer's Supplies"), findsOneWidget);
      expect(find.text("Mason's Tools"), findsOneWidget);

      // Select Brewer's Supplies
      await tester.tap(find.text("Brewer's Supplies"));
      await tester.pumpAndSettle();

      // Choice chip is selected
      final brewerChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, "Brewer's Supplies"));
      expect(brewerChip.selected, isTrue);
    });

    testWidgets('Step 2 displays bonus language selection when Human is selected', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab
      final guidedTab = find.text('Guided Builder');
      expect(guidedTab, findsOneWidget);
      await tester.tap(guidedTab);
      await tester.pumpAndSettle();

      // Step 1: Basics -> Select 2014 ruleset -> Next Step
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human
      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();

      // Scroll down to reveal bonus language prompt
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify bonus language prompt is displayed
      expect(find.text('Species Bonus Language:'), findsOneWidget);
      expect(find.text('Elvish'), findsOneWidget);
      expect(find.text('Draconic'), findsOneWidget);

      // Select Draconic
      await tester.tap(find.text('Draconic'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 1 languages selected'), findsOneWidget);
    });
  });
}
