import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/grid_geometry.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_grid_controls.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_view.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';

class CountingCampaignRepository extends FakeCampaignRepository {
  int serviceWritesCount = 0;

  CountingCampaignRepository([super.initial]);

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = profiles[id];
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    if (!identical(updated, current) &&
        updated.mapGridRegister.timestamp != current.mapGridRegister.timestamp) {
      serviceWritesCount++;
    }
    await putProfile(updated);
    return updated;
  }
}

Uint8List _makeValidJpeg() {
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00, 0x7F, 0x00, 0xFF, 0xD9,
  ]);
}

CampaignProfile _makeProfile({
  String id = 'camp-1',
  BlobRef? mapRef,
  MapGrid? grid,
  HybridLogicalClock? timestamp,
}) {
  final stamp = timestamp ??
      const HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 0,
        nodeId: 'node-1',
      );
  return CampaignProfile.raw(
    id: id,
    nameRegister: CrdtLwwRegister<String>(
      value: 'Camp 1',
      timestamp: stamp,
    ),
    notesRegister: CrdtLwwRegister<String>(
      value: '',
      timestamp: stamp,
    ),
    activeMapRegister: CrdtLwwRegister<BlobRef?>(
      value: mapRef,
      timestamp: stamp,
    ),
    mapGridRegister: CrdtLwwRegister<MapGrid?>(
      value: grid,
      timestamp: stamp,
    ),
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    roomState: const RoomNodeState.empty(),
  );
}

void main() {
  group('MapGridEditSuite (GR1-GR9, GL1)', () {
    late FakeBlobNetwork network;
    late FakeBlobStore store;
    late CountingCampaignRepository repo;
    late StatefulHlcClock clock;
    late BlobTransferService transfer;
    late ActiveMapController controller;
    late MapGridService gridService;
    late TransformationController transformController;

    late Uint8List mapBytes;
    late BlobRef mapRef;
    late MapGrid initialGrid;

    setUp(() {
      network = FakeBlobNetwork();
      final channel = network.createChannel('me');
      store = FakeBlobStore();
      repo = CountingCampaignRepository();
      clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      transfer = BlobTransferService(
        channel: channel,
        store: store,
        servableRefs: () => activeMapServableRefs(repo),
      );
      controller = ActiveMapController(
        campaignRepo: repo,
        transfer: transfer,
        store: store,
        channel: channel,
        transportState: () => TransportState.webRtc,
      );
      gridService = MapGridService(campaignRepo: repo, clock: clock);
      transformController = TransformationController();

      mapBytes = _makeValidJpeg();
      mapRef = BlobRef(
        sha256Hex: sha256.convert(mapBytes).toString().toLowerCase(),
        byteSize: mapBytes.length,
        width: 1000,
        height: 800,
        format: BlobFormat.jpeg,
      );
      store.put(mapRef, mapBytes, campaignId: 'camp-1');

      initialGrid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
    });

    tearDown(() {
      controller.dispose();
      transformController.dispose();
    });

    Widget buildTestView({bool canEditMap = true}) {
      return MaterialApp(
        home: Scaffold(
          body: MapView(
            controller: controller,
            gridService: gridService,
            transformationController: transformController,
            canEditMap: canEditMap,
          ),
        ),
      );
    }

    testWidgets('GR1 Failing example 1: + once, 50 ms, hide. After 1 s the profile\'s grid has visible: false and the new square size. The panel is gone and no later write shows the grid. Control: hide with nothing pending stays hidden.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Control first: hide with nothing pending stays hidden
      await tester.tap(find.widgetWithText(OutlinedButton, 'Grid'));
      await tester.pumpAndSettle();
      expect(repo.activeProfile!.mapGrid!.visible, isFalse);
      expect(find.byType(MapGridControls), findsNothing);

      // Re-enable grid for the test
      await tester.tap(find.widgetWithText(OutlinedButton, 'Grid'));
      await tester.pumpAndSettle();
      expect(repo.activeProfile!.mapGrid!.visible, isTrue);
      expect(find.byType(MapGridControls), findsOneWidget);

      // Test: Press + once (increases cellSize by 0.5 px -> 50.5 px = 5050 cpx)
      await tester.tap(find.byTooltip('Increase size'));
      await tester.pump(const Duration(milliseconds: 50));

      // Press Grid to hide
      await tester.tap(find.widgetWithText(OutlinedButton, 'Grid'));
      await tester.pump(const Duration(milliseconds: 100));

      // Wait 1 second for any timers to settle
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final currentGrid = repo.activeProfile!.mapGrid;
      expect(currentGrid, isNotNull);
      expect(currentGrid!.visible, isFalse);
      expect(currentGrid.cellCentiPx, equals(5050));
      expect(find.byType(MapGridControls), findsNothing);
    });

    testWidgets('GR2 Failing example 2: + once, 50 ms, Set a corner, tap at an image point P. After 1 s the grid equals gridWithCornerAt applied at P to the grid with the new size. Control: corner with nothing pending stays.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Control: corner with nothing pending stays
      await tester.tap(find.text('Set a corner'));
      await tester.pump();
      final ivFinder = find.byType(InteractiveViewer);
      final center = tester.getCenter(ivFinder);
      await tester.tapAt(center);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final cornerControl = repo.activeProfile!.mapGrid!;
      expect(cornerControl.cellCentiPx, equals(5000));

      // Reset grid
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid, timestamp: clock.nextTimestamp()));
      await tester.pumpAndSettle();

      // Test: Press + once (size becomes 5050 cpx)
      await tester.tap(find.byTooltip('Increase size'));
      await tester.pump(const Duration(milliseconds: 50));

      // Press Set a corner
      await tester.tap(find.text('Set a corner'));
      await tester.pump();

      // Tap at an image point P
      const tapViewport = Offset(200, 200);
      final sceneP = transformController.toScene(tapViewport);
      final ivTopLeft = tester.getTopLeft(find.byType(InteractiveViewer));
      await tester.tapAt(ivTopLeft + tapViewport);
      await tester.pump(const Duration(milliseconds: 100));

      // Wait 1 s for any panel timers to fire
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final currentGrid = repo.activeProfile!.mapGrid;
      expect(currentGrid, isNotNull);
      expect(currentGrid!.cellCentiPx, equals(5050));

      final expectedGrid = gridWithCornerAt(
        MapGrid(
          mapSha256Hex: mapRef.sha256Hex,
          cellCentiPx: 5050,
          offsetXCentiPx: 0,
          offsetYCentiPx: 0,
          feetPerCell: 5,
          visible: true,
        ),
        sceneP.dx,
        sceneP.dy,
      );
      expect(currentGrid.offsetXCentiPx, equals(expectedGrid.offsetXCentiPx));
      expect(currentGrid.offsetYCentiPx, equals(expectedGrid.offsetYCentiPx));
    });

    testWidgets('GR3 Co-DM edit while a change is pending: the DM nudges right once; 100 ms later a co-DM update changes the feet to 10 and the square size to 60 px. After 1 s: feet 10, square size 60 px, X offset = the DM\'s nudged value reduced modulo 60 px. The panel shows feet 10 and size 60 as soon as the update arrives, before the timer fires.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // DM nudges right once
      await tester.tap(find.byTooltip('Nudge right'));
      await tester.pump(const Duration(milliseconds: 100));

      // 100 ms later a co-DM update changes feet to 10 and square size to 60 px (6000 cpx)
      final coDmGrid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 6000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 10,
        visible: true,
      );
      repo.putProfile(_makeProfile(
        mapRef: mapRef,
        grid: coDmGrid,
        timestamp: clock.nextTimestamp(),
      ));
      await tester.pump();

      // The panel shows feet 10 and size 60 as soon as the update arrives, before timer fires
      final sizeField = find.byType(TextField).first;
      expect(tester.widget<TextField>(sizeField).controller!.text, equals('60'));
      final feetField = find.byType(TextField).at(1);
      expect(tester.widget<TextField>(feetField).controller!.text, equals('10'));

      // Wait 1 s for settle
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final grid = repo.activeProfile!.mapGrid!;
      expect(grid.feetPerCell, equals(10));
      expect(grid.cellCentiPx, equals(6000));
      // DM's nudged value (100 cpx) reduced modulo 60 px (6000 cpx) -> 100
      expect(grid.offsetXCentiPx, equals(100 % 6000));
    });

    testWidgets('GR4 Co-DM hides the grid while the DM\'s nudge is pending: after 1 s the grid is still hidden, with the DM\'s offset.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // DM nudges right once
      await tester.tap(find.byTooltip('Nudge right'));
      await tester.pump(const Duration(milliseconds: 100));

      // Co-DM hides grid
      final hiddenGrid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: false,
      );
      repo.putProfile(_makeProfile(
        mapRef: mapRef,
        grid: hiddenGrid,
        timestamp: clock.nextTimestamp(),
      ));
      await tester.pump();

      // Wait 1 s for settle
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final grid = repo.activeProfile!.mapGrid!;
      expect(grid.visible, isFalse);
      expect(grid.offsetXCentiPx, equals(100));
    });

    testWidgets('GR5 Co-DM clears the grid (null) while the DM\'s nudge is pending: after 1 s the grid is still null, and the service wrote nothing (count writes).', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // DM nudges right once
      await tester.tap(find.byTooltip('Nudge right'));
      await tester.pump(const Duration(milliseconds: 100));

      final writesBefore = repo.serviceWritesCount;

      // Co-DM clears the grid
      repo.putProfile(_makeProfile(
        mapRef: mapRef,
        grid: null,
        timestamp: clock.nextTimestamp(),
      ));
      await tester.pump();

      // Wait 1 s
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.activeProfile!.mapGrid, isNull);
      expect(repo.serviceWritesCount, equals(writesBefore));
    });

    testWidgets('GR6 Feet field: each of 0, 101, abc, 2.5 and empty shows the message and writes nothing; 12 clears the message and writes feet 12 once, 400 ms later.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      final feetField = find.byType(TextField).at(1);
      final writesBefore = repo.serviceWritesCount;

      const badInputs = ['0', '101', 'abc', '2.5', ''];
      for (final bad in badInputs) {
        await tester.enterText(feetField, bad);
        await tester.pump();
        expect(
          find.text('Feet per square must be a whole number from 1 to 100.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(repo.serviceWritesCount, equals(writesBefore));
      }

      // Valid: 12
      await tester.enterText(feetField, '12');
      await tester.pump();
      expect(
        find.text('Feet per square must be a whole number from 1 to 100.'),
        findsNothing,
      );

      // Not written yet at 200 ms
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.activeProfile!.mapGrid!.feetPerCell, equals(5));

      // Advance past 400 ms
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(repo.activeProfile!.mapGrid!.feetPerCell, equals(12));
      expect(repo.serviceWritesCount, equals(writesBefore + 1));
    });

    testWidgets('GR7 An invalid size typed while a nudge is pending: the message shows, and 400 ms after the nudge the nudge is written with the old size.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Nudge right once
      await tester.tap(find.byTooltip('Nudge right'));
      await tester.pump(const Duration(milliseconds: 100));

      // Type invalid size
      final sizeField = find.byType(TextField).first;
      await tester.enterText(sizeField, '9');
      await tester.pump();

      expect(find.text('Square size must be between 10 and 512 px.'), findsOneWidget);

      // Wait remaining 350 ms
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final grid = repo.activeProfile!.mapGrid!;
      expect(grid.cellCentiPx, equals(5000)); // Old size preserved
      expect(grid.offsetXCentiPx, equals(100)); // Nudge written
    });

    testWidgets('GR8 The DM leaves the screen with a nudge pending: the nudge is written at once, and once only (no second write after 400 ms).', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Nudge right once
      await tester.tap(find.byTooltip('Nudge right'));
      await tester.pump(const Duration(milliseconds: 100));

      final writesBefore = repo.serviceWritesCount;

      // Leave screen by pumping another widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Gone'))));
      await tester.pump();

      // Nudge written at once
      expect(repo.activeProfile!.mapGrid!.offsetXCentiPx, equals(100));
      expect(repo.serviceWritesCount, equals(writesBefore + 1));

      // Wait 500 ms: no second write
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.serviceWritesCount, equals(writesBefore + 1));
    });

    testWidgets('GR9 The active map changes while a nudge is pending: the old map\'s grid gets the nudge, and the new map shows no grid.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Nudge right once
      await tester.tap(find.byTooltip('Nudge right'));
      await tester.pump(const Duration(milliseconds: 100));

      // Active map changes to a new map with no grid
      final newMapBytes = Uint8List.fromList([...mapBytes, 1]);
      final newMapRef = BlobRef(
        sha256Hex: sha256.convert(newMapBytes).toString().toLowerCase(),
        byteSize: newMapBytes.length,
        width: 1000,
        height: 800,
        format: BlobFormat.jpeg,
      );
      store.put(newMapRef, newMapBytes, campaignId: 'camp-1');

      repo.putProfile(repo.activeProfile!.copyWith(
        activeMapRegister: CrdtLwwRegister<BlobRef?>(
          value: newMapRef,
          timestamp: clock.nextTimestamp(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Old map's grid received the nudge
      expect(repo.activeProfile!.mapGrid!.offsetXCentiPx, equals(100));
      // New map has no grid of its own -> panel is not shown
      expect(find.byType(MapGridControls), findsNothing);
    });

    testWidgets('GL1 Law test over 180 seeds checking L1, L2, L3 and coverage controls (>= 20 each)', (tester) async {
      int hideWhilePendingCount = 0;
      int cornerWhilePendingCount = 0;
      int coDmWhilePendingCount = 0;
      int leaveWhilePendingCount = 0;

      const totalSeeds = 180;

      for (int seed = 1; seed <= totalSeeds; seed++) {
        final rng = Random(seed + 141000);

        // Fresh repo, clock, service, controller
        final testRepo = CountingCampaignRepository();
        final testClock = StatefulHlcClock(replicaId: ReplicaId('node-$seed'));
        final testTransfer = BlobTransferService(
          channel: network.createChannel('node-$seed'),
          store: store,
          servableRefs: () => activeMapServableRefs(testRepo),
        );
        final testController = ActiveMapController(
          campaignRepo: testRepo,
          transfer: testTransfer,
          store: store,
          channel: network.createChannel('ch-$seed'),
          transportState: () => TransportState.webRtc,
        );
        final testGridService = MapGridService(campaignRepo: testRepo, clock: testClock);

        final startingGrid = MapGrid(
          mapSha256Hex: mapRef.sha256Hex,
          cellCentiPx: 5000,
          offsetXCentiPx: 0,
          offsetYCentiPx: 0,
          feetPerCell: 5,
          visible: true,
        );
        testRepo.putProfile(_makeProfile(
          mapRef: mapRef,
          grid: startingGrid,
          timestamp: testClock.nextTimestamp(),
        ));
        testController.start();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MapView(
              key: ValueKey('map-seed-$seed'),
              controller: testController,
              gridService: testGridService,
              transformationController: transformController,
              canEditMap: true,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        // Reference model state
        MapGrid? modelM = startingGrid;
        MapGridEdit modelP = const MapGridEdit();
        int modelDueMs = -1;
        int modelWrites = 0;
        int modelNowMs = 0;
        bool hasLeftScreen = false;

        void modelFlush() {
          if (modelDueMs >= 0) {
            modelDueMs = -1;
            if (modelM != null && modelM!.mapSha256Hex == mapRef.sha256Hex && !modelP.isEmpty) {
              modelM = modelP.applyTo(modelM!);
              modelWrites++;
            }
            modelP = const MapGridEdit();
          }
        }

        void modelAdvance(int dt) {
          final target = modelNowMs + dt;
          if (modelDueMs >= 0 && modelDueMs <= target) {
            if (modelM != null && modelM!.mapSha256Hex == mapRef.sha256Hex && !modelP.isEmpty) {
              modelM = modelP.applyTo(modelM!);
              modelWrites++;
            }
            modelP = const MapGridEdit();
            modelDueMs = -1;
          }
          modelNowMs = target;
        }

        MapGrid? modelDisplayed() =>
            (modelM != null) ? modelP.applyTo(modelM!) : null;

        bool seedHadHideWhilePending = false;
        bool seedHadCornerWhilePending = false;
        bool seedHadCoDmWhilePending = false;
        bool seedHadLeaveWhilePending = false;

        final stepCount = rng.nextInt(13) + 8; // 8 to 20 steps
        for (int step = 0; step < stepCount; step++) {
          if (hasLeftScreen) break;

          // Pump seeded random gap: half 0..399 ms, half 400..1000 ms
          final gap = rng.nextBool() ? rng.nextInt(400) : (400 + rng.nextInt(601));
          modelAdvance(gap);
          await tester.pump(Duration(milliseconds: gap));

          // Check which steps are allowed
          final isPanelOpen = modelDisplayed() != null && modelDisplayed()!.visible;

          // Select step
          // Available steps:
          // 0: plus, 1: minus, 2: nudge, 3: size text, 4: feet text,
          // 5: Grid toggle, 6: corner, 7: co-DM update, 8: leave screen (if last step)
          final availableSteps = <int>[];
          if (isPanelOpen) {
            availableSteps.addAll([0, 1, 2, 3, 4, 6]);
          }
          availableSteps.add(5); // Grid toggle always available in MapReady
          availableSteps.add(7); // Co-DM update always possible
          if (step == stepCount - 1) {
            availableSteps.add(8); // In some seeds, leave the screen as the last step
          }

          // If pending is not empty, bias towards race conditions
          final int chosenStep;
          if (!modelP.isEmpty && availableSteps.contains(8) && rng.nextDouble() < 0.7) {
            chosenStep = 8;
          } else if (!modelP.isEmpty && rng.nextDouble() < 0.6) {
            final raceOptions = <int>[5, 7];
            if (isPanelOpen) raceOptions.add(6);
            if (availableSteps.contains(8)) raceOptions.add(8);
            chosenStep = raceOptions[rng.nextInt(raceOptions.length)];
          } else {
            chosenStep = availableSteps[rng.nextInt(availableSteps.length)];
          }

          if (!modelP.isEmpty) {
            if (chosenStep == 5 && modelM != null && modelM!.visible) {
              seedHadHideWhilePending = true;
            } else if (chosenStep == 6) {
              seedHadCornerWhilePending = true;
            } else if (chosenStep == 7) {
              seedHadCoDmWhilePending = true;
            } else if (chosenStep == 8) {
              seedHadLeaveWhilePending = true;
            }
          }


          switch (chosenStep) {
            case 0: // +
              final cur = modelDisplayed()!;
              final nextPx = ((cur.cellCentiPx / 100.0 + 0.5) * 100.0).round() / 100.0;
              if (nextPx <= 512.0) {
                modelP = modelP.merge(MapGridEdit(cellCentiPx: (nextPx * 100.0).round()));
                modelDueMs = modelNowMs + 400;
              }
              final btn = find.byTooltip('Increase size');
              await tester.ensureVisible(btn);
              await tester.tap(btn);
              await tester.pump();
            case 1: // -
              final cur = modelDisplayed()!;
              final nextPx = ((cur.cellCentiPx / 100.0 - 0.5) * 100.0).round() / 100.0;
              if (nextPx >= 10.0) {
                modelP = modelP.merge(MapGridEdit(cellCentiPx: (nextPx * 100.0).round()));
                modelDueMs = modelNowMs + 400;
              }
              final btn = find.byTooltip('Decrease size');
              await tester.ensureVisible(btn);
              await tester.tap(btn);
              await tester.pump();
            case 2: // nudge
              final dir = rng.nextInt(4);
              final dx = dir == 0 ? -1 : (dir == 3 ? 1 : 0);
              final dy = dir == 1 ? -1 : (dir == 2 ? 1 : 0);
              final cur = modelDisplayed()!;
              final cell = cur.cellCentiPx;
              int? nx;
              if (dx != 0) {
                nx = (cur.offsetXCentiPx + dx * 100) % cell;
                if (nx < 0) nx += cell;
              }
              int? ny;
              if (dy != 0) {
                ny = (cur.offsetYCentiPx + dy * 100) % cell;
                if (ny < 0) ny += cell;
              }
              modelP = modelP.merge(MapGridEdit(offsetXCentiPx: nx, offsetYCentiPx: ny));
              modelDueMs = modelNowMs + 400;

              final tooltip = dir == 0
                  ? 'Nudge left'
                  : (dir == 1
                      ? 'Nudge up'
                      : (dir == 2 ? 'Nudge down' : 'Nudge right'));
              final btn = find.byTooltip(tooltip);
              await tester.ensureVisible(btn);
              await tester.tap(btn);
              await tester.pump();
            case 3: // type size
              final valid = rng.nextBool();
              final curSize = modelDisplayed()!.cellCentiPx ~/ 100;
              int sizeVal = valid ? (rng.nextInt(100) + 20) : (rng.nextInt(2) == 0 ? 5 : 600);
              if (valid && sizeVal == curSize) {
                sizeVal = (sizeVal >= 512) ? 511 : sizeVal + 1;
              }
              if (valid) {
                modelP = modelP.merge(MapGridEdit(cellCentiPx: sizeVal * 100));
                modelDueMs = modelNowMs + 400;
              }
              final sizeField = find.byType(TextField).first;
              await tester.ensureVisible(sizeField);
              await tester.enterText(sizeField, sizeVal.toString());
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pump();
            case 4: // type feet
              final valid = rng.nextBool();
              final curFeet = modelDisplayed()!.feetPerCell;
              int feetVal = valid ? (rng.nextInt(50) + 1) : (rng.nextInt(2) == 0 ? 0 : 150);
              if (valid && feetVal == curFeet) {
                feetVal = (feetVal >= 100) ? 99 : feetVal + 1;
              }
              if (valid) {
                modelP = modelP.merge(MapGridEdit(feetPerCell: feetVal));
                modelDueMs = modelNowMs + 400;
              }
              final feetField = find.byType(TextField).at(1);
              await tester.ensureVisible(feetField);
              await tester.enterText(feetField, feetVal.toString());
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pump();
            case 5: // Grid toggle
              modelFlush();
              if (modelM == null || modelM!.mapSha256Hex != mapRef.sha256Hex) {
                modelM = testGridService.defaultGridFor(mapRef);
              } else if (modelM!.visible) {
                modelM = MapGrid(
                  mapSha256Hex: modelM!.mapSha256Hex,
                  cellCentiPx: modelM!.cellCentiPx,
                  offsetXCentiPx: modelM!.offsetXCentiPx,
                  offsetYCentiPx: modelM!.offsetYCentiPx,
                  feetPerCell: modelM!.feetPerCell,
                  visible: false,
                );
              } else {
                modelM = MapGrid(
                  mapSha256Hex: modelM!.mapSha256Hex,
                  cellCentiPx: modelM!.cellCentiPx,
                  offsetXCentiPx: modelM!.offsetXCentiPx,
                  offsetYCentiPx: modelM!.offsetYCentiPx,
                  feetPerCell: modelM!.feetPerCell,
                  visible: true,
                );
              }
              modelWrites++;
              await tester.tap(find.widgetWithText(OutlinedButton, 'Grid'));
              await tester.pump();
            case 6: // corner
              modelFlush();
              final ivFinder = find.byType(InteractiveViewer);
              final ivSize = tester.getSize(ivFinder);
              final tapX = rng.nextDouble() * (ivSize.width - 20.0) + 10.0;
              final tapY = rng.nextDouble() * (ivSize.height - 20.0) + 10.0;
              final scene = transformController.toScene(Offset(tapX, tapY));
              if (modelM != null && modelM!.mapSha256Hex == mapRef.sha256Hex) {
                modelM = gridWithCornerAt(modelM!, scene.dx, scene.dy);
                modelWrites++;
              }
              final cornerBtn = find.text('Set a corner');
              await tester.ensureVisible(cornerBtn);
              await tester.tap(cornerBtn);
              await tester.pump();
              final ivTopLeft = tester.getTopLeft(ivFinder);
              await tester.tapAt(ivTopLeft + Offset(tapX, tapY));
              await tester.pump();
            case 7: // co-DM update
              final kind = rng.nextInt(3);
              final MapGrid? coDmGrid;
              if (kind == 0) {
                coDmGrid = null;
              } else {
                coDmGrid = MapGrid(
                  mapSha256Hex: mapRef.sha256Hex,
                  cellCentiPx: (rng.nextInt(20) + 30) * 100,
                  offsetXCentiPx: rng.nextInt(10) * 100,
                  offsetYCentiPx: rng.nextInt(10) * 100,
                  feetPerCell: rng.nextInt(10) + 5,
                  visible: kind == 1,
                );
              }
              modelM = coDmGrid;
              final p = _makeProfile(
                mapRef: mapRef,
                grid: coDmGrid,
                timestamp: testClock.nextTimestamp(),
              );
              await testRepo.putProfile(p);
              await tester.pump();
            case 8: // leave screen
              modelFlush();
              hasLeftScreen = true;
              await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Out'))));
              await tester.pump();
          }

          // L1: After every step, the panel's size and feet fields show the model's displayed values,
          // or no panel is shown when the model's grid is null or hidden.
          if (!hasLeftScreen) {
            final disp = modelDisplayed();
            if (disp == null || !disp.visible) {
              expect(
                find.byType(MapGridControls),
                findsNothing,
                reason: 'Seed $seed step $step: expected no panel when grid is null or hidden',
              );
            } else {
              expect(
                find.byType(MapGridControls),
                findsOneWidget,
                reason: 'Seed $seed step $step: expected panel visible',
              );
              // Verify size and feet
              final hasSizeError = find.text('Square size must be between 10 and 512 px.').evaluate().isNotEmpty;
              final hasFeetError = find.text('Feet per square must be a whole number from 1 to 100.').evaluate().isNotEmpty;

              if (!hasSizeError) {
                final sizeField = find.byType(TextField).first;
                final expectedSizeText = (disp.cellCentiPx / 100.0 % 1 == 0)
                    ? (disp.cellCentiPx ~/ 100).toString()
                    : (disp.cellCentiPx / 100.0).toStringAsFixed(1);
                expect(
                  tester.widget<TextField>(sizeField).controller!.text,
                  equals(expectedSizeText),
                  reason: 'Seed $seed step $step: size field mismatch',
                );
              }

              if (!hasFeetError) {
                final feetField = find.byType(TextField).at(1);
                expect(
                  tester.widget<TextField>(feetField).controller!.text,
                  equals(disp.feetPerCell.toString()),
                  reason: 'Seed $seed step $step: feet field mismatch',
                );
              }
            }
          }
        }

        // Settle for 1 s
        modelAdvance(1000);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // L2: Profile's grid equals model M
        final profileGrid = testRepo.activeProfile!.mapGrid;
        expect(
          profileGrid,
          equals(modelM),
          reason: 'Seed $seed: profile grid does not match model M',
        );

        // L3: Number of service writes equals modelWrites
        expect(
          testRepo.serviceWritesCount,
          equals(modelWrites),
          reason: 'Seed $seed: service writes (${testRepo.serviceWritesCount}) != model ($modelWrites)',
        );

        if (seedHadHideWhilePending) hideWhilePendingCount++;
        if (seedHadCornerWhilePending) cornerWhilePendingCount++;
        if (seedHadCoDmWhilePending) coDmWhilePendingCount++;
        if (seedHadLeaveWhilePending) leaveWhilePendingCount++;

        testController.dispose();
      }

      // ignore: avoid_print
      print('GL1 coverage counts: hideWhilePending=$hideWhilePendingCount, cornerWhilePending=$cornerWhilePendingCount, coDmWhilePending=$coDmWhilePendingCount, leaveWhilePending=$leaveWhilePendingCount');
      expect(hideWhilePendingCount, greaterThanOrEqualTo(20));
      expect(cornerWhilePendingCount, greaterThanOrEqualTo(20));
      expect(coDmWhilePendingCount, greaterThanOrEqualTo(20));
      expect(leaveWhilePendingCount, greaterThanOrEqualTo(20));
    });
  });
}
