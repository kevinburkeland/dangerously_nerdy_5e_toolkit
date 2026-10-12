import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/utils/aggregate_join_utils.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage — Pass 4 Closure Regressions', () {
    final replicaId = ReplicaId('writer-authoritative-1');
    late StatefulHlcClock clock;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      clock = StatefulHlcClock(
        replicaId: replicaId,
        timeProvider: () => 1700000000000,
      );
      CampaignProfileService.resetForTesting();
      CampaignProfileService(replicaId: replicaId, clock: clock);
    });

    tearDown(() {
      CampaignProfileService.resetForTesting();
    });

    // =========================================================================
    // 1. FRESH / DEFAULT CAMPAIGN CREATION CAUSALITY
    // =========================================================================
    group('1. Fresh/Default Campaign Active Creation Causality', () {
      test('CampaignProfile.defaultProfile requires authoritative timestamp or clock', () {
        expect(
          () => CampaignProfile.defaultProfile(nodeId: replicaId.value),
          throwsArgumentError,
        );
      });

      test('CampaignProfile.defaultProfile rejects genesis sentinel timestamp', () {
        expect(
          () => CampaignProfile.defaultProfile(
            nodeId: 'genesis',
            timestamp: const HybridLogicalClock(
              physicalTime: 0,
              logicalCounter: 0,
              nodeId: 'genesis',
            ),
          ),
          throwsArgumentError,
        );
      });

      test('CampaignProfile.defaultProfile stamps active CRDT membership with runtime writer causality (never genesis)', () {
        final profile = CampaignProfile.defaultProfile(
          id: 'camp-fresh-active',
          name: 'The Sunken Citadel',
          nodeId: replicaId.value,
          clock: clock,
          defaultPinnedRules: {'concentration', 'grapple_shove'},
        );

        // nameRegister
        expect(profile.nameRegister.timestamp.nodeId, equals(replicaId.value));
        expect(profile.nameRegister.timestamp.nodeId, isNot(equals('genesis')));
        expect(profile.nameRegister.timestamp.physicalTime, greaterThan(0));

        // notesRegister
        expect(profile.notesRegister.timestamp.nodeId, equals(replicaId.value));
        expect(profile.notesRegister.timestamp.nodeId, isNot(equals('genesis')));
        expect(profile.notesRegister.timestamp.physicalTime, greaterThan(0));

        // pinnedRules
        expect(profile.pinnedRules.items.isNotEmpty, isTrue);
        for (final entry in profile.pinnedRules.items.values) {
          expect(entry.timestamp.nodeId, equals(replicaId.value));
          expect(entry.timestamp.nodeId, isNot(equals('genesis')));
          expect(entry.timestamp.physicalTime, greaterThan(0));
        }
      });

      test('CampaignProfileService.createProfile authors fresh state with runtime writer causality', () async {
        final service = CampaignProfileService();
        final created = await service.createProfile(
          name: 'Active Fresh Campaign',
          edition: DmRulesEdition.v2024,
        );

        expect(created.nameRegister.timestamp.nodeId, equals(replicaId.value));
        expect(created.nameRegister.timestamp.nodeId, isNot(equals('genesis')));
        for (final entry in created.pinnedRules.items.values) {
          expect(entry.timestamp.nodeId, equals(replicaId.value));
          expect(entry.timestamp.nodeId, isNot(equals('genesis')));
          expect(entry.timestamp.physicalTime, greaterThan(0));
        }
      });
    });

    // =========================================================================
    // 2. LEGACY DETERMINISTIC MIGRATION (GENESIS PRESERVATION)
    // =========================================================================
    group('2. Legacy Deterministic Migration & Genesis Sentinel', () {
      test('Legacy DTO without CRDT sets deterministically constructs genesis sentinel', () {
        final legacyMap = {
          'id': 'legacy-camp-1',
          'name': 'Old Forgotten Realm',
          'pinnedRuleIds': ['concentration', 'grapple_shove'],
          'partyCharacterIds': ['hero-1', 'hero-2'],
        };

        final dto = CampaignProfileDto.fromMap(legacyMap);
        final domain = dto.toDomain();

        // Migration sentinel is genesis
        expect(domain.nameRegister.timestamp.nodeId, equals('genesis'));
        expect(domain.nameRegister.timestamp.physicalTime, equals(0));

        expect(domain.pinnedRules.items.values.isNotEmpty, isTrue);
        for (final entry in domain.pinnedRules.items.values) {
          expect(entry.timestamp.nodeId, equals('genesis'));
          expect(entry.timestamp.physicalTime, equals(0));
        }

        expect(domain.partyRoster.items.values.isNotEmpty, isTrue);
        for (final entry in domain.partyRoster.items.values) {
          expect(entry.timestamp.nodeId, equals('genesis'));
          expect(entry.timestamp.physicalTime, equals(0));
        }
      });
    });

    // =========================================================================
    // 3. DETERMINISTIC MIGRATION-SAFE ROOM CODE & REGRESSION
    // =========================================================================
    group('3. Deterministic Room State Migration & Collision Safety', () {
      test('Missing legacy room state produces deterministic room code derived from campaign ID', () {
        final mapA = {
          'id': 'camp-alpha-123',
          'name': 'Alpha Campaign',
        };
        final dto1 = CampaignProfileDto.fromMap(mapA);
        final domain1 = dto1.toDomain();

        final dto2 = CampaignProfileDto.fromMap(mapA);
        final domain2 = dto2.toDomain();

        // Deterministic: multiple loads produce identical roomCode
        expect(domain1.roomState.roomCode, equals(domain2.roomState.roomCode));
        expect(domain1.roomState.roomCode, startsWith('CR-'));
        expect(domain1.roomState.roomId, equals('room_camp-alpha-123'));
        expect(domain1.roomState.title, equals('Alpha Campaign Staging'));
      });

      test('Two distinct legacy campaign IDs produce distinct room codes (no shared authority / collision)', () {
        final map1 = {
          'id': 'legacy-campaign-one',
          'name': 'First Table',
        };
        final map2 = {
          'id': 'legacy-campaign-two',
          'name': 'Second Table',
        };

        final domain1 = CampaignProfileDto.fromMap(map1).toDomain();
        final domain2 = CampaignProfileDto.fromMap(map2).toDomain();

        expect(domain1.roomState.roomCode, isNot(equals(domain2.roomState.roomCode)));
        expect(domain1.roomState.roomCode, isNot(equals('CR-101')));
        expect(domain2.roomState.roomCode, isNot(equals('CR-101')));
      });

      test('Authoritative empty room state is preserved and distinct from genuine absence', () {
        final mapEmpty = {
          'id': 'camp-empty-room',
          'name': 'Empty Room Campaign',
          'roomState': <String, dynamic>{},
        };

        final dto = CampaignProfileDto.fromMap(mapEmpty);
        expect(dto.hasRoomState, isTrue);
        final domain = dto.toDomain();

        // Empty roomState should deserialize as empty RoomNodeState, not synthetic staging
        expect(domain.roomState.roomId, isEmpty);
        expect(domain.roomState.roomCode, isEmpty);
        expect(domain.roomState.title, isEmpty);
      });

      test('Malformed present roomState fails loudly with FormatException', () {
        final malformedMap = {
          'id': 'camp-bad-room',
          'roomState': 'not-a-map',
        };

        expect(
          () => CampaignProfileDto.fromMap(malformedMap),
          throwsA(isA<FormatException>()),
        );
      });
    });

    // =========================================================================
    // 4. ENTITYLINKCRDTSET AGGREGATE LAW REGRESSIONS
    // =========================================================================
    group('4. EntityLinkCrdtSet Join Semilattice Laws', () {
      const ts10 = HybridLogicalClock(physicalTime: 10, logicalCounter: 0, nodeId: 'nodeA');
      const ts20 = HybridLogicalClock(physicalTime: 20, logicalCounter: 0, nodeId: 'nodeA');
      const ts30 = HybridLogicalClock(physicalTime: 30, logicalCounter: 0, nodeId: 'nodeB');

      final linkG1 = RoomEntityLink(
        entityId: 'door-1',
        incarnationTimestamp: ts10,
        displayNameRegister: const CrdtLwwRegister<String>(value: 'Iron Door G1', timestamp: ts10),
        notesRegister: const CrdtLwwRegister<String>(value: 'Locked G1', timestamp: ts10),
      );

      final linkG2 = RoomEntityLink(
        entityId: 'door-1',
        incarnationTimestamp: ts30,
        displayNameRegister: const CrdtLwwRegister<String>(value: 'Reinforced Door G2', timestamp: ts30),
        notesRegister: const CrdtLwwRegister<String>(value: 'Unlocked G2', timestamp: ts30),
      );

      test('Idempotence: join(A, A) == A', () {
        final setA = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG1, ts10);
        expect(joinEntityLinks(setA, setA), equals(setA));
      });

      test('Commutativity: join(A, B) == join(B, A)', () {
        final setA = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG1, ts10);
        final setB = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG2, ts30);

        final ab = joinEntityLinks(setA, setB);
        final ba = joinEntityLinks(setB, setA);

        expect(ab, equals(ba));
        // Higher generation G2 dominates G1
        expect(ab.activeValues.single.incarnationTimestamp, equals(ts30));
        expect(ab.activeValues.single.displayName, equals('Reinforced Door G2'));
      });

      test('Associativity: join(join(A, B), C) == join(A, join(B, C))', () {
        final setA = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG1, ts10);
        final setB = const EntityLinkCrdtSet.empty().remove('door-1', ts20, targetGeneration: ts10);
        final setC = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG2, ts30);

        final abThenC = joinEntityLinks(joinEntityLinks(setA, setB), setC);
        final aThenBc = joinEntityLinks(setA, joinEntityLinks(setB, setC));

        expect(abThenC, equals(aThenBc));
        expect(abThenC.activeValues.single.displayName, equals('Reinforced Door G2'));
      });

      test('Same-generation native removal wins over active link', () {
        final setA = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG1, ts10);
        final setB = const EntityLinkCrdtSet.empty().remove('door-1', ts20, targetGeneration: ts10);

        final merged = joinEntityLinks(setA, setB);
        expect(merged.activeValues, isEmpty);
        expect(merged.tombstones.containsKey('door-1'), isTrue);
      });

      test('Same-generation active payloads recursively compose via RoomEntityLink.join', () {
        final base = const EntityLinkCrdtSet.empty().createOrReadd('door-1', linkG1, ts10);

        final linkEditName = linkG1.copyWith(
          displayName: 'Wooden Gate',
          displayNameTimestamp: ts20,
        );
        final linkEditNotes = linkG1.copyWith(
          notes: 'Key hidden under stone',
          notesTimestamp: ts20,
        );

        final setA = base.update('door-1', linkEditName, ts20);
        final setB = base.update('door-1', linkEditNotes, ts20);

        final merged = joinEntityLinks(setA, setB);
        expect(merged.activeValues.length, equals(1));
        final surviving = merged.activeValues.single;
        expect(surviving.displayName, equals('Wooden Gate'));
        expect(surviving.notes, equals('Key hidden under stone'));
      });
    });
  });
}
