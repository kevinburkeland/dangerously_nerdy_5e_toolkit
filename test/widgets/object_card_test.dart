import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/set_object_hp_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/minions/object_card.dart';

void main() {
  Widget buildTestCard({
    required AnimatedObjectInstance object,
    VoidCallback? onDelete,
    Function(int delta)? onHpChanged,
    Function(String name)? onNameChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: ObjectCard(
          object: object,
          onDelete: onDelete ?? () {},
          onHpChanged: onHpChanged ?? (_) {},
          onNameChanged: onNameChanged ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('ObjectCard displays 1-second combat HUD and handles HP modifications', (WidgetTester tester) async {
    final obj = AnimatedObjectInstance(
      id: 'coin_1',
      name: 'Silver Coin #1',
      size: ObjectSize.tiny,
      currentHp: 20,
      maxHp: 20,
    );

    int hpDelta = 0;
    await tester.pumpWidget(buildTestCard(
      object: obj,
      onHpChanged: (delta) => hpDelta = delta,
    ));

    // Name & Size pill
    expect(find.text('Silver Coin #1'), findsOneWidget);
    expect(find.text('TINY (1pt)'), findsOneWidget);

    // 1-second stat HUD labels and values
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('18'), findsNWidgets(2)); // AC 18 and DEX 18
    expect(find.text('TO HIT'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
    expect(find.text('DMG'), findsOneWidget);
    expect(find.text('1d4+4 Bludgeoning'), findsOneWidget);
    expect(find.text('STR'), findsOneWidget);
    expect(find.text('DEX'), findsOneWidget);

    // Current HP
    expect(find.text('HP: 20 / 20'), findsOneWidget);

    // Tap decrement HP button
    final minusBtn = find.byTooltip('-1 HP');
    expect(minusBtn, findsOneWidget);
    await tester.tap(minusBtn);
    expect(hpDelta, -1);
  });

  testWidgets('ObjectCard displays DESTROYED badge when object is dead', (WidgetTester tester) async {
    final deadObj = AnimatedObjectInstance(
      id: 'coin_dead',
      name: 'Broken Coin',
      size: ObjectSize.tiny,
      currentHp: 0,
      maxHp: 20,
    );

    await tester.pumpWidget(buildTestCard(object: deadObj));

    expect(find.text('💀 DESTROYED'), findsOneWidget);
  });

  testWidgets('ObjectCard displays TEMP badge when temp HP is active', (WidgetTester tester) async {
    final tempObj = AnimatedObjectInstance(
      id: 'coin_temp',
      name: 'Shielded Coin',
      size: ObjectSize.tiny,
      currentHp: 20,
      maxHp: 20,
      tempHp: 5,
    );

    await tester.pumpWidget(buildTestCard(object: tempObj));

    expect(find.text('+5 TEMP'), findsOneWidget);
  });

  testWidgets('SetObjectHpDialog allocates bonus health in excess of cap to temp HP', (WidgetTester tester) async {
    SetObjectHpResult? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await SetObjectHpDialog.show(
                  context,
                  objectName: 'Silver Coin #1',
                  currentHp: 20,
                  maxHp: 20,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Enter 25 HP for a creature with 20 Max HP
    final hpField = find.widgetWithText(TextField, 'Current HP (Max 20)');
    await tester.enterText(hpField, '25');

    // Tap Save HP
    await tester.tap(find.text('Save HP'));
    await tester.pumpAndSettle();

    expect(dialogResult, isNotNull);
    expect(dialogResult!.currentHp, 20);
    expect(dialogResult!.tempHp, 5); // 25 - 20 = 5 bonus HP allocated as temp HP!
  });
}
