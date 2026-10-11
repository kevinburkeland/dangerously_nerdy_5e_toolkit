import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/aggregate_hlc_extractor.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/loot_models.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';

void main() {
  setUpAll(() {
    IRoomSyncPayloadPort.defaultProvider = () => const RoomSyncPayloadMapper();
  });

  group('Cold Iron Birdcage — Pass 4.2: Mutable Field Semantics & Single-Writer Law', () {
    late StatefulHlcClock clockA;
    late RoomStateReconciliationService reconciliationService;

    setUp(() {
      clockA = StatefulHlcClock(
        replicaId: ReplicaId('replica-a'),
        timeProvider: () => 1700000000000,
      );
      reconciliationService = RoomStateReconciliationService(
        networkTimeProvider: () => 1700000000000,
      );
    });

    CampaignProfile createCommonBase() {
      const genesisHlc = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'genesis');
      final link = RoomEntityLink(
        entityId: 'link-door',
        displayName: 'North Door',
        notes: 'A solid oak door',
        notesTimestamp: genesisHlc,
      );
      final instance = EntityInstance(
        instanceId: 'inst-goblin',
        displayName: 'Goblin Scout',
        displayNameTimestamp: genesisHlc,
      );
      final container = LootContainer(
        containerId: 'cont-chest',
        name: 'Wooden Chest',
        nameTimestamp: genesisHlc,
      );

      return CampaignProfile.raw(
        id: 'camp-birdcage',
        name: 'Initial Campaign',
        nameTimestamp: genesisHlc,
        edition: const RulesetIdentifier('generic_tabletop'),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room-1',
          roomCode: 'RC-1',
          title: 'Tavern',
          titleTimestamp: genesisHlc,
          description: 'A cozy tavern with a roaring hearth.',
          descriptionTimestamp: genesisHlc,
          entityLinks: [link],
          entityInstances: [instance],
          containers: [container],
        ),
        partyPurse: const PartyPurse.empty(),
        notesRegister: const CrdtLwwRegister<String>(value: '', timestamp: genesisHlc),
      );
    }

    group('1. Single-Writer Propagation Law', () {
      test('CampaignProfile.name: single-writer edit propagates to unchanged replica and converges', () {
        final base = createCommonBase();
        final editTs = clockA.nextTimestamp();
        final repA = base.copyWith(name: 'Crypt of Shadows', nameTimestamp: editTs);
        final repB = base; // Unchanged replica

        // Canonical engine join
        final joinAB = CampaignProfile.join(repA, repB);
        final joinBA = CampaignProfile.join(repB, repA);

        expect(joinAB.name, equals('Crypt of Shadows'));
        expect(joinBA.name, equals('Crypt of Shadows'));
        expect(joinAB, equals(joinBA));
        expect(joinAB.nameRegister.timestamp, equals(editTs));

        // Application-level reconciliation produces zero faults
        final reconResult = reconciliationService.reconcileProfileSafely(local: repB, remote: repA);
        expect(reconResult.hasFaults, isFalse);
        expect(reconResult.profile.name, equals('Crypt of Shadows'));
        expect(reconResult.profile.nameRegister.timestamp, equals(editTs));

        // Repeated joins converge
        final repeatJoin = CampaignProfile.join(joinAB, repB);
        expect(repeatJoin, equals(joinAB));

        // Roundtrip serialization preserves causal state
        final dtoMap = CampaignProfileDto.fromDomain(joinAB).toMap();
        final roundTrip = CampaignProfileDto.fromMap(dtoMap).toDomain();
        expect(roundTrip.name, equals('Crypt of Shadows'));
        expect(roundTrip.nameRegister.timestamp, equals(editTs));
      });

      test('RoomNodeState.title: single-writer edit propagates and converges with zero faults', () {
        final base = createCommonBase();
        final editTs = clockA.nextTimestamp();
        final repA = base.copyWith(
          roomState: base.roomState.copyWith(title: 'Ancient Crypt', titleTimestamp: editTs),
        );
        final repB = base;

        final joinAB = CampaignProfile.join(repA, repB);
        final joinBA = CampaignProfile.join(repB, repA);

        expect(joinAB.roomState.title, equals('Ancient Crypt'));
        expect(joinBA.roomState.title, equals('Ancient Crypt'));
        expect(joinAB, equals(joinBA));

        final reconResult = reconciliationService.reconcileProfileSafely(local: repB, remote: repA);
        expect(reconResult.hasFaults, isFalse);
        expect(reconResult.profile.roomState.title, equals('Ancient Crypt'));
        expect(reconResult.profile.roomState.titleRegister.timestamp, equals(editTs));
      });

      test('RoomNodeState.description: single-writer edit propagates and converges with zero faults', () {
        final base = createCommonBase();
        final editTs = clockA.nextTimestamp();
        final repA = base.copyWith(
          roomState: base.roomState.copyWith(
            description: 'A cold, foreboding stone chamber filled with sarcophagi.',
            descriptionTimestamp: editTs,
          ),
        );
        final repB = base;

        final joinAB = CampaignProfile.join(repA, repB);
        final joinBA = CampaignProfile.join(repB, repA);

        expect(joinAB.roomState.description, equals('A cold, foreboding stone chamber filled with sarcophagi.'));
        expect(joinBA.roomState.description, equals('A cold, foreboding stone chamber filled with sarcophagi.'));
        expect(joinAB, equals(joinBA));

        final reconResult = reconciliationService.reconcileProfileSafely(local: repB, remote: repA);
        expect(reconResult.hasFaults, isFalse);
        expect(reconResult.profile.roomState.description, equals('A cold, foreboding stone chamber filled with sarcophagi.'));
      });

      test('RoomEntityLink.notes: single-writer edit propagates and converges', () {
        final base = createCommonBase();
        final editTs = clockA.nextTimestamp();
        final updatedLink = base.roomState.entityLinks.first.copyWith(
          notes: 'Trapped heavy iron door with poisonous runes',
          notesTimestamp: editTs,
        );
        final repA = base.copyWith(
          roomState: base.roomState.copyWith(
            entityLinksCrdt: base.roomState.entityLinksCrdt.add(updatedLink.entityId, updatedLink, editTs),
          ),
        );
        final repB = base;

        final joinAB = CampaignProfile.join(repA, repB);
        final joinBA = CampaignProfile.join(repB, repA);

        expect(joinAB.roomState.entityLinks.first.notes, equals('Trapped heavy iron door with poisonous runes'));
        expect(joinBA.roomState.entityLinks.first.notes, equals('Trapped heavy iron door with poisonous runes'));
        expect(joinAB, equals(joinBA));

        final reconResult = reconciliationService.reconcileProfileSafely(local: repB, remote: repA);
        expect(reconResult.hasFaults, isFalse);
        expect(reconResult.profile.roomState.entityLinks.first.notes, equals('Trapped heavy iron door with poisonous runes'));
      });

      test('EntityInstance.displayName: single-writer edit propagates and converges', () {
        final base = createCommonBase();
        final editTs = clockA.nextTimestamp();
        final updatedInstance = base.roomState.entityInstances.first.copyWith(
          displayName: 'Goblin Warlord',
          displayNameTimestamp: editTs,
        );
        final repA = base.copyWith(
          roomState: base.roomState.copyWith(
            entityInstances: [updatedInstance],
          ),
        );
        final repB = base;

        final joinAB = CampaignProfile.join(repA, repB);
        final joinBA = CampaignProfile.join(repB, repA);

        expect(joinAB.roomState.entityInstances.first.displayName, equals('Goblin Warlord'));
        expect(joinBA.roomState.entityInstances.first.displayName, equals('Goblin Warlord'));
        expect(joinAB, equals(joinBA));

        final reconResult = reconciliationService.reconcileProfileSafely(local: repB, remote: repA);
        expect(reconResult.hasFaults, isFalse);
        expect(reconResult.profile.roomState.entityInstances.first.displayName, equals('Goblin Warlord'));
      });

      test('LootContainer.name: single-writer edit propagates and converges', () {
        final base = createCommonBase();
        final editTs = clockA.nextTimestamp();
        final updatedContainer = base.roomState.containers.first.copyWith(
          name: 'Royal Gilded Vault',
          nameTimestamp: editTs,
        );
        final repA = base.copyWith(
          roomState: base.roomState.copyWith(
            containers: [updatedContainer],
          ),
        );
        final repB = base;

        final joinAB = CampaignProfile.join(repA, repB);
        final joinBA = CampaignProfile.join(repB, repA);

        expect(joinAB.roomState.containers.first.name, equals('Royal Gilded Vault'));
        expect(joinBA.roomState.containers.first.name, equals('Royal Gilded Vault'));
        expect(joinAB, equals(joinBA));

        final reconResult = reconciliationService.reconcileProfileSafely(local: repB, remote: repA);
        expect(reconResult.hasFaults, isFalse);
        expect(reconResult.profile.roomState.containers.first.name, equals('Royal Gilded Vault'));
      });
    });

    group('2. Concurrent Edits & Conflict Resolution', () {
      test('Concurrent scalar edits: higher HLC wins deterministically and symmetrically', () {
        final base = createCommonBase();
        const tsA = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'replica-a');
        const tsB = HybridLogicalClock(physicalTime: 3000, logicalCounter: 0, nodeId: 'replica-b');

        final mutA = base.copyWith(name: 'Campaign by Replica A', nameTimestamp: tsA);
        final mutB = base.copyWith(name: 'Campaign by Replica B', nameTimestamp: tsB);

        final joinAB = CampaignProfile.join(mutA, mutB);
        final joinBA = CampaignProfile.join(mutB, mutA);

        expect(joinAB.name, equals('Campaign by Replica B'));
        expect(joinBA.name, equals('Campaign by Replica B'));
        expect(joinAB, equals(joinBA));

        // Reconciliation also converges to winning replica
        final recon = reconciliationService.reconcileProfileSafely(local: mutA, remote: mutB);
        expect(recon.hasFaults, isFalse);
        expect(recon.profile.name, equals('Campaign by Replica B'));
      });

      test('Exact-HLC collision with divergent values fails loud in engine and isolates in application reconciliation', () {
        final base = createCommonBase();
        const collisionTs = HybridLogicalClock(physicalTime: 5000, logicalCounter: 1, nodeId: 'collision-node');

        final mutA = base.copyWith(name: 'Name Branch A', nameTimestamp: collisionTs);
        final mutB = base.copyWith(name: 'Name Branch B', nameTimestamp: collisionTs);

        // Engine join throws StateError
        expect(() => CampaignProfile.join(mutA, mutB), throwsA(isA<StateError>()));
        expect(() => CampaignProfile.join(mutB, mutA), throwsA(isA<StateError>()));

        // Application reconciliation isolates fault without corrupting
        final recon = reconciliationService.reconcileProfileSafely(local: mutA, remote: mutB);
        expect(recon.hasFaults, isTrue);
        expect(recon.fieldFaults.any((f) => f.field == 'name'), isTrue);
        expect(recon.profile.name, equals('Name Branch A')); // Keeps local on collision fault
      });
    });

    group('3. HLC Extraction & Remote Drift Validation', () {
      test('extractCampaignProfileTimestamps includes all newly versioned scalars', () {
        final base = createCommonBase();
        final timestamps = extractCampaignProfileTimestamps(base);
        expect(timestamps, contains(base.nameRegister.timestamp));
        expect(timestamps, contains(base.roomState.titleRegister.timestamp));
        expect(timestamps, contains(base.roomState.descriptionRegister.timestamp));
        expect(timestamps, contains(base.roomState.entityLinks.first.notesRegister.timestamp));
        expect(timestamps, contains(base.roomState.entityInstances.first.displayNameRegister.timestamp));
        expect(timestamps, contains(base.roomState.containers.first.nameRegister.timestamp));
      });

      test('Remote future drift at T + 10 years on newly versioned field rejects before mutation', () {
        final base = createCommonBase();
        const driftHlc = HybridLogicalClock(
          physicalTime: 1700000000000 + (10 * 365 * 24 * 3600 * 1000), // ~10 years in future
          logicalCounter: 0,
          nodeId: 'drifter',
        );

        final driftedProfile = base.copyWith(
          roomState: base.roomState.copyWith(title: 'Future Room', titleTimestamp: driftHlc),
        );

        final candidateHlcs = extractCampaignProfileTimestamps(driftedProfile);
        expect(
          () => clockA.validateAllRemote(candidateHlcs),
          throwsA(isA<HlcFutureDriftException>()),
        );

        // Local clock did not advance
        final nextTs = clockA.nextTimestamp();
        expect(nextTs.physicalTime, lessThan(driftHlc.physicalTime));
      });
    });

    group('4. Trusted Local Persisted History', () {
      test('Historically future timestamp loads and observes into runtime clock without rejection', () {
        final base = createCommonBase();
        const futureHistTs = HybridLogicalClock(
          physicalTime: 1700000000000 + 3600000, // 1 hour ahead
          logicalCounter: 5,
          nodeId: 'historical-writer',
        );

        final localPersisted = base.copyWith(
          name: 'Persisted Campaign',
          nameTimestamp: futureHistTs,
        );

        // Observe trusted history into fresh clock
        final freshClock = StatefulHlcClock(
          replicaId: ReplicaId('current-replica'),
          timeProvider: () => 1700000000000,
        );

        final localTimestamps = extractCampaignProfileTimestamps(localPersisted);
        freshClock.observeAllTrustedHistory(localTimestamps);

        // Next timestamp from clock must causally advance beyond historical timestamp
        final nextTs = freshClock.nextTimestamp();
        expect(nextTs.physicalTime, greaterThanOrEqualTo(futureHistTs.physicalTime));
        expect(nextTs.nodeId, equals('current-replica'));
      });
    });

    group('5. Permanent Architectural Source Bars', () {
      test('Calling copyWith on versioned fields without timestamp throws ArgumentError', () {
        final base = createCommonBase();

        // CampaignProfile.name
        expect(() => base.copyWith(name: 'New Name'), throwsA(isA<ArgumentError>()));

        // RoomNodeState.title
        expect(() => base.roomState.copyWith(title: 'New Title'), throwsA(isA<ArgumentError>()));

        // RoomNodeState.description
        expect(() => base.roomState.copyWith(description: 'New Desc'), throwsA(isA<ArgumentError>()));

        // EntityInstance.displayName
        expect(
          () => base.roomState.entityInstances.first.copyWith(displayName: 'New Display'),
          throwsA(isA<ArgumentError>()),
        );

        // RoomEntityLink.notes
        expect(
          () => base.roomState.entityLinks.first.copyWith(notes: 'New Notes'),
          throwsA(isA<ArgumentError>()),
        );

        // LootContainer.name
        expect(
          () => base.roomState.containers.first.copyWith(name: 'New Container'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Production codebase scan ensures zero active unversioned mutations on RoomNodeState or CampaignProfile', () {
        final libDir = Directory('lib');
        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          // RoomNodeState.copyWith must never be called with raw customProperties in production
          expect(
            content.contains('roomState.copyWith(customProperties:'),
            isFalse,
            reason: '${file.path} must not mutate roomState.customProperties via copyWith',
          );
        }
      });
    });
  });
}
