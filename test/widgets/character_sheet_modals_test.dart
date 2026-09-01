import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/feature_list_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/spell_list_item.dart';

void main() {
  testWidgets('FeatureListItem renders and opens bottom sheet modal with Semantics', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeatureListItem(
            name: 'Action Surge',
            source: 'Fighter Feature',
            descriptionMarkdown: 'You can push yourself beyond your normal limits for a moment. On your turn, you can take one additional action.',
          ),
        ),
      ),
    );

    expect(find.text('Action Surge'), findsOneWidget);
    expect(find.text('Fighter Feature'), findsOneWidget);

    // Tap to open modal
    await tester.tap(find.text('Action Surge'));
    await tester.pumpAndSettle();

    // Verify modal content
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('You can push yourself beyond your normal limits'), findsOneWidget);

    // Verify semantics header
    final semanticsFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label?.contains('Feature Details: Action Surge') == true,
    );
    expect(semanticsFinder, findsOneWidget);
  });

  testWidgets('SpellListItem renders and opens spell detail modal', (tester) async {
    const testSpell = Spell(
      id: EntityId(slug: 'shield', ruleset: RulesetVersion.v2024),
      name: 'Shield',
      level: 1,
      school: 'abjuration',
      castingTime: CastingTime(cost: 1, actionType: ActionType.reaction, triggerCondition: 'when hit by an attack'),
      range: 'Self',
      components: SpellComponents(v: true, s: true),
      duration: SpellDuration(type: DurationType.timed, durationSeconds: 6, rawText: '1 round'),
      descriptionMarkdown: 'An invisible barrier of magical force appears and protects you. Until the start of your next turn, you have a +5 bonus to AC.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpellListItem(
            spell: testSpell,
            isPrepared: true,
          ),
        ),
      ),
    );

    expect(find.text('Shield'), findsOneWidget);
    expect(find.text('Lvl 1'), findsOneWidget);

    // Tap to open modal
    await tester.tap(find.text('Shield'));
    await tester.pumpAndSettle();

    // Verify modal content
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('1 reaction (when hit by an attack)'), findsOneWidget);
    expect(find.text('Self'), findsOneWidget);
    expect(find.textContaining('An invisible barrier of magical force appears'), findsOneWidget);

    // Verify semantics header
    final semanticsFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label?.contains('Spell Details: Shield') == true,
    );
    expect(semanticsFinder, findsOneWidget);
  });
}
