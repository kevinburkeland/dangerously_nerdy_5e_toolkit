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

MapGrid _sampleGrid({
  String mapSha256Hex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  int cellCentiPx = 5000,
  int offsetXCentiPx = 0,
  int offsetYCentiPx = 0,
  int feetPerCell = 5,
  bool visible = true,
}) {
  return MapGrid(
    mapSha256Hex: mapSha256Hex,
    cellCentiPx: cellCentiPx,
    offsetXCentiPx: offsetXCentiPx,
    offsetYCentiPx: offsetYCentiPx,
    feetPerCell: feetPerCell,
    visible: visible,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Map slice 1.4: Grid Sync, Storage, and Durability Suite', () {
    test('GS2 (fault isolation): divergent grids at same non-zero timestamp produce exactly one fault on mapGrid, keep local grid, and take newer remote notes', () {
      final reconciler = RoomStateReconciliationService();
      const collisionStamp = HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 0,
        nodeId: 'node_local',
      );
      final gridA = _sampleGrid(cellCentiPx: 4000);
      final gridB = _sampleGrid(cellCentiPx: 6000);

      final localProfile = CampaignProfile.raw(
        id: 'camp_fault_grid',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Local Name',
          timestamp: collisionStamp,
        ),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Old Local Notes',
          timestamp: collisionStamp,
        ),
        mapGridRegister: CrdtLwwRegister<MapGrid?>(
          value: gridA,
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
        id: 'camp_fault_grid',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Local Name',
          timestamp: collisionStamp,
        ),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'New Remote Notes',
          timestamp: newerRemoteStamp,
        ),
        mapGridRegister: CrdtLwwRegister<MapGrid?>(
          value: gridB,
          timestamp: collisionStamp, // Collision at same non-zero timestamp
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
      expect(result.fieldFaults.first.field, equals('mapGrid'));
      expect(result.profile.mapGrid, equals(gridA), reason: 'Local grid must be kept on fault');
      expect(result.profile.notesMarkdown, equals('New Remote Notes'), reason: 'Remote newer notes must be adopted');
    });

    group('GS3 (storage and wire format)', () {
      test('round trip through DTO and JSON preserves no grid, with grid, and cleared grid', () {
        const t1 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
        const t2 = HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1');
        final grid = _sampleGrid();

        final clk = StatefulHlcClock(replicaId: ReplicaId('n1'));
        final base = createBaseProfile('ROOM_GS3', clk, 'n1');

        final cases = <CampaignProfile>[
          base, // no grid
          base.withMapGrid(grid, t1), // with grid
          base.withMapGrid(grid, t1).withMapGrid(null, t2), // cleared grid at non-zero ts
        ];

        for (final profile in cases) {
          final dto = CampaignProfileDto.fromDomain(profile);
          final map = dto.toMap();
          final jsonStr = json.encode(map);
          final decodedMap = json.decode(jsonStr) as Map<String, dynamic>;
          final parsedDto = CampaignProfileDto.fromMap(decodedMap);
          final roundTripped = parsedDto.toDomain();

          expect(roundTripped, equals(profile));
          expect(roundTripped.mapGridRegister, equals(profile.mapGridRegister));
        }
      });

      test('format 60cae35 writes without mapGridRegister key loads as noMapGrid and keeps activeMapRegister', () {
        final legacyMap = <String, dynamic>{
          'id': 'legacy_camp_60cae35',
          'name': 'Legacy 60cae35 Campaign',
          'notes': 'Legacy Notes',
          'nameRegister': {
            'v': 'Legacy 60cae35 Campaign',
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'notesRegister': {
            'v': 'Legacy Notes',
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'activeMapRegister': {
            'v': {
              'sha256Hex': 'a' * 64,
              'byteSize': 1024,
              'width': 800,
              'height': 600,
              'format': 'webp',
            },
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'nodeId': 'n1',
          'recordVersion': 1,
        };

        final dto = CampaignProfileDto.fromMap(legacyMap);
        final profile = dto.toDomain();
        expect(profile.mapGrid, isNull);
        expect(profile.mapGridRegister, equals(CampaignProfile.noMapGrid));
        expect(profile.activeMap, isNotNull);
        expect(profile.activeMap!.sha256Hex, equals('a' * 64));
      });

      test('fromMap throws FormatException on invalid mapGridRegister shapes and bad grid categories', () {
        Map<String, dynamic> makePayload(dynamic mapGridReg) => {
          'id': 'bad_camp_grid',
          'recordVersion': 1,
          'mapGridRegister': mapGridReg,
        };

        // string mapGridRegister
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

        // bad grid from each G1 category
        Map<String, dynamic> makeWithGrid(Map<String, dynamic> gridMap) => makePayload({
          'v': gridMap,
          'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
        });

        // 1. bad hash (63 chars)
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 63,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 1b. bad hash (65 chars)
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 65,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 1c. bad hash (uppercase)
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': '${'a' * 63}A',
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 1d. bad hash ('g')
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': '${'a' * 63}g',
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 2. cellCentiPx 999
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 999,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 2b. cellCentiPx 51201
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 51201,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 3. offsetXCentiPx -1
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': -1,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 3b. offsetXCentiPx == cellCentiPx
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 5000,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 4. offsetYCentiPx -1
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': -1,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 4b. offsetYCentiPx == cellCentiPx
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 5000,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 5. feetPerCell 0
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 0,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 5b. feetPerCell 101
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 101,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 6. missing key
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            // missing 'visible'
          })),
          throwsA(isA<FormatException>()),
        );

        // 7. extra key
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
            'extra': 123,
          })),
          throwsA(isA<FormatException>()),
        );

        // 8. visible: 1
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': 1,
          })),
          throwsA(isA<FormatException>()),
        );

        // 8b. visible: "true"
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': 'true',
          })),
          throwsA(isA<FormatException>()),
        );

        // 9. feetPerCell: "5"
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': 5000,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': '5',
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );

        // 10. cellCentiPx: null
        expect(
          () => CampaignProfileDto.fromMap(makeWithGrid({
            'mapSha256Hex': 'a' * 64,
            'cellCentiPx': null,
            'offsetXCentiPx': 0,
            'offsetYCentiPx': 0,
            'feetPerCell': 5,
            'visible': true,
          })),
          throwsA(isA<FormatException>()),
        );
      });

      test('RoomSyncPayloadMapper preserves mapGridRegister with recordVersion == 1', () {
        const t = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'node_dm');
        final grid = _sampleGrid();
        final profile = CampaignProfile.raw(
          id: 'camp_sync_grid',
          nameRegister: const CrdtLwwRegister<String>(value: 'Room', timestamp: t),
          notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: t),
          mapGridRegister: CrdtLwwRegister<MapGrid?>(value: grid, timestamp: t),
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
        expect(parsed.mapGridRegister, equals(profile.mapGridRegister));
        expect(parsed.mapGrid, equals(grid));
      });
    });

    group('GS4 (backup)', () {
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

      test('exportProfileJson then validateAndImportProfile keeps the grid with new id', () async {
        final t = clock.nextTimestamp();
        final grid = _sampleGrid();
        final base = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Original Grid Campaign',
        ).withMapGrid(grid, t);

        final jsonExport = dmBackupService.exportProfileJson(base);
        final imported = await dmBackupService.validateAndImportProfile(jsonExport);

        expect(imported, isNotNull);
        expect(imported!.id, isNot(equals(base.id)));
        expect(imported.name, equals('Original Grid Campaign'));
        expect(imported.mapGrid, equals(grid));
        expect(imported.mapGridRegister, equals(base.mapGridRegister));
      });

      test('full system snapshot export and restore keeps the grid on every restored campaign', () async {
        final t = clock.nextTimestamp();
        final grid1 = _sampleGrid(cellCentiPx: 4500);
        final grid2 = _sampleGrid(cellCentiPx: 5500);

        final camp1 = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Camp 1 Grid',
        ).copyWith(id: 'c1').withMapGrid(grid1, t);

        final camp2 = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Camp 2 Grid',
        ).copyWith(id: 'c2').withMapGrid(grid2, t);

        await campaignService.saveProfileImmediate(camp1);
        await campaignService.saveProfileImmediate(camp2);

        final snapshotJson = await dmBackupService.exportFullSystemSnapshot();

        // Mutate local campaigns to verify restore overwrites them back with grids
        await campaignService.saveProfileImmediate(camp1.withMapGrid(null, t));
        await campaignService.saveProfileImmediate(camp2.withMapGrid(null, t));
        final mutated1 = await campaignService.getProfile('c1');
        expect(mutated1!.mapGrid, isNull);

        final restored = await dmBackupService.restoreFullSystemSnapshot(snapshotJson);
        expect(restored, isTrue);

        final loaded = await campaignService.loadAllProfiles();
        final loadedC1 = loaded.firstWhere((p) => p.id == 'c1');
        final loadedC2 = loaded.firstWhere((p) => p.id == 'c2');

        expect(loadedC1.mapGrid, equals(grid1));
        expect(loadedC1.mapGridRegister, equals(camp1.mapGridRegister));
        expect(loadedC2.mapGrid, equals(grid2));
        expect(loadedC2.mapGridRegister, equals(camp2.mapGridRegister));
      });

      test('future grid timestamp (+10 years) is refused and violations names mapGridRegister', () async {
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
          name: 'Future Grid Campaign',
        );
        final grid = _sampleGrid();
        final futureGridProfile = base.copyWith(
          id: 'camp_future_grid',
          mapGridRegister: CrdtLwwRegister<MapGrid?>(
            value: grid,
            timestamp: farFutureStamp,
          ),
        );

        final violations = futureTimestampViolations(
          futureGridProfile,
          nowMs,
          const Duration(minutes: 5),
        );
        expect(violations, contains('mapGridRegister'));

        final exportJson = dmBackupService.exportProfileJson(futureGridProfile);
        final imported = await dmBackupService.validateAndImportProfile(exportJson);
        expect(imported, isNull, reason: 'validateAndImportProfile must refuse future grid timestamp');
      });
    });

    test('GS5 (late joiner): detached player attaches, converges mapGrid within two anti-entropy intervals; DM hides grid (visible: false) and player follows', () async {
      final bus = TestP2pBus(seed: 99);
      const shortTick = Duration(milliseconds: 10);
      const fastAntiEntropy = Duration(milliseconds: 30);

      final dm = DeviceHarness.create(
        nodeId: 'dm',
        bus: bus,
        roomCode: 'GRID_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastAntiEntropy,
        isHost: true,
      );

      final base = createBaseProfile('GRID_ROOM', dm.clock, 'dm');
      final mapRef = _sampleRef();
      final grid = _sampleGrid(mapSha256Hex: mapRef.sha256Hex);
      final dmStamp1 = dm.clock.nextTimestamp();
      final dmStamp2 = dm.clock.nextTimestamp();
      final dmWithMapAndGrid = base
          .withActiveMap(mapRef, dmStamp1)
          .withMapGrid(grid, dmStamp2);

      await dm.repo.putProfile(dmWithMapAndGrid);
      dm.orchestrator.startSynchronization();

      // Player is detached initially
      final player = DeviceHarness.create(
        nodeId: 'player',
        bus: bus,
        roomCode: 'GRID_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastAntiEntropy,
      );
      player.node.isAttached = false;
      await player.repo.putProfile(base);
      player.orchestrator.startSynchronization();

      expect(player.repo.activeProfile!.mapGrid, isNull);

      // Player attaches
      player.node.isAttached = true;

      // Within two antiEntropyIntervals (2 * 30ms = 60ms + buffer), player's mapGrid equals DM's
      await Future<void>.delayed(fastAntiEntropy * 2 + const Duration(milliseconds: 20));

      expect(player.repo.activeProfile!.mapGrid, equals(grid));
      expect(player.repo.activeProfile!.mapGridRegister, equals(dmWithMapAndGrid.mapGridRegister));

      // DM hides the grid (visible: false)
      final hideStamp = dm.clock.nextTimestamp();
      final hiddenGrid = MapGrid(
        mapSha256Hex: grid.mapSha256Hex,
        cellCentiPx: grid.cellCentiPx,
        offsetXCentiPx: grid.offsetXCentiPx,
        offsetYCentiPx: grid.offsetYCentiPx,
        feetPerCell: grid.feetPerCell,
        visible: false,
      );
      await dm.repo.updateProfile(base.id, (c) => c.withMapGrid(hiddenGrid, hideStamp));

      // Within two antiEntropyIntervals, player follows
      await Future<void>.delayed(fastAntiEntropy * 2 + const Duration(milliseconds: 20));

      expect(player.repo.activeProfile!.mapGrid, equals(hiddenGrid));
      expect(player.repo.activeProfile!.mapGrid!.visible, isFalse);
      expect(player.repo.activeProfile!.mapGridRegister, equals(dm.repo.activeProfile!.mapGridRegister));

      dm.dispose();
      player.dispose();
    });
  });
}
