import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dpr_calculator_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  Widget buildTestableScreen({DmRulesEdition edition = DmRulesEdition.v2024}) {
    return MaterialApp(
      theme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        accent: FantasyAccent.paladinGold,
      ),
      home: DprCalculatorScreen(initialEdition: edition),
    );
  }

  group('DprCalculatorScreen Widget Tests', () {
    testWidgets('renders DPR Calculator with clean custom build default and 2024 header', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // App bar & Rules Edition Header
      expect(find.text('DPR Calculator & Graph'), findsOneWidget);
      expect(find.text('Active: 2024 Revised Rules'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // AC Target & Metrics
      expect(find.text('Target Armor Class (AC):'), findsOneWidget);
      expect(find.text('AC 15'), findsOneWidget);
      expect(find.text('Accuracy'), findsNWidgets(2));
      expect(find.text('Crit Rate'), findsOneWidget);

      // Combatant Configurator
      expect(find.text('Attacks, Weapons & Cantrips'), findsOneWidget);
      expect(find.text('Equip Weapon / Cantrip'), findsOneWidget);
      expect(find.text('Attack / Weapon / Cantrip Name'), findsOneWidget);
    });

    testWidgets('switches between 2024 and 2014 rules edition toggles', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Active: 2024 Revised Rules'), findsOneWidget);

      // Tap 2014 Segmented Button
      final btn2014 = find.text('2014');
      expect(btn2014, findsOneWidget);
      await tester.tap(btn2014);
      await tester.pumpAndSettle();

      expect(find.text('Active: 2014 5e RAW'), findsOneWidget);
    });

    testWidgets('opens weapon picker sheet and selects a weapon', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final equipBtn = find.text('Equip Weapon / Cantrip').first;
      expect(equipBtn, findsOneWidget);
      await tester.tap(equipBtn);
      await tester.pumpAndSettle();

      // Verify modal sheet is open
      expect(find.text('Select Weapon, Cantrip, or Magic Item'), findsOneWidget);
      expect(find.text('Standard Melee'), findsOneWidget);
      expect(find.text('Damage Cantrip'), findsOneWidget);

      // Select Greatsword
      final greatswordOption = find.text('Greatsword (2d6 Slashing)');
      expect(greatswordOption, findsOneWidget);
      await tester.tap(greatswordOption);
      await tester.pumpAndSettle();

      // Modal closed and weapon applied
      expect(find.text('Select Weapon, Cantrip, or Magic Item'), findsNothing);
      expect(find.text('Greatsword'), findsOneWidget);
    });

    testWidgets('opens picker sheet and selects a damage cantrip', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final equipBtn = find.text('Equip Weapon / Cantrip').first;
      await tester.tap(equipBtn);
      await tester.pumpAndSettle();

      // Search for Fire Bolt in the picker sheet
      final searchField = find.byType(TextField).last;
      await tester.enterText(searchField, 'Fire Bolt');
      await tester.pumpAndSettle();

      // Select Fire Bolt
      final fireBoltOption = find.textContaining('Fire Bolt');
      expect(fireBoltOption, findsWidgets);
      await tester.tap(fireBoltOption.first);
      await tester.pumpAndSettle();

      expect(find.text('Fire Bolt'), findsOneWidget);
    });

    testWidgets('resets build to clean custom when tapping refresh icon in app bar', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Tap refresh
      final refreshBtn = find.byIcon(Icons.refresh);
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(find.text('Attacks, Weapons & Cantrips'), findsOneWidget);
      expect(find.text('Lv 5'), findsOneWidget);
    });

    testWidgets('adjusts target AC when pressing + / - buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('AC 15'), findsOneWidget);

      // Tap + button
      final plusButton = find.byIcon(Icons.add_circle_outline);
      expect(plusButton, findsOneWidget);

      await tester.ensureVisible(plusButton);
      await tester.tap(plusButton);
      await tester.pumpAndSettle();

      expect(find.text('AC 16'), findsOneWidget);
    });

    testWidgets('opens 5e DPR Math Guide dialog when tapping info icon', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final infoBtn = find.byIcon(Icons.info_outline);
      expect(infoBtn, findsOneWidget);

      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('5e DPR Math Guide'), findsOneWidget);
      expect(find.textContaining('Core Formula for Damage Per Round (DPR):'), findsOneWidget);

      final closeBtn = find.text('Close');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Core Formula for Damage Per Round (DPR):'), findsNothing);
    });

    testWidgets('filters modifiers strictly by edition and unlocks all with Anything Goes', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen(edition: DmRulesEdition.v2024));
      await tester.pumpAndSettle();

      // By default in 2024 mode: 2024 options are shown, 2014 GWM is hidden
      expect(find.textContaining('GWM 2024'), findsOneWidget);
      expect(find.textContaining('GWF 2024'), findsOneWidget);
      expect(find.text('GWM 2014 (-5/+10)'), findsNothing);
      expect(find.text('GWF 2014 (Reroll 1s & 2s)'), findsNothing);

      // Tap Anything Goes filter chip
      final anythingGoesChip = find.text('Anything Goes');
      expect(anythingGoesChip, findsOneWidget);
      await tester.tap(anythingGoesChip);
      await tester.pumpAndSettle();

      // Now both 2014 and 2024 options are visible simultaneously
      expect(find.textContaining('GWM 2024'), findsOneWidget);
      expect(find.textContaining('GWF 2024'), findsOneWidget);
      expect(find.text('GWM 2014 (-5/+10)'), findsOneWidget);
      expect(find.text('GWF 2014 (Reroll 1s & 2s)'), findsOneWidget);
    });

    testWidgets('toggles Agonizing Blast chip to add ability modifier damage', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen(edition: DmRulesEdition.v2024));
      await tester.pumpAndSettle();

      // Open picker and search for Eldritch Blast
      final equipBtn = find.text('Equip Weapon / Cantrip').first;
      await tester.tap(equipBtn);
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).last;
      await tester.enterText(searchField, 'Eldritch Blast');
      await tester.pumpAndSettle();

      final ebPreset = find.textContaining('Eldritch Blast').first;
      await tester.tap(ebPreset);
      await tester.pumpAndSettle();

      // Agonizing Blast toggle chip should now appear
      final agonizingChip = find.textContaining('Agonizing Blast (+');
      expect(agonizingChip, findsOneWidget);

      await tester.tap(agonizingChip, warnIfMissed: false);
      await tester.pumpAndSettle();
    });

    testWidgets('switches between chart modes and adjusts AC scale presets & zoom', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Test Scale Presets
      expect(find.text('8–25 5e'), findsOneWidget);
      expect(find.text('10–20 Focus'), findsOneWidget);
      expect(find.text('5–30 Epic'), findsOneWidget);

      // Switch to Focus scale
      await tester.tap(find.text('10–20 Focus'));
      await tester.pumpAndSettle();

      // Switch to Epic scale
      await tester.tap(find.text('5–30 Epic'));
      await tester.pumpAndSettle();

      // Zoom In and Out buttons
      final zoomInBtn = find.byIcon(Icons.zoom_in);
      final zoomOutBtn = find.byIcon(Icons.zoom_out);
      expect(zoomInBtn, findsOneWidget);
      expect(zoomOutBtn, findsOneWidget);

      await tester.tap(zoomInBtn);
      await tester.pumpAndSettle();

      await tester.tap(zoomOutBtn);
      await tester.pumpAndSettle();

      // Center on Target AC
      final centerBtn = find.byIcon(Icons.center_focus_strong);
      expect(centerBtn, findsOneWidget);
      await tester.tap(centerBtn);
      await tester.pumpAndSettle();

      // Toggle Advantage and Disadvantage
      final advChip = find.text('Advantage');
      expect(advChip, findsOneWidget);
      await tester.tap(advChip);
      await tester.pumpAndSettle();

      final disadvChip = find.text('Disadvantage');
      expect(disadvChip, findsOneWidget);
      await tester.tap(disadvChip);
      await tester.pumpAndSettle();
      final accuracySegment = find.byIcon(Icons.percent);
      expect(accuracySegment, findsOneWidget);
      await tester.tap(accuracySegment);
      await tester.pumpAndSettle();

      expect(find.text('Accuracy & Hit Rate % vs AC'), findsOneWidget);
      expect(find.text('Normal Hit %'), findsOneWidget);
      expect(find.text('Crit %'), findsOneWidget);

      // Switch to Damage on Hit Breakdown mode
      final breakdownSegment = find.byIcon(Icons.stacked_bar_chart);
      expect(breakdownSegment, findsOneWidget);
      await tester.tap(breakdownSegment);
      await tester.pumpAndSettle();

      expect(find.text('Damage on Hit vs Miss (Breakdown)'), findsOneWidget);
      expect(find.text('Regular Hit Damage'), findsOneWidget);
      expect(find.text('Critical Hit Damage'), findsOneWidget);
    });
  });
}
