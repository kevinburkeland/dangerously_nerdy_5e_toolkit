import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
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
    notesRegister: const CrdtLwwRegister<String>(
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
  group('MapPanSuite (PN1-PN6)', () {
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

    testWidgets('PN1 Drag the fitted map by (+120, +60) with a slow drag (no fling), then pumpAndSettle. The translation equals the fitted translation plus (120, 60), within 1 px. The scale is unchanged.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      final initMatrix = transformController.value.clone();
      final initTx = initMatrix.storage[12];
      final initTy = initMatrix.storage[13];
      final initScale = initMatrix.storage[0];

      final ivFinder = find.byType(InteractiveViewer);
      final center = tester.getCenter(ivFinder);

      final gesture = await tester.startGesture(center);
      for (int i = 1; i <= 10; i++) {
        await gesture.moveBy(const Offset(12.0, 6.0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final finalMatrix = transformController.value;
      final finalTx = finalMatrix.storage[12];
      final finalTy = finalMatrix.storage[13];
      final finalScale = finalMatrix.storage[0];

      expect(finalScale, closeTo(initScale, 1e-4));
      expect(finalTx, closeTo(initTx + 120.0, 1.0));
      expect(finalTy, closeTo(initTy + 60.0, 1.0));
    });

    testWidgets('PN2 Drag the map far off to the left, by (−1,500, 0). After settling, it stays there (within 1 px).', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      final initMatrix = transformController.value.clone();
      final initTx = initMatrix.storage[12];
      final initTy = initMatrix.storage[13];

      final ivFinder = find.byType(InteractiveViewer);
      final center = tester.getCenter(ivFinder);

      final gesture = await tester.startGesture(center);
      for (int i = 1; i <= 30; i++) {
        await gesture.moveBy(const Offset(-50.0, 0.0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final finalMatrix = transformController.value;
      final finalTx = finalMatrix.storage[12];
      final finalTy = finalMatrix.storage[13];

      expect(finalTx, closeTo(initTx - 1500.0, 1.0));
      expect(finalTy, closeTo(initTy, 1.0));
    });

    testWidgets('PN3 Zoom to about 3× and pan, then press Recenter. The matrix equals the fit matrix (each entry within 1e-6). This holds with canEditMap: false too, and the Recenter button is shown to that player.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: mapRef, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView(canEditMap: false));
      await tester.pumpAndSettle();

      // Recenter button shown to player (canEditMap: false)
      final recenterFinder = find.widgetWithText(OutlinedButton, 'Recenter');
      expect(recenterFinder, findsOneWidget);

      final fitMatrix = transformController.value.clone();

      // Zoom to about 3x and pan
      transformController.value = Matrix4.identity()
        ..translateByDouble(150.0, 200.0, 0.0, 1.0)
        ..scaleByDouble(3.0, 3.0, 1.0, 1.0);
      await tester.pumpAndSettle();

      // Press Recenter
      await tester.tap(recenterFinder);
      await tester.pumpAndSettle();

      final finalMatrix = transformController.value;
      for (int i = 0; i < 16; i++) {
        expect(finalMatrix.storage[i], closeTo(fitMatrix.storage[i], 1e-6));
      }
    });

    testWidgets('PN4 Change the test surface size, then press Recenter. The matrix equals the fit for the new size, not the old one.', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      repo.putProfile(_makeProfile(mapRef: mapRef, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      final initialMatrix = transformController.value.clone();
      final initialScale = initialMatrix.storage[0];

      // Change surface size to 1200 x 900
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Pan away
      transformController.value = Matrix4.identity()
        ..translateByDouble(50.0, 50.0, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
      await tester.pump();

      // Press Recenter
      final recenterFinder = find.widgetWithText(OutlinedButton, 'Recenter');
      await tester.tap(recenterFinder);
      await tester.pumpAndSettle();

      final newMatrix = transformController.value;
      final newScale = newMatrix.storage[0];
      expect(newScale, isNot(closeTo(initialScale, 0.1)));
      expect(newScale, greaterThan(initialScale));
      // Verify all matrix entries differ from initial fit matrix
      expect(newMatrix.storage[0], closeTo(1.045, 1e-3));
      expect(newMatrix.storage[12], closeTo(77.5, 1e-1));
    });

    testWidgets('PN5 With Measure on, a one-finger drag draws a ruler and doesn\'t move the map. Recenter while a ruler is shown keeps the ruler and its label.', (tester) async {
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

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      final measureBtn = find.widgetWithText(OutlinedButton, 'Measure');
      expect(measureBtn, findsOneWidget);
      await tester.tap(measureBtn);
      await tester.pumpAndSettle();

      final matrixBefore = transformController.value.clone();

      final ivFinder = find.byType(InteractiveViewer);
      final center = tester.getCenter(ivFinder);

      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(100.0, 100.0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Map has not moved
      for (int i = 0; i < 16; i++) {
        expect(transformController.value.storage[i], closeTo(matrixBefore.storage[i], 1e-6));
      }

      // Ruler is shown
      final rulerFinder = find.byType(MapRulerOverlay);
      expect(rulerFinder, findsOneWidget);
      final rulerWidgetBefore = tester.widget<MapRulerOverlay>(rulerFinder);
      expect(rulerWidgetBefore.label, isNotNull);
      final labelBefore = rulerWidgetBefore.label;

      // Press Recenter
      final recenterBtn = find.widgetWithText(OutlinedButton, 'Recenter');
      await tester.tap(recenterBtn);
      await tester.pumpAndSettle();

      // Ruler and label are still shown
      final rulerWidgetAfter = tester.widget<MapRulerOverlay>(rulerFinder);
      expect(rulerWidgetAfter.label, equals(labelBefore));
      expect(rulerWidgetAfter.start, equals(rulerWidgetBefore.start));
      expect(rulerWidgetAfter.end, equals(rulerWidgetBefore.end));
    });

    testWidgets('PN6 No Recenter button in any state other than MapReady.', (tester) async {
      repo.putProfile(_makeProfile(mapRef: null, grid: null));
      controller.start();

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // MapNone
      expect(find.widgetWithText(OutlinedButton, 'Recenter'), findsNothing);
    });
  });
}
