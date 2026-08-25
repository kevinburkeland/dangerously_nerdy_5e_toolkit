import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/table_index_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/tables/quick_roller_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/tables/rollable_table_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/tables/treasure_hoard_view.dart';

void main() {
  Widget buildTestableScreen({int initialTabIndex = 0}) {
    final provider = SettingsProvider(
      initialSettings: const AppSettings(
        rulesEdition: DmRulesEdition.v2024,
      ),
      autoLoad: false,
    );

    return SettingsScope(
      notifier: provider,
      child: MaterialApp(
        theme: AppTheme.buildTheme(
          brightness: Brightness.dark,
          accent: FantasyAccent.paladinGold,
        ),
        home: TableIndexScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  group('TableIndexScreen Widget Tests', () {
    testWidgets('renders Table Index screen with title and default tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Table Index'), findsOneWidget);
      expect(find.text('Treasure Generator'), findsOneWidget);
      expect(find.text('All Tables Index'), findsOneWidget);
      expect(find.text('Quick Rollers'), findsOneWidget);
      expect(find.byType(TreasureHoardView), findsOneWidget);
    });

    testWidgets('TreasureHoardView generates drops, adjusts party size, and toggles liquidation', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Check CR Choice chips
      expect(find.text('5–10'), findsOneWidget);
      expect(find.text('17+'), findsOneWidget);

      // Tap 17+ CR tier
      await tester.tap(find.text('17+'));
      await tester.pumpAndSettle();

      // Tap Individual Drop
      final indivBtn = find.text('Individual Drop');
      expect(indivBtn, findsOneWidget);
      await tester.tap(indivBtn);
      await tester.pumpAndSettle();

      // Party size stepper: tap '+'
      final addPlayerBtn = find.byIcon(Icons.add);
      expect(addPlayerBtn, findsWidgets);
      await tester.tap(addPlayerBtn.first);
      await tester.pumpAndSettle();
      expect(find.text('5 Players'), findsOneWidget);

      // Checkbox liquidation toggle
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    });

    testWidgets('switches to All Tables Index tab, searches, and rolls on table', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen(initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.byType(RollableTableCard), findsWidgets);
      expect(find.text('Search all SRD tables, loot items, magic surges...'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Wild Magic');
      await tester.pumpAndSettle();

      expect(find.text('Wild Magic Surge'), findsOneWidget);

      // Tap roll button
      final rollBtn = find.text('1d100').first;
      await tester.tap(rollBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Roll '), findsWidgets);
    });

    testWidgets('switches to Quick Rollers tab and dispenses trinket and wild magic', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen(initialTabIndex: 2));
      await tester.pumpAndSettle();

      expect(find.byType(QuickRollerCard), findsOneWidget);
      expect(find.text('Wild Magic Surge (d100)'), findsOneWidget);
      expect(find.text('100 SRD Trinkets Dispenser'), findsOneWidget);

      // Tap Dispense Trinket
      final dispenseBtn = find.text('Dispense Trinket');
      expect(dispenseBtn, findsOneWidget);
      await tester.tap(dispenseBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('d100:'), findsOneWidget);
    });
  });
}
