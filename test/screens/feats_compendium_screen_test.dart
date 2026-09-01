import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/feats_compendium_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/feats/feat_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestScreen({SettingsProvider? provider}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: const MaterialApp(
        home: FeatsCompendiumScreen(),
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
}
