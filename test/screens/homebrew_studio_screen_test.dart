import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/homebrew_studio_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomebrewStudioScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      HomebrewPersistenceService().clearAllHomebrew();
    });

    testWidgets('renders Homebrew Studio tabs and empty states', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Homebrew Studio'), findsOneWidget);
      expect(find.text('Spells (0)'), findsOneWidget);
      expect(find.text('Monsters (0)'), findsOneWidget);
      expect(find.text('Items (0)'), findsOneWidget);
      expect(find.text('No Custom Spells'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('opens SpellBuilderDialog on New Spell tap and saves spell', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FloatingActionButton
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Custom Spell'), findsOneWidget);
      expect(find.text('Spell Name'), findsOneWidget);

      // Enter spell name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Spell Name'),
        'Solar Flare',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Spell Description (Markdown supported)'),
        'Blasts radiant solar light in a 30ft cone.',
      );
      await tester.pumpAndSettle();

      // Tap Save Spell
      await tester.tap(find.text('Save Spell'));
      await tester.pumpAndSettle();

      // Verify saved in list
      expect(find.text('Solar Flare'), findsOneWidget);
      expect(find.textContaining('Evocation'), findsOneWidget);

      // Verify stored in persistence
      final saved = await HomebrewPersistenceService().loadCustomSpells();
      expect(saved.length, equals(1));
      expect(saved.first.name, equals('Solar Flare'));
      expect(saved.first.slug, equals('solar-flare'));
    });

    testWidgets('opens HomebrewImportDialog and parses compendium JSON', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomebrewStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap import icon button in AppBar
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Import Compendium JSON'), findsOneWidget);

      const jsonSnippet = '{"spell":[{"name":"Frost Nova","source":"HOMEBREW","level":3,"school":"V","time":[{"number":1,"unit":"action"}],"range":{"type":"point","distance":{"type":"feet","amount":30}},"components":{"v":true,"s":true},"duration":[{"type":"instant"}],"entries":["Freezes ground dealing {@damage 6d6|cold} damage."]}]}';

      await tester.enterText(find.byType(TextField), jsonSnippet);
      await tester.pumpAndSettle();

      expect(find.textContaining('Detected 1 entities'), findsOneWidget);
      expect(find.text('• Spells: 1 (Frost Nova)'), findsOneWidget);

      // Tap Import button
      await tester.tap(find.text('Import to Compendium'));
      await tester.pumpAndSettle();

      // Verify imported spell appears on screen
      expect(find.text('Frost Nova'), findsOneWidget);
    });
  });
}
