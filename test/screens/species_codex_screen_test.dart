import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/species_codex_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/races/race_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/races/race_detail_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget() {
    return MaterialApp(
      home: SettingsScope(
        notifier: SettingsProvider(),
        child: const SpeciesCodexScreen(),
      ),
    );
  }

  group('SpeciesCodexScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders screen title, search header, view mode chips, and species cards', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Species & Lineages Codex'), findsOneWidget);
      expect(find.text('All Species'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('2024 Diffs'), findsOneWidget);
      expect(find.text('Homebrew'), findsOneWidget);

      // Verify canonical SRD species cards
      expect(find.text('Elf'), findsOneWidget);
      expect(find.text('Dwarf'), findsOneWidget);
      expect(find.text('Human'), findsOneWidget);
    });

    testWidgets('filters species list by search query text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Dragonborn');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(RaceCard, 'Dragonborn'), findsOneWidget);
      expect(find.widgetWithText(RaceCard, 'Elf'), findsNothing);
      expect(find.widgetWithText(RaceCard, 'Dwarf'), findsNothing);
    });

    testWidgets('filters species by size chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Small' filter chip
      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(RaceCard, 'Halfling'), findsOneWidget);
      expect(find.widgetWithText(RaceCard, 'Gnome'), findsOneWidget);
      expect(find.widgetWithText(RaceCard, 'Elf'), findsNothing);
    });

    testWidgets('opens RaceDetailDialog upon tapping a race card', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on the Elf card
      await tester.tap(find.widgetWithText(RaceCard, 'Elf'));
      await tester.pumpAndSettle();

      expect(find.byType(RaceDetailDialog), findsOneWidget);
      expect(find.text('Traits & Lineages'), findsOneWidget);
      expect(find.text('Lore & Notes'), findsOneWidget);
      expect(find.text('High Elf'), findsOneWidget);
      expect(find.text('Wood Elf'), findsOneWidget);
    });
  });
}
