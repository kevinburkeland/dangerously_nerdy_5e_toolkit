import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/minion_tool_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dice_roller_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/minion_session_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MinionSessionService().clearCacheForTesting();
  });

  tearDown(() {
    MinionSessionService().clearCacheForTesting();
  });

  Widget createTestableApp() {
    return const MaterialApp(
      home: LandingScreen(),
    );
  }

  testWidgets('Upcasting spell level and adding minions persists when navigating to Dice Roller and back', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestableApp());

    // 1. Launch Conjure Animals
    final conjureAnimalsCard = find.text('Conjure Animals');
    expect(conjureAnimalsCard, findsOneWidget);
    await tester.ensureVisible(conjureAnimalsCard);
    await tester.pumpAndSettle();
    await tester.tap(conjureAnimalsCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);
    expect(find.text('Slot Lvl 3'), findsOneWidget);
    expect(find.text('8 Objects'), findsOneWidget);

    // 2. Change Spell Slot from Level 3 to Level 5 (Upcast)
    final dropdown = find.byType(DropdownButton<int>);
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final slot5Item = find.text('Slot Lvl 5').last;
    await tester.tap(slot5Item);
    await tester.pumpAndSettle();

    expect(find.text('Slot Lvl 5'), findsOneWidget);

    // 3. Open Squad Builder and add +4 Wolves to the squad via quick add
    final assembleBtn = find.widgetWithText(ElevatedButton, 'Add');
    expect(assembleBtn, findsOneWidget);
    await tester.tap(assembleBtn);
    await tester.pumpAndSettle();

    final addWolfChip = find.text('+1 Wolf');
    expect(addWolfChip, findsOneWidget);
    for (int i = 0; i < 4; i++) {
      await tester.tap(addWolfChip);
      await tester.pumpAndSettle();
    }

    // Close bottom sheet
    Navigator.of(tester.element(addWolfChip)).pop();
    await tester.pumpAndSettle();

    // Verify 12 Objects are now in the squad
    expect(find.text('12 Objects'), findsOneWidget);

    // 4. Navigate back to Landing Screen
    final backBtn = find.byTooltip('Back to Hub');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(find.byType(LandingScreen), findsOneWidget);

    // 5. Navigate to Dice Roller & Party Rooms
    final diceRollerCard = find.text('Dice Roller & Party Rooms');
    expect(diceRollerCard, findsOneWidget);
    await tester.ensureVisible(diceRollerCard);
    await tester.pumpAndSettle();
    await tester.tap(diceRollerCard);
    await tester.pumpAndSettle();

    expect(find.byType(DiceRollerScreen), findsOneWidget);

    // 6. Navigate back from Dice Roller to Landing Screen
    final rollerBackBtn = find.byType(BackButton);
    if (rollerBackBtn.evaluate().isNotEmpty) {
      await tester.tap(rollerBackBtn);
    } else {
      final backIcon = find.byIcon(Icons.arrow_back);
      await tester.tap(backIcon);
    }
    await tester.pumpAndSettle();

    expect(find.byType(LandingScreen), findsOneWidget);

    // 7. Re-open Conjure Animals
    await tester.ensureVisible(conjureAnimalsCard);
    await tester.pumpAndSettle();
    await tester.tap(conjureAnimalsCard);
    await tester.pumpAndSettle();

    expect(find.byType(MinionToolScreen), findsOneWidget);

    // Verify spell level and all added creatures PERSISTED!
    expect(find.text('Slot Lvl 5'), findsOneWidget);
    expect(find.text('12 Objects'), findsOneWidget);
    expect(find.text('Wolf #1'), findsOneWidget);
  });
}
