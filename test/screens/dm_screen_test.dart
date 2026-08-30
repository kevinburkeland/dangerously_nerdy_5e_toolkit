import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_reference_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestableWidget(Widget child, {SettingsProvider? provider}) {
    final settingsProvider = provider ?? SettingsProvider();
    return SettingsScope(
      notifier: settingsProvider,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('DmReferenceScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    testWidgets('renders Rules Compendium with title, quick roller, and cards', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));

      expect(find.text("Rules Compendium"), findsOneWidget);
      expect(find.text('Quick Roller:'), findsOneWidget);
      expect(find.text('d20'), findsOneWidget);
      expect(find.text('d100'), findsOneWidget);
      expect(find.text('All Rules'), findsOneWidget);

      // Verify some cards are rendered
      expect(find.text('Attack Action & Extra Attack'), findsOneWidget);
      expect(find.textContaining('Cast a Spell'), findsOneWidget);
    });

    testWidgets('toggling between 2014 and 2024 updates rule display', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen(initialEdition: DmRulesEdition.v2024)));

      expect(find.text('Active: 2024 Revised'), findsOneWidget);
      expect(find.text('2024 Revised 5e Rulebook'), findsOneWidget);

      // Tap 2014 button
      final btn2014 = find.text('2014');
      expect(btn2014, findsOneWidget);
      await tester.tap(btn2014);
      await tester.pumpAndSettle();

      expect(find.text('Active: 2014 5e RAW'), findsOneWidget);
      expect(find.text('2014 (SRD 5.1 RAW) Rulebook'), findsOneWidget);
    });

    testWidgets('filtering by search query filters cards dynamically', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Exhaustion');
      await tester.pumpAndSettle();

      expect(find.text('Exhaustion (Fatigue)'), findsOneWidget);
      expect(find.text('Attack Action & Extra Attack'), findsNothing);
    });

    testWidgets('tapping quick dice rolls a result and displays banner', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));

      final d20Btn = find.text('d20');
      await tester.tap(d20Btn);
      await tester.pumpAndSettle();

      expect(find.textContaining('d20: '), findsOneWidget);
    });

    testWidgets('tapping card opens Compare 2014 vs 2024 dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));

      final attackCard = find.text('Attack Action & Extra Attack');
      expect(attackCard, findsOneWidget);

      await tester.tap(attackCard);
      await tester.pumpAndSettle();

      expect(find.text('2014 vs 2024 Rule Comparison'), findsOneWidget);
      expect(find.text('2014 (5e RAW)'), findsOneWidget);
      expect(find.text('2024 (Revised 5e)'), findsOneWidget);

      // Close dialog
      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('2014 vs 2024 Rule Comparison'), findsNothing);
    });

    testWidgets('tapping pin button on card pins rule to top section', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));

      // Initially no Pinned section header
      expect(find.textContaining('PINNED RULES'), findsNothing);

      // Find all pin buttons
      final pinButtons = find.byTooltip('Pin rule to top');
      expect(pinButtons, findsWidgets);

      // Tap first pin button
      await tester.tap(pinButtons.first);
      await tester.pumpAndSettle();

      // Now PINNED RULES section is displayed
      expect(find.text('PINNED RULES (1)'), findsOneWidget);
      expect(find.text('Unpin All'), findsOneWidget);

      // Tap unpin on the card
      final unpinButton = find.byTooltip('Unpin rule from top');
      expect(unpinButton, findsOneWidget);
      await tester.tap(unpinButton);
      await tester.pumpAndSettle();

      // Pinned section is gone
      expect(find.textContaining('PINNED RULES'), findsNothing);
    });

    testWidgets('Unpin All button clears all pinned rules', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));
      await tester.pumpAndSettle();

      // Pin first two cards
      final pinButtons = find.byTooltip('Pin rule to top');
      await tester.tap(pinButtons.at(0));
      await tester.pumpAndSettle();

      final remainingPinButtons = find.byTooltip('Pin rule to top');
      await tester.tap(remainingPinButtons.at(0));
      await tester.pumpAndSettle();

      expect(find.text('PINNED RULES (2)'), findsOneWidget);

      // Tap Unpin All
      final unpinAll = find.text('Unpin All');
      await tester.tap(unpinAll);
      await tester.pumpAndSettle();

      expect(find.textContaining('PINNED RULES'), findsNothing);
    });

    testWidgets('Pinned Only filter chip filters to only pinned rules', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));
      await tester.pumpAndSettle();

      final pinButton = find.byTooltip('Pin rule to top').first;
      await tester.tap(pinButton);
      await tester.pumpAndSettle();

      expect(find.text('PINNED RULES (1)'), findsOneWidget);

      // Tap Pinned Only filter chip
      final pinnedOnlyChip = find.text('Pinned Only (1)');
      expect(pinnedOnlyChip, findsOneWidget);
      await tester.tap(pinnedOnlyChip);
      await tester.pumpAndSettle();

      // Pinned section is showing and other rules section is hidden
      expect(find.text('PINNED RULES (1)'), findsOneWidget);
      expect(find.textContaining('ALL RULES'), findsNothing);
    });

    testWidgets('pin button inside compare dialog toggles pinned state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(const DmReferenceScreen()));

      final attackCard = find.text('Attack Action & Extra Attack');
      await tester.tap(attackCard);
      await tester.pumpAndSettle();

      // Find pin button in dialog
      final dialogPinBtn = find.descendant(
        of: find.byType(Dialog),
        matching: find.byTooltip('Pin rule to top'),
      );
      expect(dialogPinBtn, findsOneWidget);

      // Tap pin button in dialog
      await tester.tap(dialogPinBtn);
      await tester.pumpAndSettle();

      // Now tooltip should update to unpin
      expect(find.descendant(of: find.byType(Dialog), matching: find.byTooltip('Unpin rule')), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify rule is in Pinned section
      expect(find.text('PINNED RULES (1)'), findsOneWidget);
    });

    testWidgets('LandingScreen launches DmReferenceScreen from card and AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const LandingScreen()));

      // Find Rules Compendium tool card
      final rulesCard = find.widgetWithText(Card, 'Rules Compendium');
      expect(rulesCard, findsOneWidget);

      await tester.ensureVisible(rulesCard);
      await tester.pumpAndSettle();

      await tester.tap(rulesCard);
      await tester.pumpAndSettle();

      expect(find.byType(DmReferenceScreen), findsOneWidget);
      expect(find.text("Rules Compendium"), findsOneWidget);
    });
  });
}
