import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/screens/homebrew/homebrew_workbench_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/screens/homebrew/widgets/field_editor_tile.dart';

void main() {
  group('HomebrewWorkbenchScreen Widget Tests', () {
    testWidgets('renders workbench with source, candidate cards, and field editors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewWorkbenchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check App Bar
      expect(find.textContaining('Ingestion Workbench'), findsOneWidget);

      // Check Left Pane: Source Text
      expect(find.textContaining('Source Text'), findsOneWidget);
      expect(find.text('Sample Monster'), findsOneWidget);
      expect(find.text('Sample Spell'), findsOneWidget);

      // Check Right Pane: Candidate Object and Fields
      expect(find.text('Adult Topaz Dragon'), findsAtLeastNWidgets(1));
      expect(find.text('Monster / Creature'), findsAtLeastNWidgets(1));

      // Field labels present
      expect(find.text('Armor Class'), findsAtLeastNWidgets(1));
      expect(find.text('Hit Points'), findsAtLeastNWidgets(1));
      expect(find.text('Speed'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Challenge Rating'), findsAtLeastNWidgets(1));

      // Check Commit button
      expect(find.textContaining('Commit'), findsOneWidget);
    });

    testWidgets('displays screen-reader semantic labels for parsing states',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      const missingHpSource = '''
### Incomplete Skeleton
Medium undead, lawful evil
Armor Class 13
Challenge 1/4
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewWorkbenchScreen(
            initialSourceText: missingHpSource,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that Hit Points is flagged as missing
      expect(find.text('— Missing'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Cannot create Monster'), findsOneWidget);
      expect(find.textContaining('Missing required field: Hit Points'), findsOneWidget);

      // Screen reader Semantics exists
      expect(
        find.bySemanticsLabel(RegExp(r'Missing required field')),
        findsAtLeastNWidgets(1),
      );

      // Commit button disabled
      final commitBtn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(commitBtn.onPressed, isNull);
    });

    testWidgets('user edits update field value and display User Edited badge',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      const source = '''
### Mystery Golem
Large construct, unaligned
Armor Class 15
Speed 30 ft.
Challenge 2
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewWorkbenchScreen(
            initialSourceText: source,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the text input for Hit Points specifically inside its FieldEditorTile
      final hpFieldFinder = find.ancestor(
        of: find.text('Hit Points'),
        matching: find.byType(FieldEditorTile),
      );
      expect(hpFieldFinder, findsOneWidget);

      final hpInputFinder = find.descendant(
        of: hpFieldFinder,
        matching: find.byType(TextFormField),
      );
      expect(hpInputFinder, findsOneWidget);

      // Enter value 50 into the Hit Points field
      await tester.enterText(hpInputFinder, '50');
      await tester.pumpAndSettle();

      // User Edited badge should appear
      expect(find.text('User Edited'), findsOneWidget);

      // Now valid! Ready to commit message should be visible
      expect(
        find.textContaining('Ready to commit. All domain invariants are satisfied.'),
        findsOneWidget,
      );
      final commitBtn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(commitBtn.onPressed, isNotNull);
    });

    testWidgets('changing candidate type updates expected fields safely',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      const spellSource = '''
### Frost Bolt
Evocation cantrip
Casting Time: 1 action
Range: 60 feet
Components: V, S
Duration: Instantaneous
A beam of frost strikes the enemy.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewWorkbenchScreen(
            initialSourceText: spellSource,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spell'), findsAtLeastNWidgets(1));
      expect(find.text('Casting Time'), findsAtLeastNWidgets(1));
      expect(find.text('School of Magic'), findsAtLeastNWidgets(1));

      // Open Popup Menu and change type to Monster
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monster / Creature').last);
      await tester.pumpAndSettle();

      // Schema fields should now be Monster fields
      expect(find.text('Armor Class'), findsAtLeastNWidgets(1));
      expect(find.text('Hit Points'), findsAtLeastNWidgets(1));
    });

    testWidgets('narrow / mobile layout renders tabs and remains responsive',
        (tester) async {
      // Set to phone portrait size
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewWorkbenchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check TabBar exists on mobile
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.textContaining('Candidates'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);

      // Tap Candidates tab
      await tester.tap(find.textContaining('Candidates'));
      await tester.pumpAndSettle();
      expect(find.text('Adult Topaz Dragon'), findsOneWidget);

      // Tap Editor tab
      await tester.tap(find.text('Editor'));
      await tester.pumpAndSettle();
      expect(find.text('Armor Class'), findsAtLeastNWidgets(1));

      // Ensure no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}
