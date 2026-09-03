import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/feats_compendium_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/feats/feat_card.dart';

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
        home: FeatsCompendiumScreen(initialEdition: edition),
      ),
    );
  }

  testWidgets('FeatsCompendiumScreen renders, filters, and opens feat detail dialog', (tester) async {
    await tester.pumpWidget(buildTestScreen());
    await tester.pumpAndSettle();

    // Verify Title & header
    expect(find.text('Feats Compendium'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(FeatCard), findsWidgets);

    // Verify presence of category chips
    expect(find.widgetWithText(FilterChip, 'Origin'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'General'), findsOneWidget);

    // Filter by Origin Feats
    await tester.tap(find.widgetWithText(FilterChip, 'Origin'));
    await tester.pumpAndSettle();

    // Verify Feats are displayed
    expect(find.text('Alert'), findsWidgets);

    // Tap on Alert card to open detail dialog
    await tester.tap(find.text('Alert').first);
    await tester.pumpAndSettle();

    // Verify detail dialog is shown
    expect(find.textContaining('Initiative Proficiency'), findsWidgets);
  });

  testWidgets('FeatsCompendiumScreen renders full feats catalogue in 2014 rules edition mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestScreen(edition: DmRulesEdition.v2014));
    await tester.pumpAndSettle();

    // Verify 2014 feats are fully populated
    expect(find.byType(FeatCard), findsWidgets);
    expect(find.text('Alert'), findsWidgets);
    expect(find.text('Healer'), findsWidgets);
    expect(find.text('Lucky'), findsWidgets);

    // Search for War Caster
    await tester.enterText(find.byType(TextField), 'War Caster');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FeatCard, 'War Caster'), findsOneWidget);
  });

  testWidgets('FeatCard shows General Feat in 2014 mode and Origin Feat in 2024 mode for Alert', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. In 2024 mode:
    await tester.pumpWidget(buildTestScreen(edition: DmRulesEdition.v2024));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alert');
    await tester.pumpAndSettle();

    expect(find.textContaining('Origin Feat'), findsWidgets);

    // 2. In 2014 mode:
    await tester.pumpWidget(buildTestScreen(edition: DmRulesEdition.v2014));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alert');
    await tester.pumpAndSettle();

    expect(find.textContaining('General Feat'), findsWidgets);
  });
}
