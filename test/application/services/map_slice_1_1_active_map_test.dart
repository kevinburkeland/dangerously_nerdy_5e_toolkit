import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import '../../test_doubles/hive_test_harness.dart';
import 'cold_iron_pass_11_sync_liveness_test.dart';

BlobRef _sampleRef({
  String sha256Hex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  int byteSize = 1024,
  int width = 800,
  int height = 600,
  BlobFormat format = BlobFormat.webp,
}) {
  return BlobRef(
    sha256Hex: sha256Hex,
    byteSize: byteSize,
    width: width,
    height: height,
    format: format,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Map slice 1.1: Active Map in Campaign Suite', () {
    test('A2 (fault isolation): divergent map refs at same non-zero ts produces fault on activeMap and keeps local map', () {
      final reconciler = RoomStateReconciliationService();
      const collisionStamp = HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 0,
        nodeId: 'node_a',
      );
      final refA = _sampleRef(sha256Hex: 'a' * 64);
      final refB = _sampleRef(sha256Hex: 'b' * 64);

      final localProfile = CampaignProfile.raw(
        id: 'camp_fault',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Local Name',
          timestamp: collisionStamp,
        ),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Old Local Notes',
          timestamp: collisionStamp,
        ),
        activeMapRegister: CrdtLwwRegister<BlobRef?>(
          value: refA,
          timestamp: collisionStamp,
        ),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: const RoomNodeState.empty(),
      );

      const newerRemoteStamp = HybridLogicalClock(
        physicalTime: 1700000001000,
        logicalCounter: 0,
        nodeId: 'node_remote',
      );
      final remoteProfile = CampaignProfile.raw(
        id: 'camp_fault',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Local Name',
          timestamp: collisionStamp,
        ),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'New Remote Notes',
          timestamp: newerRemoteStamp,
        ),
        activeMapRegister: CrdtLwwRegister<BlobRef?>(
          value: refB,
          timestamp: collisionStamp, // Collision at non-zero timestamp with different values
        ),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: const RoomNodeState.empty(),
      );

      final result = reconciler.reconcileProfileSafely(
        local: localProfile,
        remote: remoteProfile,
      );

      expect(result.fieldFaults.length, equals(1));
      expect(result.fieldFaults.first.field, equals('activeMap'));
      expect(result.profile.activeMap, equals(refA), reason: 'Local map must be kept on fault');
      expect(result.profile.notesMarkdown, equals('New Remote Notes'), reason: 'Remote newer notes must be adopted');
    });

    group('A3 (storage and wire format)', () {
      test('round trip through DTO and JSON preserves no map, with map, and cleared map', () {
        const t1 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
        const t2 = HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1');
        final ref = _sampleRef();

        final clk = StatefulHlcClock(replicaId: ReplicaId('n1'));
        final base = createBaseProfile('ROOM_A3', clk, 'n1');

        final cases = <CampaignProfile>[
          base, // no map
          base.withActiveMap(ref, t1), // with map
          base.withActiveMap(ref, t1).withActiveMap(null, t2), // cleared map at non-zero ts
        ];

        for (final profile in cases) {
          final dto = CampaignProfileDto.fromDomain(profile);
          final map = dto.toMap();
          final jsonStr = json.encode(map);
          final decodedMap = json.decode(jsonStr) as Map<String, dynamic>;
          final parsedDto = CampaignProfileDto.fromMap(decodedMap);
          final roundTripped = parsedDto.toDomain();

          expect(roundTripped, equals(profile));
          expect(roundTripped.activeMapRegister, equals(profile.activeMapRegister));
        }
      });

      test('hand-built legacy map without activeMapRegister loads as noActiveMap', () {
        final legacyMap = <String, dynamic>{
          'id': 'legacy_camp',
          'name': 'Legacy Campaign',
          'notes': 'Legacy Notes',
          'nameRegister': {
            'v': 'Legacy Campaign',
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'notesRegister': {
            'v': 'Legacy Notes',
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'nodeId': 'n1',
          'recordVersion': 1,
        };

        final dto = CampaignProfileDto.fromMap(legacyMap);
        final profile = dto.toDomain();
        expect(profile.activeMap, isNull);
        expect(profile.activeMapRegister, equals(CampaignProfile.noActiveMap));
      });

      test('fromMap throws FormatException on invalid activeMapRegister shapes', () {
        Map<String, dynamic> makePayload(dynamic activeMapReg) => {
          'id': 'bad_camp',
          'recordVersion': 1,
          'activeMapRegister': activeMapReg,
        };

        // string activeMapRegister
        expect(
          () => CampaignProfileDto.fromMap(makePayload('not a map')),
          throwsA(isA<FormatException>()),
        );

        // v is a string
        expect(
          () => CampaignProfileDto.fromMap(makePayload({
            'v': 'bad_val',
            'ts': {'p': 100, 'l': 0, 'n': 'n1'},
          })),
          throwsA(isA<FormatException>()),
        );

        // v is a number
        expect(
          () => CampaignProfileDto.fromMap(makePayload({
            'v': 12345,
            'ts': {'p': 100, 'l': 0, 'n': 'n1'},
          })),
          throwsA(isA<FormatException>()),
        );

        // missing ts
        expect(
          () => CampaignProfileDto.fromMap(makePayload({
            'v': null,
          })),
          throwsA(isA<FormatException>()),
        );

        // bad ref B1 categories
        Map<String, dynamic> makeWithRef(Map<String, dynamic> refMap) => makePayload({
          'v': refMap,
          'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
        });

        // 1. bad hash (63 chars)
        expect(
          () => CampaignProfileDto.fromMap(makeWithRef({
            'sha256Hex': 'a' * 63,
            'byteSize': 100,
            'width': 100,
            'height': 100,
            'format': 'webp',
          })),
          throwsA(isA<FormatException>()),
        );

        // 2. bad byteSize (0)
        expect(
          () => CampaignProfileDto.fromMap(makeWithRef({
            'sha256Hex': 'a' * 64,
            'byteSize': 0,
            'width': 100,
            'height': 100,
            'format': 'webp',
          })),
          throwsA(isA<FormatException>()),
        );

        // 3. bad pixels (width: 4097)
        expect(
          () => CampaignProfileDto.fromMap(makeWithRef({
            'sha256Hex': 'a' * 64,
            'byteSize': 100,
            'width': 4097,
            'height': 100,
            'format': 'webp',
          })),
          throwsA(isA<FormatException>()),
        );

        // 4. bad format ('png')
        expect(
          () => CampaignProfileDto.fromMap(makeWithRef({
            'sha256Hex': 'a' * 64,
            'byteSize': 100,
            'width': 100,
            'height': 100,
            'format': 'png',
          })),
          throwsA(isA<FormatException>()),
        );

        // 5. extra key
        expect(
          () => CampaignProfileDto.fromMap(makeWithRef({
            'sha256Hex': 'a' * 64,
            'byteSize': 100,
            'width': 100,
            'height': 100,
            'format': 'webp',
            'extraKey': 1,
          })),
          throwsA(isA<FormatException>()),
        );
      });

      test('RoomSyncPayloadMapper preserves activeMapRegister with recordVersion == 1', () {
        const t = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'node_dm');
        final ref = _sampleRef();
        final profile = CampaignProfile.raw(
          id: 'camp_sync',
          nameRegister: const CrdtLwwRegister<String>(value: 'Room', timestamp: t),
          notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: t),
          activeMapRegister: CrdtLwwRegister<BlobRef?>(value: ref, timestamp: t),
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        const mapper = RoomSyncPayloadMapper();
        final serialized = mapper.serializeFullProfileSync(
          profile: profile,
          originNodeId: 'node_dm',
          originSeq: 1,
          timestamp: 1000,
        );

        final decoded = json.decode(serialized) as Map<String, dynamic>;
        final campaignPayload = decoded['payload'] as Map<String, dynamic>;
        expect(campaignPayload['recordVersion'], equals(1));

        final msg = mapper.parsePayload(serialized);
        expect(msg, isA<FullProfileSyncMessage>());
        final parsed = (msg as FullProfileSyncMessage).profile;
        expect(parsed.activeMapRegister, equals(profile.activeMapRegister));
        expect(parsed.activeMap, equals(ref));
      });
    });

    group('A4 (backup)', () {
      final harness = HiveTestHarness();
      late StatefulHlcClock clock;
      late DmBackupService dmBackupService;
      late CampaignProfileService campaignService;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await harness.setUpInMemory();
        await initServiceLocator();
        clock = sl<StatefulHlcClock>();
        campaignService = CampaignProfileService();
        campaignService.clearCacheForTesting();
        dmBackupService = DmBackupService(clock: clock);
      });

      tearDown(() async {
        sl.reset();
        await harness.tearDown();
      });

      test('exportProfileJson then validateAndImportProfile keeps the map with new id', () async {
        final t = clock.nextTimestamp();
        final ref = _sampleRef();
        final base = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Original Map Campaign',
        ).withActiveMap(ref, t);

        final jsonExport = dmBackupService.exportProfileJson(base);
        final imported = await dmBackupService.validateAndImportProfile(jsonExport);

        expect(imported, isNotNull);
        expect(imported!.id, isNot(equals(base.id)));
        expect(imported.name, equals('Original Map Campaign'));
        expect(imported.activeMap, equals(ref));
        expect(imported.activeMapRegister, equals(base.activeMapRegister));
      });

      test('full system snapshot export and restore keeps the map on every restored campaign', () async {
        final t = clock.nextTimestamp();
        final ref1 = _sampleRef(sha256Hex: '1' * 64);
        final ref2 = _sampleRef(sha256Hex: '2' * 64);

        final camp1 = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Camp 1',
        ).copyWith(id: 'c1').withActiveMap(ref1, t);

        final camp2 = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Camp 2',
        ).copyWith(id: 'c2').withActiveMap(ref2, t);

        await campaignService.saveProfileImmediate(camp1);
        await campaignService.saveProfileImmediate(camp2);

        final snapshotJson = await dmBackupService.exportFullSystemSnapshot();

        // Mutate local campaigns to verify restore overwrites them back with maps
        await campaignService.saveProfileImmediate(camp1.withActiveMap(null, t));
        await campaignService.saveProfileImmediate(camp2.withActiveMap(null, t));
        final mutated1 = await campaignService.getProfile('c1');
        expect(mutated1!.activeMap, isNull);

        final restored = await dmBackupService.restoreFullSystemSnapshot(snapshotJson);
        expect(restored, isTrue);

        final loaded = await campaignService.loadAllProfiles();
        final loadedC1 = loaded.firstWhere((p) => p.id == 'c1');
        final loadedC2 = loaded.firstWhere((p) => p.id == 'c2');

        expect(loadedC1.activeMap, equals(ref1));
        expect(loadedC1.activeMapRegister, equals(camp1.activeMapRegister));
        expect(loadedC2.activeMap, equals(ref2));
        expect(loadedC2.activeMapRegister, equals(camp2.activeMapRegister));
      });

      test('future map timestamp (+10 years) is refused and violations names activeMapRegister', () async {
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final tenYearsMs = nowMs + const Duration(days: 3650).inMilliseconds;
        final farFutureStamp = HybridLogicalClock(
          physicalTime: tenYearsMs,
          logicalCounter: 0,
          nodeId: 'future_node',
        );

        final base = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Future Map Campaign',
        );
        final ref = _sampleRef();
        final futureMapProfile = base.copyWith(
          id: 'camp_future_map',
          activeMapRegister: CrdtLwwRegister<BlobRef?>(
            value: ref,
            timestamp: farFutureStamp,
          ),
        );

        final violations = futureTimestampViolations(
          futureMapProfile,
          nowMs,
          const Duration(minutes: 5),
        );
        expect(violations, contains('activeMapRegister'));

        final exportJson = dmBackupService.exportProfileJson(futureMapProfile);
        final imported = await dmBackupService.validateAndImportProfile(exportJson);
        expect(imported, isNull, reason: 'validateAndImportProfile must refuse future map timestamp');
      });
    });

    test('A5 (drift check on sync): far-future map timestamp routes to deadLetters, control applies', () async {
      final bus = TestP2pBus(seed: 42);
      const shortTick = Duration(milliseconds: 10);
      final player = DeviceHarness.create(
        nodeId: 'player',
        bus: bus,
        roomCode: 'DRIFT_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: const Duration(hours: 1),
      );

      final base = createBaseProfile('DRIFT_ROOM', player.clock, 'player');
      await player.repo.putProfile(base);
      player.orchestrator.startSynchronization();

      final ref = _sampleRef();
      final tenYearsMs = DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(days: 3650).inMilliseconds;
      final futureStamp = HybridLogicalClock(
        physicalTime: tenYearsMs,
        logicalCounter: 0,
        nodeId: 'malicious_peer',
      );

      final poisonedProfile = base.copyWith(
        activeMapRegister: CrdtLwwRegister<BlobRef?>(value: ref, timestamp: futureStamp),
        notesRegister: CrdtLwwRegister<String>(
          value: 'Poisoned Notes',
          timestamp: player.clock.nextTimestamp(),
        ),
      );

      const mapper = RoomSyncPayloadMapper();
      final poisonedPayload = mapper.serializeFullProfileSync(
        profile: poisonedProfile,
        originNodeId: 'malicious_peer',
        originSeq: 1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await player.orchestrator.handleIncomingPayload(poisonedPayload);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(player.deadLetters, isNotEmpty);
      expect(player.deadLetters.last.error, isA<HlcFutureDriftException>());
      expect(player.repo.activeProfile!.activeMap, isNull);
      expect(player.repo.activeProfile!.notesMarkdown, equals('Base Notes'));

      // Control: valid current timestamp payload applies cleanly
      final validStamp = HybridLogicalClock(
        physicalTime: DateTime.now().toUtc().millisecondsSinceEpoch,
        logicalCounter: 0,
        nodeId: 'valid_peer',
      );
      final validProfile = base.copyWith(
        activeMapRegister: CrdtLwwRegister<BlobRef?>(value: ref, timestamp: validStamp),
        notesRegister: CrdtLwwRegister<String>(
          value: 'Valid Notes',
          timestamp: validStamp,
        ),
      );
      final validPayload = mapper.serializeFullProfileSync(
        profile: validProfile,
        originNodeId: 'valid_peer',
        originSeq: 2,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await player.orchestrator.handleIncomingPayload(validPayload);
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(player.repo.activeProfile!.activeMap, equals(ref));
      expect(player.repo.activeProfile!.notesMarkdown, equals('Valid Notes'));

      player.dispose();
    });

    test('A6 (late joiner): detached player attaches, converges activeMap within two anti-entropy intervals; DM clears and player follows', () async {
      final bus = TestP2pBus(seed: 99);
      const shortTick = Duration(milliseconds: 10);
      const fastAntiEntropy = Duration(milliseconds: 30);

      final dm = DeviceHarness.create(
        nodeId: 'dm',
        bus: bus,
        roomCode: 'MAP_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastAntiEntropy,
        isHost: true,
      );

      final base = createBaseProfile('MAP_ROOM', dm.clock, 'dm');
      final ref = _sampleRef();
      final dmStamp = dm.clock.nextTimestamp();
      final dmWithMap = base.withActiveMap(ref, dmStamp);

      await dm.repo.putProfile(dmWithMap);
      dm.orchestrator.startSynchronization();

      // Player is detached initially
      final player = DeviceHarness.create(
        nodeId: 'player',
        bus: bus,
        roomCode: 'MAP_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastAntiEntropy,
      );
      player.node.isAttached = false;
      await player.repo.putProfile(base);
      player.orchestrator.startSynchronization();

      expect(player.repo.activeProfile!.activeMap, isNull);

      // Player attaches
      player.node.isAttached = true;

      // Within two antiEntropyIntervals (2 * 30ms = 60ms + buffer), player's activeMap equals DM's
      await Future<void>.delayed(fastAntiEntropy * 2 + const Duration(milliseconds: 20));

      expect(player.repo.activeProfile!.activeMap, equals(ref));
      expect(player.repo.activeProfile!.activeMapRegister, equals(dmWithMap.activeMapRegister));

      // DM clears the map
      final clearStamp = dm.clock.nextTimestamp();
      await dm.repo.updateProfile(base.id, (c) => c.withActiveMap(null, clearStamp));

      // Within two antiEntropyIntervals, player follows
      await Future<void>.delayed(fastAntiEntropy * 2 + const Duration(milliseconds: 20));

      expect(player.repo.activeProfile!.activeMap, isNull);
      expect(player.repo.activeProfile!.activeMapRegister, equals(dm.repo.activeProfile!.activeMapRegister));

      dm.dispose();
      player.dispose();
    });
  });
}
