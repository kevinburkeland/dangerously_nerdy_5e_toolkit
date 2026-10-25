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
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_grid_overlay.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_view.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';

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
  String notes = '',
}) {
  const stamp = HybridLogicalClock(
    physicalTime: 1700000000000,
    logicalCounter: 0,
    nodeId: 'node-1',
  );
  return CampaignProfile.raw(
    id: id,
    nameRegister: const CrdtLwwRegister<String>(
      value: 'Camp 1',
      timestamp: stamp,
    ),
    notesRegister: CrdtLwwRegister<String>(
      value: notes,
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
  group('MapGridView Suite (GV1-GV8)', () {
    late FakeBlobNetwork network;
    late FakeBlobStore store;
    late FakeCampaignRepository repo;
    late StatefulHlcClock clock;
    late BlobTransferService transfer;
    late ActiveMapController controller;
    late MapGridService gridService;
    late TransformationController transformController;

    late Uint8List mapBytes;
    late BlobRef mapRef;

    setUp(() {
      network = FakeBlobNetwork();
      final channel = network.createChannel('me');
      store = FakeBlobStore();
      repo = FakeCampaignRepository();
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

    testWidgets('GV1: No grid -> no grid painter lines drawn and no Measure toggle; visible grid -> painter lines equal verticalLines/horizontalLines and Measure toggle exists', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // No grid: no Measure toggle
      expect(find.text('Measure'), findsNothing);

      // Painter lines are empty
      final customPaintFinder = find.descendant(
        of: find.byType(MapGridOverlay),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
      final painterNoGrid = tester.widget<CustomPaint>(customPaintFinder).painter as MapGridPainter;
      expect(painterNoGrid.computedVerticalLines, isEmpty);
      expect(painterNoGrid.computedHorizontalLines, isEmpty);

      // Set a visible grid
      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 1000,
        offsetYCentiPx: 1500,
        feetPerCell: 5,
        visible: true,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: grid));
      await tester.pumpAndSettle();

      // Measure toggle exists
      expect(find.text('Measure'), findsOneWidget);

      // Painter lines equal verticalLines / horizontalLines
      final painterGrid = tester.widget<CustomPaint>(customPaintFinder).painter as MapGridPainter;
      expect(painterGrid.computedVerticalLines, equals(verticalLines(grid, 1000)));
      expect(painterGrid.computedHorizontalLines, equals(horizontalLines(grid, 800)));
    });

    testWidgets('GV2: canEditMap: false shows no grid controls in any state; canEditMap: true shows Grid toggle only in MapReady', (tester) async {
      // 1. canEditMap: false
      repo.putProfile(_makeProfile(mapRef: null));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: false));
      await tester.pumpAndSettle();
      expect(find.text('Grid'), findsNothing);
      expect(find.byType(MapGridControls), findsNothing);

      repo.putProfile(_makeProfile(mapRef: mapRef));
      await tester.pumpAndSettle();
      expect(find.text('Grid'), findsNothing);
      expect(find.byType(MapGridControls), findsNothing);

      // 2. canEditMap: true
      controller.dispose();
      controller = ActiveMapController(
        campaignRepo: repo,
        transfer: transfer,
        store: store,
        channel: network.createChannel('me2'),
        transportState: () => TransportState.webRtc,
      );
      repo.putProfile(_makeProfile(mapRef: null));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();
      expect(find.text('Grid'), findsNothing);

      repo.putProfile(_makeProfile(mapRef: mapRef));
      await tester.pumpAndSettle();
      expect(find.text('Grid'), findsOneWidget);
    });

    testWidgets('GV3: Turning Grid toggle on with no grid writes defaultGridFor(map) once; off writes same grid with visible: false', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();

      expect(repo.activeProfile!.mapGrid, isNull);

      // Turn on
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();

      final written1 = repo.activeProfile!.mapGrid;
      expect(written1, isNotNull);
      expect(written1!.cellCentiPx, equals(5000));
      expect(written1.visible, isTrue);

      // Turn off
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();

      final written2 = repo.activeProfile!.mapGrid;
      expect(written2, isNotNull);
      expect(written2!.cellCentiPx, equals(written1.cellCentiPx));
      expect(written2.visible, isFalse);
    });

    testWidgets('GV4: Pressing + three times then − once quickly writes once, 400 ms after last press, with cell size +1.0 px; typing 9 or 513 shows error and writes nothing; popping writes pending', (tester) async {
      final initialGrid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000, // 50.0 px
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: initialGrid));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();

      // + three times then - once quickly (each 50 ms)
      await tester.tap(find.byTooltip('Increase size'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Increase size'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Increase size'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Decrease size'));
      await tester.pump(const Duration(milliseconds: 50));

      // At 200 ms total, debounce timer (400 ms) has NOT fired yet
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5000));

      // Advance past 400 ms from the last press
      await tester.pump(const Duration(milliseconds: 450));

      // Wrote once with +1.0 px -> 51.0 px (5100 centipixels)
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5100));

      // Typing 9
      final sizeField = find.byType(TextField).first;
      await tester.enterText(sizeField, '9');
      await tester.pump();
      expect(find.text('Square size must be between 10 and 512 px.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      // Nothing written
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5100));

      // Typing 513
      await tester.enterText(sizeField, '513');
      await tester.pump();
      expect(find.text('Square size must be between 10 and 512 px.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5100));

      // Fix text back to 51
      await tester.enterText(sizeField, '51');
      await tester.pumpAndSettle();

      // Press + to create a pending change, then pop screen immediately
      await tester.tap(find.byTooltip('Increase size'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5100)); // still pending

      // Pop the screen by pumping an empty container
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      // Leaving the screen wrote it at once (51.5 px -> 5150)
      expect(repo.activeProfile!.mapGrid!.cellCentiPx, equals(5150));
    });

    testWidgets('GV5: "Set a corner" then a tap at image point P writes gridWithCornerAt(P); a pan in that mode does not set a corner', (tester) async {
      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: grid));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();

      // Enter "Set a corner" mode
      await tester.tap(find.text('Set a corner'));
      await tester.pumpAndSettle();

      // A pan does not set a corner
      await tester.drag(find.byType(InteractiveViewer), const Offset(100, 50));
      await tester.pumpAndSettle();
      expect(repo.activeProfile!.mapGrid!.offsetXCentiPx, equals(0));
      expect(repo.activeProfile!.mapGrid!.offsetYCentiPx, equals(0));

      // A tap at viewport point (200, 200)
      const tapViewport = Offset(200, 200);
      final sceneP = transformController.toScene(tapViewport);
      final expectedGrid = gridWithCornerAt(grid, sceneP.dx, sceneP.dy);

      final ivTopLeft = tester.getTopLeft(find.byType(InteractiveViewer));
      await tester.tapAt(ivTopLeft + tapViewport);
      await tester.pumpAndSettle();

      expect(repo.activeProfile!.mapGrid!.offsetXCentiPx, equals(expectedGrid.offsetXCentiPx));
      expect(repo.activeProfile!.mapGrid!.offsetYCentiPx, equals(expectedGrid.offsetYCentiPx));
      // Mode ended
      expect(find.text('Set a corner'), findsOneWidget);
    });

    testWidgets('GV6: Measure: drag from inside (1, 1) to inside (4, 3) shows "3 squares · 15 ft"; ends at square centres; profile saw no write; second drag replaces; hiding grid removes Measure', (tester) async {
      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000, // 50 px squares, offsets 0
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: grid));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();

      // Turn on Measure
      await tester.tap(find.text('Measure'));
      await tester.pumpAndSettle();

      final writesBefore = repo.activeProfile!.mapGridRegister.timestamp;

      final ivTopLeft = tester.getTopLeft(find.byType(InteractiveViewer));
      // Inside square (1, 1): scene (60, 60). Inside square (4, 3): scene (220, 170).
      final p1 = MatrixUtils.transformPoint(transformController.value, const Offset(60, 60));
      final p2 = MatrixUtils.transformPoint(transformController.value, const Offset(220, 170));

      // Perform drag
      final gesture = await tester.startGesture(ivTopLeft + p1);
      await tester.pump();
      await gesture.moveTo(ivTopLeft + p2);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Shows "3 squares · 15 ft"
      expect(find.text('3 squares · 15 ft'), findsOneWidget);

      // Ends are at square centres (75, 75) and (225, 175)
      final rulerOverlay = tester.widget<MapRulerOverlay>(find.byType(MapRulerOverlay));
      expect(rulerOverlay.start, equals(const Offset(75, 75)));
      expect(rulerOverlay.end, equals(const Offset(225, 175)));

      // Profile was NOT written during drag
      expect(repo.activeProfile!.mapGridRegister.timestamp, equals(writesBefore));

      // Second drag replaces the first ruler
      final p3 = MatrixUtils.transformPoint(transformController.value, const Offset(10, 10)); // square (0, 0)
      final p4 = MatrixUtils.transformPoint(transformController.value, const Offset(60, 10)); // square (1, 0)
      final gesture2 = await tester.startGesture(ivTopLeft + p3);
      await tester.pump();
      await gesture2.moveTo(ivTopLeft + p4);
      await tester.pump();
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(find.text('1 square · 5 ft'), findsOneWidget);
      final rulerOverlay2 = tester.widget<MapRulerOverlay>(find.byType(MapRulerOverlay));
      expect(rulerOverlay2.start, equals(const Offset(25, 25)));
      expect(rulerOverlay2.end, equals(const Offset(75, 25)));

      // Hiding grid removes Measure toggle and ruler
      final hiddenGrid = MapGrid(
        mapSha256Hex: grid.mapSha256Hex,
        cellCentiPx: grid.cellCentiPx,
        offsetXCentiPx: grid.offsetXCentiPx,
        offsetYCentiPx: grid.offsetYCentiPx,
        feetPerCell: grid.feetPerCell,
        visible: false,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: hiddenGrid));
      await tester.pumpAndSettle();

      expect(find.text('Measure'), findsNothing);
      expect(find.text('1 square · 5 ft'), findsNothing);
    });

    testWidgets('GV7: Same drag after zooming to 2x and panning still gives same squares (scene conversion used)', (tester) async {
      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: grid));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();

      // Turn on Measure
      await tester.tap(find.text('Measure'));
      await tester.pumpAndSettle();

      // Zoom to 2x and pan
      transformController.value = Matrix4.identity()
        ..translateByDouble(50.0, 30.0, 0.0, 1.0)
        ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
      await tester.pumpAndSettle();

      final ivTopLeft = tester.getTopLeft(find.byType(InteractiveViewer));
      // Drag from inside square (1, 1) [scene (60, 60)] to inside square (4, 3) [scene (220, 170)]
      final p1 = MatrixUtils.transformPoint(transformController.value, const Offset(60, 60));
      final p2 = MatrixUtils.transformPoint(transformController.value, const Offset(220, 170));

      final gesture = await tester.startGesture(ivTopLeft + p1);
      await tester.pump();
      await gesture.moveTo(ivTopLeft + p2);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('3 squares · 15 ft'), findsOneWidget);
      final rulerOverlay = tester.widget<MapRulerOverlay>(find.byType(MapRulerOverlay));
      expect(rulerOverlay.start, equals(const Offset(75, 75)));
      expect(rulerOverlay.end, equals(const Offset(225, 175)));
    });

    testWidgets('GV8: The grid panel at 360 x 640 logical pixels shows no overflow error', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: grid));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
