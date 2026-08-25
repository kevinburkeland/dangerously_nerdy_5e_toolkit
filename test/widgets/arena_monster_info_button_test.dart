import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_clash_stage.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_combatant_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_monster_picker_sheet.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/creature_stat_block_dialog.dart';

void main() {
  group('Arena Monster Info Dots & Codex Dialog Tests', () {
    testWidgets('ArenaMonsterPickerSheet renders info dot button and opens CreatureStatBlockDialog', (tester) async {
      MonsterItem? selectedMonster;
      int? selectedCount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaMonsterPickerSheet(
              team: ArenaTeam.teamA,
              edition: DmRulesEdition.v2024,
              onMonstersSelected: (monster, count) {
                selectedMonster = monster;
                selectedCount = count;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstMonster = MonsterCodexLibrary.allMonsters.first;
      final firstName = firstMonster.getName(DmRulesEdition.v2024);

      // Find an info button with tooltip containing Codex Card
      final infoButtons = find.byTooltip('$firstName Codex Card');
      expect(infoButtons, findsOneWidget);

      // Tap info button for first monster
      await tester.tap(infoButtons);
      await tester.pumpAndSettle();

      // Verify CreatureStatBlockDialog opened
      expect(find.byType(CreatureStatBlockDialog), findsOneWidget);
      expect(find.text('5E SRD CREATURE STAT BLOCK'), findsOneWidget);
      expect(find.widgetWithText(CreatureStatBlockDialog, firstName), findsOneWidget);
      expect(find.text('ADD TO TEAM CRIMSON'), findsOneWidget);

      // Tap ADD TO TEAM CRIMSON
      await tester.tap(find.text('ADD TO TEAM CRIMSON'));
      await tester.pumpAndSettle();

      expect(selectedMonster?.id, firstMonster.id);
      expect(selectedCount, 1);
    });

    testWidgets('ArenaCombatantCard in setup mode renders info button and opens CreatureStatBlockDialog', (tester) async {
      final tRex = MonsterCodexLibrary.getMonsterById('srd_mon_tyrannosaurus_rex')!;
      final combatant = ArenaCombatant.fromMonster(
        id: 'team_a_trex_1',
        monster: tRex,
        team: ArenaTeam.teamA,
        customName: 'Tyrannosaurus Rex #1',
        edition: DmRulesEdition.v2024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaCombatantCard(
              combatant: combatant,
              isSetupMode: true,
              edition: DmRulesEdition.v2024,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find info button
      final infoBtn = find.byTooltip('Tyrannosaurus Rex #1 Codex Card');
      expect(infoBtn, findsOneWidget);

      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      // Verify CreatureStatBlockDialog opened
      expect(find.byType(CreatureStatBlockDialog), findsOneWidget);
      expect(find.widgetWithText(CreatureStatBlockDialog, 'Tyrannosaurus Rex'), findsOneWidget);
    });

    testWidgets('ArenaCombatantCard in battle mode renders info button and opens CreatureStatBlockDialog', (tester) async {
      final wolf = MonsterCodexLibrary.getMonsterById('srd_mon_wolf')!;
      final combatant = ArenaCombatant.fromMonster(
        id: 'team_b_wolf_1',
        monster: wolf,
        team: ArenaTeam.teamB,
        customName: 'Wolf #1',
        edition: DmRulesEdition.v2024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaCombatantCard(
              combatant: combatant,
              isSetupMode: false,
              edition: DmRulesEdition.v2024,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final infoBtn = find.byTooltip('Wolf #1 Codex Card');
      expect(infoBtn, findsOneWidget);

      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CreatureStatBlockDialog), findsOneWidget);
      expect(find.widgetWithText(CreatureStatBlockDialog, 'Wolf'), findsOneWidget);
    });

    testWidgets('ArenaClashStage renders attacker and defender info dots and opens CreatureStatBlockDialog', (tester) async {
      final tRex = MonsterCodexLibrary.getMonsterById('srd_mon_tyrannosaurus_rex')!;
      final wolf = MonsterCodexLibrary.getMonsterById('srd_mon_wolf')!;

      final attacker = ArenaCombatant.fromMonster(
        id: 'team_a_trex_1',
        monster: tRex,
        team: ArenaTeam.teamA,
        customName: 'Tyrannosaurus Rex #1',
        edition: DmRulesEdition.v2024,
      );
      final defender = ArenaCombatant.fromMonster(
        id: 'team_b_wolf_1',
        monster: wolf,
        team: ArenaTeam.teamB,
        customName: 'Wolf #1',
        edition: DmRulesEdition.v2024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArenaClashStage(
              currentStep: null,
              activeAttacker: attacker,
              activeDefender: defender,
              isPlaying: false,
              playbackSpeed: 1.0,
              edition: DmRulesEdition.v2024,
              environment: ArenaEnvironment.colosseum,
              onTogglePlay: () {},
              onStepForward: () {},
              onSkipToEnd: () {},
              onResetMatch: () {},
              onSpeedChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Info icons are present on stage
      final infoIcons = find.byIcon(Icons.info_outline);
      expect(infoIcons, findsWidgets);

      // Tap first info icon (attacker)
      await tester.tap(infoIcons.first);
      await tester.pumpAndSettle();

      expect(find.byType(CreatureStatBlockDialog), findsOneWidget);
      expect(find.widgetWithText(CreatureStatBlockDialog, 'Tyrannosaurus Rex'), findsOneWidget);
    });
  });
}
