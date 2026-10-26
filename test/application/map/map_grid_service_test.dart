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

    test('GC4: applyEdit, toggleVisible, setCornerAt, and MapGridEdit.merge', () async {
      final mapRefA = BlobRef(
        sha256Hex: 'a' * 64,
        byteSize: 1000,
        width: 800,
        height: 600,
        format: BlobFormat.webp,
      );
      final mapRefB = BlobRef(
        sha256Hex: 'b' * 64,
        byteSize: 1000,
        width: 800,
        height: 600,
        format: BlobFormat.webp,
      );

      // MapGridEdit.merge keeps later value of each field
      const edit1 = MapGridEdit(cellCentiPx: 4000, offsetXCentiPx: 100);
      const edit2 = MapGridEdit(cellCentiPx: 6000, feetPerCell: 10);
      final merged = edit1.merge(edit2);
      expect(merged.cellCentiPx, equals(6000));
      expect(merged.offsetXCentiPx, equals(100));
      expect(merged.feetPerCell, equals(10));
      expect(merged.offsetYCentiPx, isNull);

      // applyEdit on a profile with no grid writes nothing
      final stampBefore1 = repo.activeProfile!.mapGridRegister.timestamp;
      await service.applyEdit('camp-1', mapRefA, const MapGridEdit(cellCentiPx: 4000));
      expect(repo.activeProfile!.mapGrid, isNull);
      expect(repo.activeProfile!.mapGridRegister.timestamp, equals(stampBefore1));

      // setCornerAt with no grid writes nothing
      final stampBefore2 = repo.activeProfile!.mapGridRegister.timestamp;
      await service.setCornerAt('camp-1', mapRefA, 50.0, 50.0);
      expect(repo.activeProfile!.mapGrid, isNull);
      expect(repo.activeProfile!.mapGridRegister.timestamp, equals(stampBefore2));

      // toggleVisible goes default -> hidden -> shown
      await service.toggleVisible('camp-1', mapRefA);
      final gDefault = repo.activeProfile!.mapGrid!;
      expect(gDefault.mapSha256Hex, equals(mapRefA.sha256Hex));
      expect(gDefault.visible, isTrue);
      expect(gDefault.cellCentiPx, equals(5000));

      await service.toggleVisible('camp-1', mapRefA);
      final gHidden = repo.activeProfile!.mapGrid!;
      expect(gHidden.visible, isFalse);
      expect(gHidden.cellCentiPx, equals(5000));

      await service.toggleVisible('camp-1', mapRefA);
      final gShown = repo.activeProfile!.mapGrid!;
      expect(gShown.visible, isTrue);
      expect(gShown.cellCentiPx, equals(5000));

      // applyEdit on a profile with a grid for another hash writes nothing
      final stampBefore3 = repo.activeProfile!.mapGridRegister.timestamp;
      await service.applyEdit('camp-1', mapRefB, const MapGridEdit(cellCentiPx: 3000));
      expect(repo.activeProfile!.mapGrid!.mapSha256Hex, equals(mapRefA.sha256Hex));
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5000));
      expect(repo.activeProfile!.mapGridRegister.timestamp, equals(stampBefore3));

      // applyEdit sets only the fields in the edit and reduces offsets modulo the new cell size
      await service.setGrid('camp-1', MapGrid(
        mapSha256Hex: mapRefA.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 4500,
        offsetYCentiPx: 4800,
        feetPerCell: 5,
        visible: true,
      ));
      await service.applyEdit('camp-1', mapRefA, const MapGridEdit(cellCentiPx: 4000));
      final gEdited = repo.activeProfile!.mapGrid!;
      expect(gEdited.cellCentiPx, equals(4000));
      expect(gEdited.offsetXCentiPx, equals(500)); // 4500 % 4000 = 500
      expect(gEdited.offsetYCentiPx, equals(800)); // 4800 % 4000 = 800
      expect(gEdited.feetPerCell, equals(5));
      expect(gEdited.visible, isTrue);
    });
  });
}
