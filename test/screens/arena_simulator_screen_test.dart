import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/arena_simulator_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

void main() {
  Widget buildTestableScreen() {
    return MaterialApp(
      theme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        accent: FantasyAccent.paladinGold,
      ),
      home: const ArenaSimulatorScreen(),
    );
  }

  group('ArenaSimulatorScreen Widget Tests', () {
    testWidgets('renders Arena screen with title, presets, and default fighters', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Monster Fighting Arena'), findsOneWidget);
      expect(find.text('Start Battle'), findsOneWidget);
      expect(find.text('Monte Carlo Odds'), findsOneWidget);
      expect(find.text('Team Crimson'), findsWidgets);
      expect(find.text('Team Cobalt'), findsWidgets);

      // Default preset has Tyrannosaurus Rex
      expect(find.text('Tyrannosaurus Rex'), findsWidgets);
    });

    testWidgets('starts battle and advances turns step by step', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Tap Start Battle
      final startBtn = find.text('Start Battle');
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Now in Battle mode, check for stage controls
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Step'), findsOneWidget);
      expect(find.text('Skip to End'), findsOneWidget);

      // Tap Pause to freeze automatic timer
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);

      // Tap Step forward
      await tester.tap(find.text('Step'));
      await tester.pumpAndSettle();

      // Check that Combat Action Log has entries
      expect(find.byIcon(Icons.history_edu), findsOneWidget);
    });

    testWidgets('Skip to End instantly concludes battle and presents victory dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Start Battle
      await tester.tap(find.text('Start Battle'));
      await tester.pumpAndSettle();

      // Tap Skip to End
      final skipBtn = find.text('Skip to End');
      expect(skipBtn, findsOneWidget);
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      // Victory dialog should appear
      expect(find.text('Edit Roster'), findsOneWidget);
      expect(find.text('Rematch'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Edit Roster'));
      await tester.pumpAndSettle();
      expect(find.text('Start Battle'), findsOneWidget);
    });

    testWidgets('opens Monte Carlo dialog and simulates win probabilities', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Tap Monte Carlo Odds button
      final mcBtn = find.text('Monte Carlo Odds');
      expect(mcBtn, findsOneWidget);
      await tester.tap(mcBtn);
      await tester.pumpAndSettle();

      expect(find.text('Monte Carlo Win Probabilities'), findsOneWidget);
      expect(find.text('Total Iterations'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Monster Fighting Arena'), findsOneWidget);
    });

    testWidgets('toggles 2014 and 2024 rules via RulesEditionToggle and opens environment descriptors dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Check RulesEditionToggle exists
      expect(find.text('2014'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);

      // Tap 2014
      await tester.tap(find.text('2014'));
      await tester.pumpAndSettle();

      // Tap 2024
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      // Tap Environment Descriptors info button
      final infoBtn = find.byTooltip('Arena Rules & Descriptors Guide');
      expect(infoBtn, findsOneWidget);
      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      // Environment dialog should show
      expect(find.text('Arena Battlegrounds'), findsOneWidget);
      expect(find.text('Iron Cage Match'), findsOneWidget);
      expect(find.text('Flooded Abyss (Water Match)'), findsOneWidget);
      expect(find.text('Volcanic Caldera'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cleanly without overflow on mobile phone screen (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Mobile screen should show shortened title and toggle
      expect(find.text('Monster Arena'), findsOneWidget);
      expect(find.text('2014'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);

      // Start Battle to verify stage rendered without overflow on mobile
      await tester.tap(find.text('Start Battle'));
      await tester.pumpAndSettle();

      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Step'), findsOneWidget);
    });
  });
}
