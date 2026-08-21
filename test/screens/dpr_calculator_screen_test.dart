import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dpr_calculator_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';

void main() {
  Widget buildTestableScreen() {
    return MaterialApp(
      theme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        accent: FantasyAccent.paladinGold,
      ),
      home: const DprCalculatorScreen(),
    );
  }

  group('DprCalculatorScreen Widget Tests', () {
    testWidgets('renders DPR Calculator screen with chart, presets, AC slider, and metrics', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('DPR Calculator & Graph'), findsOneWidget);

      // Presets
      expect(find.text('Level 5 Barbarian (Greatsword + Reckless)'), findsOneWidget);
      expect(find.text('Custom Build'), findsOneWidget);

      // AC Target & Metrics
      expect(find.textContaining('Target Armor Class (AC):'), findsOneWidget);
      expect(find.text('Round DPR'), findsOneWidget);
      expect(find.text('Hit Chance'), findsOneWidget);
      expect(find.text('Crit Chance'), findsOneWidget);

      // Combatant Configurator
      expect(find.text('Combatant & Attack Profile'), findsOneWidget);
      expect(find.text('Add Attack'), findsOneWidget);
    });

    testWidgets('switches presets when tapping on preset chips', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Find and tap Level 5 Fighter chip
      final fighterChip = find.text('Level 5 Fighter (Crossbow Expert + Sharpshooter)');
      expect(fighterChip, findsOneWidget);

      await tester.ensureVisible(fighterChip);
      await tester.tap(fighterChip);
      await tester.pumpAndSettle();

      // Verify that the attack list reflects the fighter attack
      expect(find.text('Hand Crossbow (Action + BA)'), findsOneWidget);
    });

    testWidgets('adjusts target AC when pressing + / - buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Target Armor Class (AC): 15'), findsOneWidget);

      // Tap + button
      final plusButton = find.byIcon(Icons.add_circle_outline);
      expect(plusButton, findsOneWidget);

      await tester.ensureVisible(plusButton);
      await tester.tap(plusButton);
      await tester.pumpAndSettle();

      expect(find.text('Target Armor Class (AC): 16'), findsOneWidget);
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

      expect(find.text('5e DPR Math Guide'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);

      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();

      expect(find.text('5e DPR Math Guide'), findsNothing);
    });
  });
}
