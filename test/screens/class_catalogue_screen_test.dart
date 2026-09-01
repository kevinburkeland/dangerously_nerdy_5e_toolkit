import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/class_catalogue_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/classes/class_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestScreen({SettingsProvider? provider, DmRulesEdition? edition}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: MaterialApp(
        home: ClassCatalogueScreen(initialEdition: edition),
      ),
    );
  }

  testWidgets('ClassCatalogueScreen renders classes, filters by role, and opens class details', (tester) async {
    // Set a larger surface size for compendium grid testing
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestScreen());
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Class Catalogue'), findsOneWidget);
    expect(find.byType(ClassCard), findsWidgets);

    // Verify Core Classes exist in the grid
    expect(find.text('Barbarian'), findsWidgets);
    expect(find.text('Fighter'), findsWidgets);

    // Filter by Martial role chip
    expect(find.widgetWithText(FilterChip, 'Martial'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Martial'));
    await tester.pumpAndSettle();

    expect(find.text('Barbarian'), findsWidgets);
    expect(find.text('Fighter'), findsWidgets);

    // Tap on Fighter to open details modal
    await tester.tap(find.text('Fighter').first);
    await tester.pumpAndSettle();

    // Verify details modal content
    expect(find.text('CLASS PROFICIENCIES & ATTRIBUTES'), findsOneWidget);
    expect(find.text('Hit Die'), findsOneWidget);
  });

  testWidgets('ClassCatalogueScreen renders all 12 core classes in 2014 rules edition mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestScreen(edition: DmRulesEdition.v2014));
    await tester.pumpAndSettle();

    // Verify all core classes exist in 2014 mode
    expect(find.byType(ClassCard), findsWidgets);
    expect(find.text('Barbarian'), findsWidgets);
    expect(find.text('Bard'), findsWidgets);
    expect(find.text('Cleric'), findsWidgets);
    expect(find.text('Druid'), findsWidgets);
    expect(find.text('Fighter'), findsWidgets);

    // Search for Sorcerer to verify search in 2014 mode
    await tester.enterText(find.byType(TextField), 'Sorcerer');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ClassCard, 'Sorcerer'), findsOneWidget);
  });
}
