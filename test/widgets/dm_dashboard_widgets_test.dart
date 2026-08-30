import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_dashboard/dm_dashboard_encounter_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_dashboard/dm_dashboard_minion_hud.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_dashboard/dm_dashboard_party_hud.dart';

void main() {
  group('DmDashboardEncounterCard Widget Tests', () {
    testWidgets('renders combatant details, initiative, and HP', (tester) async {
      const participant = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'goblin',
          displayName: 'Goblin Boss',
        ),
        initiativeScore: 18,
        currentHp: 15,
        maxHp: 21,
        armorClass: 15,
        activeConditions: ['Poisoned'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DmDashboardEncounterCard(participant: participant),
          ),
        ),
      );

      expect(find.text('Goblin Boss'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('15 / 21'), findsOneWidget);
      expect(find.text('Poisoned'), findsOneWidget);
    });

    testWidgets('opens HP adjustment dialog on HP button tap', (tester) async {
      int? deltaReceived;
      const participant = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'goblin',
          displayName: 'Goblin',
        ),
        initiativeScore: 12,
        currentHp: 10,
        maxHp: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmDashboardEncounterCard(
              participant: participant,
              onApplyHpDelta: (delta) => deltaReceived = delta,
            ),
          ),
        ),
      );

      await tester.tap(find.text('10 / 10'));
      await tester.pumpAndSettle();

      expect(find.text('Adjust HP: Goblin'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('Damage'));
      await tester.pumpAndSettle();

      expect(deltaReceived, equals(-4));
    });
  });

  group('DmDashboardPartyHud Widget Tests', () {
    testWidgets('renders empty state when roster is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DmDashboardPartyHud(partyRoster: []),
          ),
        ),
      );

      expect(find.text('No Party Members Enrolled'), findsOneWidget);
    });

    testWidgets('renders party member vitals and AC', (tester) async {
      final character = Character(
        id: const EntityId(slug: 'valeros', ruleset: RulesetVersion.v2024),
        name: 'Valeros',
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 5,
              hitDie: 'd10',
              hitPointsRolled: [10, 6, 6, 6, 6],
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        resources: const CharacterResourcePool(
          currentHp: 44,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmDashboardPartyHud(partyRoster: [character]),
          ),
        ),
      );

      expect(find.text('Valeros'), findsOneWidget);
      expect(find.text('Lvl 5 Fighter'), findsOneWidget);
      expect(find.textContaining('AC'), findsOneWidget);
      expect(find.textContaining('PP'), findsOneWidget);
    });
  });

  group('DmDashboardMinionHud Widget Tests', () {
    testWidgets('renders empty state when minion list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DmDashboardMinionHud(activeMinions: []),
          ),
        ),
      );

      expect(find.text('No Active Summons or Minions'), findsOneWidget);
    });

    testWidgets('renders active minion card with dismiss button', (tester) async {
      String? dismissedId;
      final minion = AnimatedObjectInstance(
        id: 'minion_1',
        name: 'Tiny Dagger #1',
        size: ObjectSize.tiny,
        currentHp: 20,
        maxHp: 20,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DmDashboardMinionHud(
              activeMinions: [minion],
              onRemoveMinion: (id) => dismissedId = id,
            ),
          ),
        ),
      );

      expect(find.text('Tiny Dagger #1'), findsOneWidget);
      expect(find.text('AC 18 • 20/20 HP'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss Minion'));
      expect(dismissedId, equals('minion_1'));
    });
  });
}
