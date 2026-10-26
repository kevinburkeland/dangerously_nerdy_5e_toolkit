import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_intake_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/fake_map_image_intake.dart';

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

BlobRef _makeRef(Uint8List bytes, {int width = 800, int height = 600}) {
  return BlobRef(
    sha256Hex: sha256.convert(bytes).toString().toLowerCase(),
    byteSize: bytes.length,
    width: width,
    height: height,
    format: BlobFormat.jpeg,
  );
}

class FakeActiveMapController extends ActiveMapController {
  final StreamController<ActiveMapViewState> _testStates =
      StreamController<ActiveMapViewState>.broadcast(sync: true);
  ActiveMapViewState _testCurrent;
  String? _testCampaignId;

  FakeActiveMapController({
    ActiveMapViewState initial = const MapNone(),
    String? campaignId = 'camp-1',
    required super.campaignRepo,
    required super.transfer,
    required super.store,
    required super.channel,
    required super.transportState,
  })  : _testCurrent = initial,
        _testCampaignId = campaignId;

  @override
  ActiveMapViewState get current => _testCurrent;

  @override
  String? get campaignId => _testCampaignId;

  @override
  Stream<ActiveMapViewState> get states {
    late final StreamController<ActiveMapViewState> ctrl;
    StreamSubscription<ActiveMapViewState>? sub;
    ctrl = StreamController<ActiveMapViewState>.broadcast(
      sync: true,
      onListen: () {
        ctrl.add(_testCurrent);
        sub = _testStates.stream.listen(ctrl.add);
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return ctrl.stream;
  }

  void emit(ActiveMapViewState state) {
    _testCurrent = state;
    _testStates.add(state);
  }

  void setCampaignId(String? id) {
    _testCampaignId = id;
  }

  @override
  void dispose() {
    _testStates.close();
    super.dispose();
  }
}

class _CountingIntakeService extends MapIntakeService {
  int clearMapCalls = 0;
  String? lastClearedCampaignId;
  MapSetResult? nextSetResult;
  Object? nextError;

  _CountingIntakeService({
    required super.intake,
    required super.store,
    required super.campaignRepo,
    required super.clock,
  });

  @override
  Future<MapSetResult> setMapFromSource(
    MapImageSource source, {
    required String campaignId,
  }) async {
    if (nextError != null) throw nextError!;
    return nextSetResult!;
  }

  @override
  Future<void> clearMap({required String campaignId}) async {
    clearMapCalls++;
    lastClearedCampaignId = campaignId;
  }
}

void main() {
  group('MapView Widget Tests (V1 - V6)', () {
    late FakeBlobNetwork network;
    late FakeBlobStore store;
    late FakeCampaignRepository repo;
    late FakeActiveMapController controller;
    late FakeMapImageIntake intake;
    late _CountingIntakeService intakeService;

    setUp(() {
      network = FakeBlobNetwork();
      final channel = network.createChannel('me');
      store = FakeBlobStore();
      repo = FakeCampaignRepository();
      final clock = StatefulHlcClock(replicaId: ReplicaId('me'));
      intake = FakeMapImageIntake();
      intakeService = _CountingIntakeService(
        intake: intake,
        store: store,
        campaignRepo: repo,
        clock: clock,
      );
      final transfer = BlobTransferService(
        channel: channel,
        store: store,
        servableRefs: () => activeMapServableRefs(repo),
      );
      controller = FakeActiveMapController(
        campaignRepo: repo,
        transfer: transfer,
        store: store,
        channel: channel,
        transportState: () => TransportState.webRtc,
      );
      final gridService = MapGridService(campaignRepo: repo, clock: clock);
      sl.registerSingleton<MapGridService>(gridService);
    });

    tearDown(() {
      sl.reset();
      controller.dispose();
    });

    Widget wrap(Widget child) {
      return MaterialApp(
        home: Material(
          child: child,
        ),
      );
    }

    testWidgets('V1: Each state shows its text; MapReady shows InteractiveViewer with Image.memory', (tester) async {
      final bytes = _makeValidJpeg();
      final ref = _makeRef(bytes);

      // MapNone
      controller.emit(const MapNone());
      await tester.pumpWidget(wrap(MapView(controller: controller)));
      expect(find.text("No map yet. The DM hasn't shared one."), findsOneWidget);

      // MapLoading
      controller.emit(const MapLoading());
      await tester.pump();
      expect(find.text('Opening map…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // MapDownloading
      controller.emit(const MapDownloading(2, 5));
      await tester.pump();
      expect(find.text('Downloading map, 40%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // MapWaitingForPeer
      controller.emit(const MapWaitingForPeer());
      await tester.pump();
      expect(find.text('Waiting for a player who has the map'), findsOneWidget);

      // MapConnecting
      controller.emit(const MapConnecting());
      await tester.pump();
      expect(find.text('Connecting to other players…'), findsOneWidget);

      // MapRelayOnly
      controller.emit(const MapRelayOnly());
      await tester.pump();
      expect(find.text("This map can't reach you over the relay connection. Ask the DM to connect you directly."), findsOneWidget);

      // MapStoreUnavailable
      controller.emit(const MapStoreUnavailable('quota exceeded'));
      await tester.pump();
      expect(find.text("Maps can't be stored in this browser: quota exceeded"), findsOneWidget);

      // MapFailed
      controller.emit(MapFailed(Exception('network dropped')));
      await tester.pump();
      expect(find.text("The map couldn't be loaded: network dropped"), findsOneWidget);

      // MapReady
      controller.emit(MapReady(ref, bytes));
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      final image = tester.widget<Image>(imgFinder);
      expect(image.image, isA<MemoryImage>());
      final memoryImage = image.image as MemoryImage;
      expect(memoryImage.bytes, equals(bytes));
    });

    testWidgets('V2: canEditMap false shows neither button in any state; canEditMap true shows Choose, and Clear only while map is set', (tester) async {
      final bytes = _makeValidJpeg();
      final ref = _makeRef(bytes);

      // canEditMap: false -> no buttons in any state
      await tester.pumpWidget(wrap(MapView(controller: controller, canEditMap: false)));

      for (final state in [
        const MapNone(),
        const MapLoading(),
        const MapDownloading(1, 2),
        const MapWaitingForPeer(),
        const MapConnecting(),
        const MapRelayOnly(),
        const MapStoreUnavailable('err'),
        MapReady(ref, bytes),
        MapFailed(Exception('err')),
      ]) {
        controller.emit(state);
        await tester.pump();
        expect(find.text('Choose map image'), findsNothing);
        expect(find.text('Clear map'), findsNothing);
      }

      // canEditMap: true
      await tester.pumpWidget(wrap(MapView(
        controller: controller,
        intake: intake,
        intakeService: intakeService,
        canEditMap: true,
      )));

      // In MapNone: Choose is present, Clear is NOT present
      controller.emit(const MapNone());
      await tester.pump();
      expect(find.text('Choose map image'), findsOneWidget);
      expect(find.text('Clear map'), findsNothing);

      // In MapReady: Choose is present, Clear IS present
      controller.emit(MapReady(ref, bytes));
      await tester.pump();
      expect(find.text('Choose map image'), findsOneWidget);
      expect(find.text('Clear map'), findsOneWidget);
    });

    testWidgets('V3: Each rejection reason shows its message with real numbers', (tester) async {
      await tester.pumpWidget(wrap(MapView(
        controller: controller,
        intake: intake,
        intakeService: intakeService,
        canEditMap: true,
      )));

      final source = FakeMapImageSource(bytes: Uint8List(10));
      intake.nextPickResult = source;

      // fileTooLarge (250 MB)
      intakeService.nextError = const MapIntakeRejected(
        MapRejectReason.fileTooLarge,
        byteSize: 250 * 1024 * 1024,
      );
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text('This file is 250 MB. The largest file you can pick is 200 MB.'), findsOneWidget);

      // tooManyPixels (9,000 x 4,000)
      intakeService.nextError = const MapIntakeRejected(
        MapRejectReason.tooManyPixels,
        width: 9000,
        height: 4000,
      );
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text('This image is 9,000 × 4,000 px. The largest image you can pick is 8,192 px on its longest side.'), findsOneWidget);

      // unsupportedFormat
      intakeService.nextError = const MapIntakeRejected(MapRejectReason.unsupportedFormat);
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text("This file type can't be used as a map. Export it as PNG or WebP and try again."), findsOneWidget);

      // unreadable
      intakeService.nextError = const MapIntakeRejected(MapRejectReason.unreadable);
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text("This image couldn't be read. Export it again as PNG or WebP."), findsOneWidget);

      // undecodable
      intakeService.nextError = const MapIntakeRejected(MapRejectReason.undecodable);
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text("This image couldn't be read. Export it again as PNG or WebP."), findsOneWidget);

      // outputTooLarge
      intakeService.nextError = const MapIntakeRejected(MapRejectReason.outputTooLarge);
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text('This map is still over 10 MB after compression. Try a smaller or simpler image.'), findsOneWidget);

      // encoderMismatch
      intakeService.nextError = const MapIntakeRejected(MapRejectReason.encoderMismatch);
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text('This browser produced an unexpected image. Try another browser.'), findsOneWidget);

      // MapIntakeUnavailableException
      intakeService.nextError = const MapIntakeUnavailableException('Not supported on desktop');
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text("The map couldn't be shared: Not supported on desktop"), findsOneWidget);

      // BlobStoreUnavailableException
      intakeService.nextError = const BlobStoreUnavailableException('Quota exceeded');
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text("The map couldn't be shared: Quota exceeded"), findsOneWidget);
    });

    testWidgets('V4: Successful scaled pick shows message line; cancelled pick changes nothing', (tester) async {
      await tester.pumpWidget(wrap(MapView(
        controller: controller,
        intake: intake,
        intakeService: intakeService,
        canEditMap: true,
      )));

      // 1. Cancelled pick
      intake.nextPickResult = null;
      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Map shared.'), findsNothing);

      // 2. Scaled pick: 6000 x 3000 -> 4096 x 2048
      final bytes = _makeValidJpeg();
      final ref = _makeRef(bytes, width: 4096, height: 2048);
      intake.nextPickResult = FakeMapImageSource(bytes: bytes);
      intakeService.nextError = null;
      intakeService.nextSetResult = MapSetResult(
        ref,
        6000,
        3000,
        scaledDown: true,
      );

      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(find.text('Map shared. Scaled down from 6,000 × 3,000 to 4,096 × 2,048 px.'), findsOneWidget);
    });

    testWidgets('V5: Clear map calls clearMap with the active profile id', (tester) async {
      final validBytes = _makeValidJpeg();
      controller.emit(MapReady(_makeRef(validBytes), validBytes));

      await tester.pumpWidget(wrap(MapView(
        controller: controller,
        intake: intake,
        intakeService: intakeService,
        canEditMap: true,
      )));

      expect(find.text('Clear map'), findsOneWidget);
      await tester.tap(find.text('Clear map'));
      await tester.pump();

      expect(intakeService.clearMapCalls, equals(1));
      expect(intakeService.lastClearedCampaignId, equals('camp-1'));
    });

    testWidgets('V6: MapView inside plain SizedBox in a Column with no Scaffold builds without errors', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SizedBox(
                width: 300,
                height: 300,
                child: MapView(
                  controller: controller,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(MapView), findsOneWidget);
    });

    testWidgets(
        'NM1: Intake normalize waits on Completer; popping during preparing map does not throw setState after dispose',
        (tester) async {
      for (final scenario in ['success', 'rejected', 'exception']) {
        final completerIntake = _CompleterIntake();
        final realIntakeService = MapIntakeService(
          intake: completerIntake,
          store: store,
          campaignRepo: repo,
          clock: StatefulHlcClock(replicaId: ReplicaId('test')),
        );

        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: MapView(
                        controller: controller,
                        intake: completerIntake,
                        intakeService: realIntakeService,
                        canEditMap: true,
                      ),
                    ),
                  ),
                ),
                child: const Text('Go to map'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Go to map'));
        await tester.pumpAndSettle();

        expect(find.text('Choose map image'), findsOneWidget);
        await tester.tap(find.text('Choose map image'));
        await tester.pump();
        expect(find.text('Preparing map…'), findsOneWidget);

        navKey.currentState!.pop();
        await tester.pumpAndSettle();

        if (scenario == 'success') {
          completerIntake.completer.complete(NormalizedMapImage(
            bytes: _makeValidJpeg(),
            width: 1,
            height: 1,
            format: BlobFormat.jpeg,
          ));
        } else if (scenario == 'rejected') {
          completerIntake.completer.completeError(
            const MapIntakeRejected(MapRejectReason.orientationMismatch),
          );
        } else {
          completerIntake.completer.completeError(Exception('Network drop'));
        }

        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
        'NM2: With no MapIntakeService registered and none passed in, tapping Choose map image throws',
        (tester) async {
      final fakeIntake = FakeMapImageIntake();
      fakeIntake.nextPickResult = FakeMapImageSource(bytes: _makeValidJpeg());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MapView(
            controller: controller,
            intake: fakeIntake,
            intakeService: null,
            canEditMap: true,
          ),
        ),
      ));

      await tester.tap(find.text('Choose map image'));
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
    });
  });
}

class _CompleterIntake implements MapImageIntakePort {
  final completer = Completer<NormalizedMapImage>();

  @override
  Future<MapImageSource?> pick() async {
    return FakeMapImageSource(bytes: _makeValidJpeg());
  }

  @override
  Future<NormalizedMapImage> normalize(
    MapImageSource source, {
    required int targetWidth,
    required int targetHeight,
  }) {
    return completer.future;
  }
}
