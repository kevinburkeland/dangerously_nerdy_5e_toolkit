import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_combatant_token.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_condition_chip.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_condition_toggle_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_combatant_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';

void main() {
  group('ArenaCombatantToken & Condition Chips Widget Tests', () {
    testWidgets('renders ArenaCombatantToken with glyph and condition chips', (tester) async {
      final wolfMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');
      final combatant = ArenaCombatant.fromMonster(
        id: 'token_wolf_1',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
        customName: 'Alpha Wolf',
      );

      combatant.applyActiveCondition(
        const ActiveCondition(condition: ArenaCondition.poisoned, durationRounds: 2),
      );
      combatant.applyActiveCondition(
        const ActiveCondition(condition: ArenaCondition.prone),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArenaCombatantToken(
                combatant: combatant,
                size: 70,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify token is rendered
      expect(find.byType(ArenaCombatantToken), findsOneWidget);
      expect(find.byType(ArenaConditionChipsBar), findsOneWidget);

      // Verify chip short codes are rendered
      expect(find.text('POI'), findsOneWidget);
      expect(find.text('PRN'), findsOneWidget);
      expect(find.text('2r'), findsOneWidget); // Duration badge
    });

    testWidgets('ArenaConditionChipsBar handles overflow with +N badge when >3 conditions active', (tester) async {
      final conditions = [
        const ActiveCondition(condition: ArenaCondition.poisoned),
        const ActiveCondition(condition: ArenaCondition.prone),
        const ActiveCondition(condition: ArenaCondition.stunned),
        const ActiveCondition(condition: ArenaCondition.restrained),
        const ActiveCondition(condition: ArenaCondition.frightened),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArenaConditionChipsBar(
                conditions: conditions,
                maxVisible: 2,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First 2 visible chips rendered
      expect(find.text('POI'), findsOneWidget);
      expect(find.text('PRN'), findsOneWidget);

      // Overflow badge rendered with +3
      expect(find.byType(ArenaConditionOverflowBadge), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('ArenaConditionChip displays tooltip with mechanical penalty reminder', (tester) async {
      const active = ActiveCondition(
        condition: ArenaCondition.prone,
        durationRounds: 1,
        source: 'Trip Attack',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArenaConditionChip(
                activeCondition: active,
                showLabel: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, contains('Prone'));
      expect(tooltip.message, contains('1 round remaining'));
      expect(tooltip.message, contains('Trip Attack'));
      expect(tooltip.message, contains('Disadvantage on attacks'));
    });

    testWidgets('ArenaConditionToggleDialog allows DM to toggle conditions', (tester) async {
      final wolfMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');
      final combatant = ArenaCombatant.fromMonster(
        id: 'toggle_wolf_1',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      bool updated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaConditionToggleDialog(
              combatant: combatant,
              onUpdated: () => updated = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and condition list are shown
      expect(find.textContaining('Status Conditions:'), findsOneWidget);
      expect(find.text('Stunned'), findsOneWidget);

      // Tap on Stunned chip to toggle it on
      await tester.tap(find.text('Stunned'));
      await tester.pumpAndSettle();

      expect(combatant.hasCondition(ArenaCondition.stunned), true);
      expect(updated, true);

      // Verify active condition preview bar now contains Stunned
      expect(find.text('ACTIVE ON TOKEN (Tap to remove):'), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(find.text('Stunned').first);
      await tester.pumpAndSettle();

      expect(combatant.hasCondition(ArenaCondition.stunned), false);
    });

    testWidgets('ArenaCombatantCard renders token and dynamic condition chips in roster', (tester) async {
      final tRex = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('tyrannosaurus'));
      final combatant = ArenaCombatant.fromMonster(
        id: 'card_trex_1',
        monster: tRex,
        team: ArenaTeam.teamA,
      );
      combatant.applyActiveCondition(
        const ActiveCondition(condition: ArenaCondition.blinded),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaCombatantCard(
              combatant: combatant,
              isCurrentTurn: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ArenaCombatantCard), findsOneWidget);
      expect(find.byType(ArenaCombatantToken), findsOneWidget);
      expect(find.text('BLN'), findsOneWidget);
      expect(find.text('TURN'), findsOneWidget);
    });

    testWidgets('LandingScreen renders Monster Fighting Arena tool card with custom DndGlyph', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Monster Fighting Arena'), findsWidgets);
      expect(find.text('Pit Fight Simulator'), findsWidgets);
    });
  });
}
