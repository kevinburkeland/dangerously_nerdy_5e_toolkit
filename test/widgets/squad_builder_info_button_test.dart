import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spell_session.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/creature_stat_block_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/minions/squad_builder.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spell_reference.dart';

void main() {
  testWidgets('SquadBuilderBottomSheet displays creature stat block info button that opens full stat block dialog', (WidgetTester tester) async {
    final session = SpellSession(
      activePreset: BeastSummons.conjureAnimalsPreset,
      spellLevel: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquadBuilderBottomSheet(
            session: session,
            onSquadUpdated: () {},
          ),
        ),
      ),
    );

    // Verify info button is rendered for Wolf
    final wolfInfoBtn = find.byTooltip('Wolf Full Stat Block');
    expect(wolfInfoBtn, findsOneWidget);

    await tester.ensureVisible(wolfInfoBtn);
    await tester.pumpAndSettle();
    await tester.tap(wolfInfoBtn);
    await tester.pumpAndSettle();

    // Verify CreatureStatBlockDialog opened
    expect(find.byType(CreatureStatBlockDialog), findsOneWidget);
    expect(find.text('5E SRD CREATURE STAT BLOCK'), findsOneWidget);
    expect(find.widgetWithText(CreatureStatBlockDialog, 'Wolf'), findsOneWidget);
    expect(find.text('ADD TO SQUAD'), findsOneWidget);

    // Tap ADD TO SQUAD from inside dialog
    await tester.tap(find.text('ADD TO SQUAD'));
    await tester.pumpAndSettle();

    expect(session.activeObjects.length, 1);
    expect(session.activeObjects.first.name, 'Wolf #1');
  });

  testWidgets('SpellReferenceWidget creature profile card displays stat block button that opens full stat block dialog', (WidgetTester tester) async {
    final undeadPreset = SrdSummonsLibrary.allPresets.firstWhere((p) => p.id == 'animate_dead');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpellReferenceWidget(initialPreset: undeadPreset),
        ),
      ),
    );

    expect(find.text('ANIMATE DEAD CREATURE PROFILES'), findsOneWidget);
    final statBlockBtn = find.text('STAT BLOCK').first;
    expect(statBlockBtn, findsOneWidget);

    await tester.ensureVisible(statBlockBtn);
    await tester.pumpAndSettle();
    await tester.tap(statBlockBtn);
    await tester.pumpAndSettle();

    expect(find.byType(CreatureStatBlockDialog), findsOneWidget);
    expect(find.widgetWithText(CreatureStatBlockDialog, 'Skeleton'), findsOneWidget);
    expect(find.text('Medium undead, lawful evil'), findsOneWidget);
  });
}
