import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_event.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/rules/ruleset_edition.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/session_graph_service.dart';

void main() {
  group('Cold Iron Birdcage — Pass 4.1: Convergence Closure & Deletion Semantics', () {
    late RoomStateReconciliationService reconciliationService;

    setUp(() {
      reconciliationService = RoomStateReconciliationService(
        networkTimeProvider: () => 1700000000000,
      );
    });

    CampaignProfile createSampleProfile({
      String id = 'camp-p4-1',
      String name = 'Test Campaign',
      RulesetEdition edition = RulesetEdition.v2024,
      DateTime? timestamp,
      RoomNodeState? roomState,
      List<String> partyCharacterIds = const ['char-1', 'char-2'],
      Set<String> pinnedRuleIds = const {'cover', 'flanking'},
      List<PartyEvent> changeLog = const [],
    }) {
      final baseTs = timestamp ?? DateTime.utc(2026, 1, 1, 10, 0);
      return CampaignProfile(
        id: id,
        name: name,
        edition: edition,
        createdAt: baseTs,
        lastPlayedAt: baseTs,
        roomState: roomState ??
            RoomNodeState(
              roomId: 'room-1',
              roomCode: 'RC-101',
              title: 'Entry Hall',
            ),
        partyCharacterIds: partyCharacterIds,
        pinnedRuleIds: pinnedRuleIds,
        notesMarkdown: 'Initial briefing.',
        partyPurse: const PartyPurse.empty().modifyDenomination('gp', 100, replicaId: ReplicaId('genesis')),
        changeLog: changeLog,
        nodeId: 'genesis',
      );
    }

    test('AC. Safe reconciliation equals canonical engine join on valid states with empty fieldFaults', () {
      final base = createSampleProfile();

      final evA = PartyEvent(
        id: 'ev-a',
        roomCode: 'RC-101',
        type: 'info',
        playerName: 'Alice',
        details: 'Checked map',
        timestamp: DateTime.utc(2026, 1, 1, 11, 0),
      );
      final evB = PartyEvent(
        id: 'ev-b',
        roomCode: 'RC-101',
        type: 'info',
        playerName: 'Bob',
        details: 'Lit torch',
        timestamp: DateTime.utc(2026, 1, 1, 11, 30),
      );

      final pA = base.copyWith(
        name: 'Test Campaign',
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Alice updated notes',
          timestamp: HybridLogicalClock(physicalTime: 2000, logicalCounter: 1, nodeId: 'nodeA'),
        ),
        partyPurse: base.partyPurse.modifyDenomination('gp', 50, replicaId: ReplicaId('nodeA')),
        changeLog: [evA],
      );

      final pB = base.copyWith(
        name: 'Test Campaign',
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Bob notes',
          timestamp: HybridLogicalClock(physicalTime: 1500, logicalCounter: 1, nodeId: 'nodeB'),
        ),
        partyPurse: base.partyPurse.modifyDenomination('sp', 20, replicaId: ReplicaId('nodeB')),
        changeLog: [evB],
      );

      // Canonical engine join
      final canonicalJoinAB = CampaignProfile.join(pA, pB);
      final canonicalJoinBA = CampaignProfile.join(pB, pA);
      expect(canonicalJoinAB, equals(canonicalJoinBA));

      // Safe application reconciliation
      final reconAB = reconciliationService.reconcileProfileSafely(local: pA, remote: pB);
      final reconBA = reconciliationService.reconcileProfileSafely(local: pB, remote: pA);

      expect(reconAB.fieldFaults, isEmpty);
      expect(reconBA.fieldFaults, isEmpty);

      // Exact parity between engine canonical join and safe reconciliation
      expect(reconAB.profile, equals(canonicalJoinAB));
      expect(reconBA.profile, equals(canonicalJoinBA));
    });

    test('N. Custom property structural equality matches in engine and toolkit safe reconciliation', () {
      final roomA = RoomNodeState(
        roomId: 'r1',
        roomCode: 'RC-1',
        title: 'Hall',
        customProperties: {
          'config': {'difficulty': 'hard', 'tags': [1, 2, 3]},
        },
      );
      // Separately allocated, identical nested structure
      final roomB = RoomNodeState(
        roomId: 'r1',
        roomCode: 'RC-1',
        title: 'Hall',
        customProperties: {
          'config': {'difficulty': 'hard', 'tags': [1, 2, 3]},
        },
      );

      final pA = createSampleProfile(roomState: roomA);
      final pB = createSampleProfile(roomState: roomB);

      final canonical = CampaignProfile.join(pA, pB);
      final recon = reconciliationService.reconcileProfileSafely(local: pA, remote: pB);

      expect(recon.fieldFaults, isEmpty);
      expect(recon.profile, equals(canonical));
      expect(recon.profile.roomState.customProperties['config'], equals({'difficulty': 'hard', 'tags': [1, 2, 3]}));
    });

    test('P & Q. Pure reconciliation does NOT mint new synthetic PartyEvents or consult wall clock', () {
      final pA = createSampleProfile().copyWith(
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Note A',
          timestamp: HybridLogicalClock(physicalTime: 1000, logicalCounter: 1, nodeId: 'nodeA'),
        ),
      );
      final pB = createSampleProfile().copyWith(
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Note B',
          timestamp: HybridLogicalClock(physicalTime: 2000, logicalCounter: 1, nodeId: 'nodeB'),
        ),
      );

      final recon = reconciliationService.reconcileProfileSafely(local: pA, remote: pB);

      expect(recon.fieldFaults, isEmpty);
      expect(recon.profile.notesMarkdown, equals('Note B'));
      // No notesConflictOverwrite synthesized into changeLog
      expect(recon.profile.changeLog.any((e) => e.type == 'notesConflictOverwrite'), isFalse);
    });

    test('G & Y. Stale replica cannot resurrect causally removed pinned rule', () {
      final base = createSampleProfile(pinnedRuleIds: {'cover', 'flanking'});

      // Replica A unpins 'cover' at authoritative timestamp
      const unpinHlc = HybridLogicalClock(physicalTime: 2000, logicalCounter: 1, nodeId: 'nodeA');
      final repA = base.copyWith(
        pinnedRules: base.pinnedRules.remove('cover', unpinHlc),
      );

      // Replica B was offline with stale 'cover' (genesis timestamp)
      final repB = base;

      final merged = reconciliationService.reconcileProfileSafely(local: repA, remote: repB).profile;

      expect(merged.pinnedRuleIds.contains('cover'), isFalse);
      expect(merged.pinnedRuleIds, contains('flanking'));

      // Symmetrically when repB is local and repA is incoming remote
      final mergedReverse = reconciliationService.reconcileProfileSafely(local: repB, remote: repA).profile;
      expect(mergedReverse.pinnedRuleIds.contains('cover'), isFalse);
    });

    test('H & Y. Stale replica cannot resurrect causally unbound entity link', () {
      final link1 = RoomEntityLink(entityId: 'monster-orc', displayName: 'Orc Raider');
      final link2 = RoomEntityLink(entityId: 'monster-goblin', displayName: 'Goblin Sneak');
      final baseRoom = RoomNodeState(
        roomId: 'r1',
        roomCode: 'RC-1',
        title: 'Ambush Site',
        entityLinks: [link1, link2],
      );
      final base = createSampleProfile(roomState: baseRoom);

      // Replica A unbinds 'monster-orc' with SessionGraphService
      const unbindHlc = HybridLogicalClock(physicalTime: 2500, logicalCounter: 1, nodeId: 'nodeA');
      final roomA = SessionGraphService.unbindEntityFromRoom(baseRoom, 'monster-orc', timestamp: unbindHlc);
      final repA = base.copyWith(roomState: roomA);

      // Replica B was offline with stale 'monster-orc'
      final repB = base;

      final merged = reconciliationService.reconcileProfileSafely(local: repA, remote: repB).profile;
      final mergedLinks = merged.roomState.entityLinks.map((l) => l.entityId).toList();

      expect(mergedLinks.contains('monster-orc'), isFalse);
      expect(mergedLinks, contains('monster-goblin'));
    });

    test('J & Y. Stale replica cannot resurrect character removed via typed PartyEvent entityId', () {
      final base = createSampleProfile(partyCharacterIds: ['cleric-1', 'rogue-1']);

      // Removal event with typed entityId
      final removeEvent = PartyEvent(
        id: 'rm-cleric',
        roomCode: 'RC-101',
        type: 'characterRemove',
        playerName: 'DM',
        details: 'Dismissed from party',
        entityId: 'cleric-1',
        timestamp: DateTime.utc(2026, 1, 1, 12, 0),
      );

      final repA = base.copyWith(changeLog: [removeEvent]);
      final repB = base; // Stale replica still containing cleric-1

      final merged = reconciliationService.reconcileProfileSafely(local: repA, remote: repB).profile;

      expect(merged.partyCharacterIds.contains('cleric-1'), isFalse);
      expect(merged.partyCharacterIds, contains('rogue-1'));
    });

    test('V. Serialization roundtrip with changeLog and pinnedRules matches exactly and joins cleanly', () {
      final ev1 = PartyEvent(
        id: 'ev-1',
        roomCode: 'RC-101',
        type: 'coinDeposit',
        playerName: 'Alice',
        details: 'Deposited 50 GP',
        entityId: 'char-1',
        timestamp: DateTime.utc(2026, 1, 1, 10, 0),
      );
      final ev2 = PartyEvent(
        id: 'ev-2',
        roomCode: 'RC-101',
        type: 'itemAdd',
        playerName: 'Bob',
        details: 'Found Longsword',
        timestamp: DateTime.utc(2026, 1, 1, 11, 0),
      );

      final original = createSampleProfile(
        pinnedRuleIds: {'cover', 'resting'},
        changeLog: [ev1, ev2],
      );

      final dto = CampaignProfileDto.fromDomain(original);
      final restored = dto.toDomain();

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));

      final joined = CampaignProfile.join(original, restored);
      expect(joined, equals(original));
    });

    test('X. Three-replica delete/reconnect scenario converges with all deletions preserved', () {
      final link = RoomEntityLink(entityId: 'boss-dragon', displayName: 'Red Dragon');
      final base = createSampleProfile(
        partyCharacterIds: ['hero-1', 'hero-2'],
        pinnedRuleIds: {'cover', 'inspiration'},
        roomState: RoomNodeState(
          roomId: 'r1',
          roomCode: 'RC-1',
          title: 'Lair',
          entityLinks: [link],
        ),
      );

      // Replica A unpins 'cover'
      final repA = base.copyWith(
        pinnedRules: base.pinnedRules.remove(
          'cover',
          const HybridLogicalClock(physicalTime: 100, logicalCounter: 1, nodeId: 'nodeA'),
        ),
      );

      // Replica B unbinds 'boss-dragon'
      final repB = base.copyWith(
        roomState: SessionGraphService.unbindEntityFromRoom(
          base.roomState,
          'boss-dragon',
          timestamp: const HybridLogicalClock(physicalTime: 200, logicalCounter: 1, nodeId: 'nodeB'),
        ),
      );

      // Replica C removes 'hero-1'
      final repC = base.copyWith(
        changeLog: [
          PartyEvent(
            id: 'ev-rm-hero1',
            roomCode: 'RC-1',
            type: 'characterRemove',
            playerName: 'DM',
            details: 'Hero retired',
            entityId: 'hero-1',
            timestamp: DateTime.utc(2026, 1, 1, 12, 0),
          ),
        ],
      );

      // Merge order 1: (A + B) + C
      final ab = reconciliationService.reconcileProfileSafely(local: repA, remote: repB).profile;
      final abc = reconciliationService.reconcileProfileSafely(local: ab, remote: repC).profile;

      // Merge order 2: (C + B) + A
      final cb = reconciliationService.reconcileProfileSafely(local: repC, remote: repB).profile;
      final cba = reconciliationService.reconcileProfileSafely(local: cb, remote: repA).profile;

      expect(abc, equals(cba));

      // Verify all intended deletions are preserved:
      expect(abc.pinnedRuleIds.contains('cover'), isFalse);
      expect(abc.pinnedRuleIds, contains('inspiration'));
      expect(abc.roomState.entityLinks.map((l) => l.entityId).contains('boss-dragon'), isFalse);
      expect(abc.partyCharacterIds.contains('hero-1'), isFalse);
      expect(abc.partyCharacterIds, contains('hero-2'));
    });

    test('AD. Source bar: RoomStateReconciliationService delegates to canonical engine join helpers and does not reimplement merge logic', () {
      final file = File('lib/application/services/room_state_reconciliation_service.dart');
      final source = file.readAsStringSync();

      // Zero duplicated algorithms / suspicious local logic:
      expect(source.contains('.union('), isFalse, reason: 'RoomStateReconciliationService must not use .union for pinned rules');
      expect(source.contains('notesConflictOverwrite'), isFalse, reason: 'RoomStateReconciliationService must not mint synthetic notesConflictOverwrite events');
      expect(source.contains('event.details.trim()'), isFalse, reason: 'RoomStateReconciliationService must not parse display prose for roster deletion');

      // Canonical engine helpers are explicitly called:
      expect(source.contains('joinChangeLog('), isTrue);
      expect(source.contains('joinPartyRoster('), isTrue);
      expect(source.contains('joinPinnedRules('), isTrue);
      expect(source.contains('joinCustomProperties('), isTrue);
      expect(source.contains('joinEntityLinks('), isTrue);
      expect(source.contains('joinEntityInstances('), isTrue);
      expect(source.contains('joinContainers('), isTrue);
      expect(source.contains('joinUnversionedString('), isTrue);
      expect(source.contains('joinImmutableId('), isTrue);
    });
  });
}
