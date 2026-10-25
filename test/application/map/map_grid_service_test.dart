import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';

import '../../test_doubles/fake_campaign_repository.dart';

void main() {
  group('MapGridService (GC1)', () {
    late FakeCampaignRepository repo;
    late StatefulHlcClock clock;
    late MapGridService service;

    setUp(() {
      const stamp = HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 0,
        nodeId: 'node-1',
      );
      final profile = CampaignProfile.raw(
        id: 'camp-1',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Camp 1',
          timestamp: stamp,
        ),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: stamp,
        ),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: const RoomNodeState.empty(),
      );
      repo = FakeCampaignRepository(profile);
      clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      service = MapGridService(campaignRepo: repo, clock: clock);
    });

    test('defaultGridFor returns valid standard grid', () {
      final mapRef = BlobRef(
        sha256Hex: 'a' * 64,
        byteSize: 1000,
        width: 800,
        height: 600,
        format: BlobFormat.webp,
      );
      final grid = service.defaultGridFor(mapRef);
      expect(grid.mapSha256Hex, equals('a' * 64));
      expect(grid.cellCentiPx, equals(5000));
      expect(grid.offsetXCentiPx, equals(0));
      expect(grid.offsetYCentiPx, equals(0));
      expect(grid.feetPerCell, equals(5));
      expect(grid.visible, isTrue);
    });

    test('setGrid writes a register with a fresh, increasing timestamp each call, setGrid(null) clears it, and timestamp is never genesis', () async {
      final grid1 = MapGrid(
        mapSha256Hex: 'a' * 64,
        cellCentiPx: 4000,
        offsetXCentiPx: 100,
        offsetYCentiPx: 200,
        feetPerCell: 5,
        visible: true,
      );

      await service.setGrid('camp-1', grid1);
      final p1 = repo.activeProfile!;
      expect(p1.mapGrid, equals(grid1));
      final ts1 = p1.mapGridRegister.timestamp;
      expect(ts1, isNot(equals(HybridLogicalClock.genesis)));
      expect(ts1.physicalTime, greaterThan(0));

      final grid2 = MapGrid(
        mapSha256Hex: 'a' * 64,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 10,
        visible: true,
      );

      await service.setGrid('camp-1', grid2);
      final p2 = repo.activeProfile!;
      expect(p2.mapGrid, equals(grid2));
      final ts2 = p2.mapGridRegister.timestamp;
      expect(ts2.compareTo(ts1), greaterThan(0));
      expect(ts2, isNot(equals(HybridLogicalClock.genesis)));

      // setGrid(null) clears it
      await service.setGrid('camp-1', null);
      final p3 = repo.activeProfile!;
      expect(p3.mapGrid, isNull);
      final ts3 = p3.mapGridRegister.timestamp;
      expect(ts3.compareTo(ts2), greaterThan(0));
      expect(ts3, isNot(equals(HybridLogicalClock.genesis)));
    });
  });
}
