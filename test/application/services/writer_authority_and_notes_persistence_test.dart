import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppDatabaseService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('Pass 3.2 Writer Authority & Notes Invariants', () {
    test(
        'Section D regression: local edit after observing remote peer timestamp wins with local ReplicaId',
        () async {
      final replicaIdA = ReplicaId('runtime_node_alpha');
      final clockA = StatefulHlcClock(
        replicaId: replicaIdA,
        maxFutureDrift: const Duration(minutes: 5),
      );

      // Inbound remote note from Peer B with future-but-acceptable timestamp (+10 seconds)
      final remotePhysical =
          DateTime.now().millisecondsSinceEpoch + 10000;
      final remoteTs = HybridLogicalClock(
        physicalTime: remotePhysical,
        logicalCounter: 5,
        nodeId: 'peer_node_bravo',
      );
      final remoteRegister = CrdtLwwRegister<String>(
        value: 'Peer B notes from remote',
        timestamp: remoteTs,
      );

      // Local runtime observes the accepted remote causal history
      clockA.observeRemote(remoteTs);

      // Local writer A edits notes afterward
      final localTs = clockA.nextTimestamp();
      final localRegister = CrdtLwwRegister<String>(
        value: 'Local notes edit by Alpha',
        timestamp: localTs,
      );

      // Invariants:
      // 1. Authoritative local node ID is stamped
      expect(localTs.nodeId, equals(replicaIdA.value));
      // 2. Monotonically strictly after observed remote timestamp
      expect(localTs.isAfter(remoteTs), isTrue);
      // 3. Local edit wins under LWW merge
      final merged = localRegister.merge(remoteRegister);
      expect(merged.value, equals('Local notes edit by Alpha'));
      expect(merged.timestamp, equals(localTs));
    });

    test(
        'Section E regression: same-millisecond local edits are strictly monotonic and unique without wall-clock movement',
        () {
      final replicaId = ReplicaId('deterministic_writer');
      // Deterministic physical time provider: frozen in time
      int frozenMs = 1712000000000;
      final clock = StatefulHlcClock(
        replicaId: replicaId,
        timeProvider: () => frozenMs,
      );

      final ts1 = clock.nextTimestamp();
      final ts2 = clock.nextTimestamp();
      final ts3 = clock.nextTimestamp();

      // All generated within same physical millisecond
      expect(ts1.physicalTime, equals(frozenMs));
      expect(ts2.physicalTime, equals(frozenMs));
      expect(ts3.physicalTime, equals(frozenMs));

      // Strictly monotonic advancement of logical counters
      expect(ts2.isAfter(ts1), isTrue);
      expect(ts3.isAfter(ts2), isTrue);
      expect(ts1 != ts2, isTrue);
      expect(ts2 != ts3, isTrue);

      // Logical counters strictly sequential
      expect(ts2.logicalCounter, equals(ts1.logicalCounter + 1));
      expect(ts3.logicalCounter, equals(ts2.logicalCounter + 1));

      // Node ID attribution strictly preserved
      expect(ts1.nodeId, equals(replicaId.value));
      expect(ts2.nodeId, equals(replicaId.value));
      expect(ts3.nodeId, equals(replicaId.value));
    });

    test(
        'Section W regression: loading persisted profile with future HLC advances shared clock for next write',
        () async {
      final replicaId = ReplicaId('loading_runtime');
      final clock = StatefulHlcClock(
        replicaId: replicaId,
        maxFutureDrift: const Duration(minutes: 5),
      );

      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
      );
      addTearDown(repo.dispose);

      // Persisted profile notes timestamp is ahead of current wall clock (+15s)
      final futurePhysical = DateTime.now().millisecondsSinceEpoch + 15000;
      final futureTs = HybridLogicalClock(
        physicalTime: futurePhysical,
        logicalCounter: 42,
        nodeId: 'historical_dm_writer',
      );
      final profile = CampaignProfile.defaultProfile(
        id: 'camp_future_history',
        name: 'Future History Campaign',
        nodeId: 'historical_node',
      ).copyWith(
        notesRegister: CrdtLwwRegister(
          value: 'Historical future notes',
          timestamp: futureTs,
        ),
      );

      final dtoMap = CampaignProfileDto.fromDomain(profile).toMap();
      SharedPreferences.setMockInitialValues({
        'dn5e_campaign_profile_index': ['camp_future_history'],
        'dn5e_campaign_profile_camp_future_history': json.encode(dtoMap),
        'dn5e_active_campaign_profile_id': 'camp_future_history',
      });

      // Load profile: LocalCampaignRepository observes loaded timestamps into clock
      await repo.loadAllProfiles();

      // Next local note edit must be strictly after futureTs
      final nextLocalTs = clock.nextTimestamp();
      expect(nextLocalTs.isAfter(futureTs), isTrue);
      expect(nextLocalTs.physicalTime >= futurePhysical, isTrue);
      expect(nextLocalTs.nodeId, equals(replicaId.value));
    });

    test(
        'Section Y regression: local mutations (notes, minions) strictly carry runtime ReplicaId',
        () async {
      final replicaId = ReplicaId('runtime_attribution_node');
      final clock = StatefulHlcClock(
        replicaId: replicaId,
        maxFutureDrift: const Duration(minutes: 5),
      );

      final campaignService = CampaignProfileService();
      final characterService = CharacterPersistenceService();

      final controller = DmDashboardController(
        campaignProfileService: campaignService,
        characterPersistenceService: characterService,
        replicaId: replicaId,
        clock: clock,
      );
      addTearDown(controller.dispose);

      final baseCampaign = CampaignProfile.defaultProfile(
        id: 'camp_attrib_test',
        name: 'Attribution Campaign',
        nodeId: 'genesis_node',
      );
      await campaignService.saveProfileImmediate(baseCampaign);
      await campaignService.switchProfile(baseCampaign.id);

      await controller.loadData();

      // 1. Update Notes
      await controller.updateNotes('New local notes by controller');
      final activeProfile = controller.activeProfile!;
      expect(activeProfile.notesMarkdown, equals('New local notes by controller'));
      expect(activeProfile.notesRegister.timestamp.nodeId, equals(replicaId.value));

      // 2. Add Minion
      final minion = AnimatedObjectInstance(
        id: 'minion_golem_1',
        name: 'Clay Golem',
        size: ObjectSize.medium,
        currentHp: 50,
        maxHp: 50,
      );
      await controller.addMinion(minion);
      final addedMinionItem =
          controller.activeProfile!.roomState.activeMinions.items['minion_golem_1']!;
      expect(addedMinionItem.timestamp.nodeId, equals(replicaId.value));

      // 3. Modify Minion HP
      await controller.modifyMinionHp('minion_golem_1', -15);
      final modifiedMinionItem =
          controller.activeProfile!.roomState.activeMinions.items['minion_golem_1']!;
      expect(modifiedMinionItem.timestamp.nodeId, equals(replicaId.value));
      expect(modifiedMinionItem.value.currentHp, equals(35));

      // 4. Remove Minion (Tombstone)
      await controller.removeMinion('minion_golem_1');
      final tombstoneTs = controller
          .activeProfile!.roomState.activeMinions.tombstones['minion_golem_1']!;
      expect(tombstoneTs.nodeId, equals(replicaId.value));
    });

    test(
        'Section R scaffold (Future Pass): one colliding subresource must not permanently dead-letter unrelated progress',
        () {
      // Pass 3 / Pass 3.2 Invariant:
      // Primitive layer fails loudly (StateError) upon exact same HLC + divergent payload.
      // Next Layer (Pass 4 Orchestration/Fault Isolation):
      // Application/sync layer should quarantine the offending colliding subresource
      // rather than aborting unrelated fields (e.g., party purse progress).
    },
        skip:
            'Pending Pass 4 fault isolation architecture. Primitive exact-HLC collision remains fail-loud.');
  });

  group('Section J Static Source Audit: Grep-Ban Direct HLC Construction', () {
    test(
        'forbids HybridLogicalClock construction outside approved DTO reconstruction in lib/',
        () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];
      final regex = RegExp(r'\bHybridLogicalClock(?:\.now)?\s*\(');

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // Approved paths: DTOs reconstruction / serialization
        final normalizedPath = entity.path.replaceAll(r'\', '/');
        if (normalizedPath.contains('/infrastructure/dtos/')) {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Ignore comments
          final trimmed = line.trim();
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('*')) {
            continue;
          }
          if (regex.hasMatch(line)) {
            violations.add('${entity.path}:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Direct HybridLogicalClock construction is forbidden in production code outside DTO reconstruction. '
            'All active writes must use the DI singleton StatefulHlcClock.\n'
            'Violations found:\n${violations.join('\n')}',
      );
    });
  });
}
