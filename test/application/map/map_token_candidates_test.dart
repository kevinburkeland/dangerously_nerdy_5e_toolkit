import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_candidates.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';

void main() {
  group('MapTokenCandidatesSuite', () {
    test('TC1: tokenCandidates lists active roster, combatants, and minions in correct order with suggested labels', () {
      const mapSha1 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const mapSha2 = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
      const ts100 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
      const ts200 = HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1');

      // 1. Roster: two active slugs, one removed
      var roster = const CrdtOrSet<String>.empty();
      roster = roster.add('slug_thorin', 'slug_thorin', ts100);
      roster = roster.add('slug_plain', 'slug_plain', ts100);
      roster = roster.add('slug_removed', 'slug_removed', ts100);
      roster = roster.remove('slug_removed', ts200);

      // Character names (telemetry)
      final characterNames = {
        'slug_thorin': '  Thorin Oakenshield  ',
        'slug_removed': 'Removed Guy',
      };

      // 2. Combatants: two active
      var encounter = const CrdtOrSet<EncounterParticipant>.empty();
      encounter = encounter.add(
        'c_orc',
        EncounterParticipant(
          participantId: 'c_orc',
          entityLink: RoomEntityLink(entityId: 'e1', displayName: ' Orc Raider '),
        ),
        ts100,
      );
      encounter = encounter.add(
        'c_empty',
        EncounterParticipant(
          participantId: 'c_empty',
          entityLink: RoomEntityLink(entityId: 'e2', displayName: '   '),
        ),
        ts100,
      );

      // 3. Minions: two active (one MinionInstance, one plain map), one removed
      var minions = const CrdtOrSet<dynamic>.empty();
      final minionInst = MinionInstance(
        id: 'min_goblin',
        name: ' goblin ',
        size: EntitySize.small,
      );
      minions = minions.add('min_goblin', minionInst, ts100);
      minions = minions.add('min_plain', {'id': 'min_plain', 'name': 'Wolf'}, ts100);
      minions = minions.add('min_removed', MinionInstance(id: 'min_removed', name: 'Dead', size: EntitySize.small), ts100);
      minions = minions.remove('min_removed', ts200);

      // Profile
      var profile = CampaignProfile.raw(
        id: 'camp_tc1',
        nameRegister: const CrdtLwwRegister<String>(value: 'Camp', timestamp: ts100),
        notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: ts100),
        partyRoster: roster,
        roomState: const RoomNodeState.empty().copyWith(
          activeEncounter: encounter,
          activeMinions: minions,
        ),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
      );

      String tokId(int i) => 'tok_${i.toRadixString(16).padLeft(32, '0')}';

      // Add a token with label 'G' already on mapSha1
      profile = profile.withTokenPlaced(
        MapToken(
          id: tokId(1),
          mapSha256Hex: mapSha1,
          kind: MapTokenKind.monster,
          refId: 'other_ref',
          label: 'G',
        ),
        MapTokenCell(col: 0, row: 0),
        ts100,
      );

      // Place token for slug_thorin on this map (mapSha1) -> onThisMap: true
      profile = profile.withTokenPlaced(
        MapToken(
          id: tokId(2),
          mapSha256Hex: mapSha1,
          kind: MapTokenKind.character,
          refId: 'slug_thorin',
          label: 'TH',
        ),
        MapTokenCell(col: 1, row: 1),
        ts100,
      );

      // Place token for min_goblin on another map (mapSha2) -> onThisMap: false
      profile = profile.withTokenPlaced(
        MapToken(
          id: tokId(3),
          mapSha256Hex: mapSha2,
          kind: MapTokenKind.minion,
          refId: 'min_goblin',
          label: 'G',
        ),
        MapTokenCell(col: 2, row: 2),
        ts100,
      );

      // Place and remove token for c_orc on this map -> onThisMap: false
      profile = profile.withTokenPlaced(
        MapToken(
          id: tokId(4),
          mapSha256Hex: mapSha1,
          kind: MapTokenKind.monster,
          refId: 'c_orc',
          label: 'OR',
        ),
        MapTokenCell(col: 3, row: 3),
        ts100,
      );
      profile = profile.withTokenRemoved(tokId(4), ts200);

      final candidates = tokenCandidates(profile, mapSha1, characterNames);

      // 6 active items:
      // Characters: slug_plain ('slug_plain'), slug_thorin ('Thorin Oakenshield')
      // Combatants: c_orc ('Orc Raider'), c_empty ('c_empty')
      // Minions: min_goblin ('goblin'), min_plain ('min_plain')
      expect(candidates.length, equals(6));

      // Order: characters, combatants, minions
      // Within characters: 'slug_plain' vs 'Thorin Oakenshield' -> 'slug_plain' (S) comes before 'Thorin Oakenshield' (T)
      expect(candidates[0].kind, equals(MapTokenKind.character));
      expect(candidates[0].refId, equals('slug_plain'));
      expect(candidates[0].name, equals('slug_plain'));
      expect(candidates[0].onThisMap, isFalse);

      expect(candidates[1].kind, equals(MapTokenKind.character));
      expect(candidates[1].refId, equals('slug_thorin'));
      expect(candidates[1].name, equals('Thorin Oakenshield'));
      expect(candidates[1].onThisMap, isTrue);
      expect(candidates[1].suggestedLabel, equals('TO'));

      // Within combatants: 'c_empty' (c_empty) vs 'Orc Raider' (Orc Raider) -> 'c_empty' (C) comes before 'Orc Raider' (O)
      expect(candidates[2].kind, equals(MapTokenKind.monster));
      expect(candidates[2].refId, equals('c_empty'));
      expect(candidates[2].name, equals('c_empty'));
      expect(candidates[2].onThisMap, isFalse);

      expect(candidates[3].kind, equals(MapTokenKind.monster));
      expect(candidates[3].refId, equals('c_orc'));
      expect(candidates[3].name, equals('Orc Raider'));
      expect(candidates[3].onThisMap, isFalse);

      // Within minions: 'goblin' (G) vs 'min_plain' (M) -> 'goblin' comes before 'min_plain'
      expect(candidates[4].kind, equals(MapTokenKind.minion));
      expect(candidates[4].refId, equals('min_goblin'));
      expect(candidates[4].name, equals('goblin'));
      expect(candidates[4].onThisMap, isFalse);
      // 'G' is taken on mapSha1, so suggestedLabel must be 'G2'
      expect(candidates[4].suggestedLabel, equals('G2'));

      expect(candidates[5].kind, equals(MapTokenKind.minion));
      expect(candidates[5].refId, equals('min_plain'));
      expect(candidates[5].name, equals('min_plain'));
      expect(candidates[5].onThisMap, isFalse);

      // List is unmodifiable
      expect(
        () => candidates.add(candidates[0]),
        throwsUnsupportedError,
      );
    });
  });
}
