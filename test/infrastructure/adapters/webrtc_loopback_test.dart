@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:web/web.dart' as web;

import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_intake_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/map/web/web_map_image_intake_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/storage/blob_store_adapter.dart';

import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/loopback_signaling.dart';

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 45),
  Duration pollInterval = const Duration(milliseconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future.delayed(pollInterval);
  }
}

Future<Uint8List> _renderPngCanvas(int width, int height) async {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  canvas.width = width;
  canvas.height = height;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx.fillStyle = '#00FF00'.toJS;
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#FF0000'.toJS;
  ctx.fillRect(width ~/ 4, height ~/ 4, width ~/ 2, height ~/ 2);

  final completer = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? b) => completer.complete(b)).toJS,
    'image/png',
    1.0.toJS,
  );
  final blob = await completer.future;
  canvas.width = 0;
  canvas.height = 0;
  final buf = await blob!.arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}

WebMapImageSource _makeSourceFromBytes(Uint8List bytes, String filename, String mimeType) {
  final file = web.File([bytes.toJS].toJS, filename, web.FilePropertyBag(type: mimeType));
  return WebMapImageSource(file);
}

void main() {
  group('WebRtcMeshAdapter Headless Browser Loopback Tests', () {
    test('RT0 (control) Two devices connect over loopback and exchange mesh text', () async {
      final hub = LoopbackSignalingHub();
      final signalingA = LoopbackSignaling(hub);
      final signalingB = LoopbackSignaling(hub);

      final adapterA = WebRtcMeshAdapter(signalingAdapter: signalingA);
      final adapterB = WebRtcMeshAdapter(signalingAdapter: signalingB);

      final dbNameA = 'db_rt0_a_${DateTime.now().microsecondsSinceEpoch}';
      final dbNameB = 'db_rt0_b_${DateTime.now().microsecondsSinceEpoch}';
      final storeA = BlobStoreAdapter(databaseName: dbNameA);
      final storeB = BlobStoreAdapter(databaseName: dbNameB);

      final serviceA = BlobTransferService(
        channel: adapterA,
        store: storeA,
        servableRefs: () => [],
      )..start();
      final serviceB = BlobTransferService(
        channel: adapterB,
        store: storeB,
        servableRefs: () => [],
      )..start();

      try {
        final incomingOnB = adapterB.watchIncomingPayloads().first;

        await adapterA.initializeRoom('ROOM-RT0', 'node-a');
        await adapterB.initializeRoom('ROOM-RT0', 'node-b');

        // Wait for loopback WebRTC mesh and blob data channels to open.
        await _waitFor(() =>
            adapterA.openBlobPeers.contains('node-b') &&
            adapterB.openBlobPeers.contains('node-a'));

        expect(adapterA.openBlobPeers, contains('node-b'));
        expect(adapterB.openBlobPeers, contains('node-a'));

        // Broadcast mesh payload
        await adapterA.broadcastPayload('rt0-hello-mesh');
        final received = await incomingOnB.timeout(const Duration(seconds: 15));
        expect(received, equals('rt0-hello-mesh'));
      } finally {
        serviceA.dispose();
        serviceB.dispose();
        await adapterA.disconnect();
        await adapterB.disconnect();
        await storeA.close();
        await storeB.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('RT1 Device A stores a 1.5 MiB + 123 B blob, Device B fetches it with backpressure', () async {
      final hub = LoopbackSignalingHub();
      final signalingA = LoopbackSignaling(hub);
      final signalingB = LoopbackSignaling(hub);

      final adapterA = WebRtcMeshAdapter(signalingAdapter: signalingA);
      final adapterB = WebRtcMeshAdapter(signalingAdapter: signalingB);

      final dbNameA = 'db_rt1_a_${DateTime.now().microsecondsSinceEpoch}';
      final dbNameB = 'db_rt1_b_${DateTime.now().microsecondsSinceEpoch}';
      final storeA = BlobStoreAdapter(databaseName: dbNameA);
      final storeB = BlobStoreAdapter(databaseName: dbNameB);

      // Create a 1.5 MiB + 123 byte blob starting with WebP signature
      final totalBytes = (1.5 * 1024 * 1024).toInt() + 123;
      final blobBytes = Uint8List(totalBytes);
      blobBytes.setRange(0, 4, 'RIFF'.codeUnits);
      final riffSize = totalBytes - 8;
      blobBytes[4] = riffSize & 0xff;
      blobBytes[5] = (riffSize >> 8) & 0xff;
      blobBytes[6] = (riffSize >> 16) & 0xff;
      blobBytes[7] = (riffSize >> 24) & 0xff;
      blobBytes.setRange(8, 12, 'WEBP'.codeUnits);
      blobBytes.setRange(12, 16, 'VP8 '.codeUnits);
      final rng = math.Random(1337);
      for (var i = 16; i < totalBytes; i++) {
        blobBytes[i] = rng.nextInt(256);
      }

      final sha256Hex = crypto.sha256.convert(blobBytes).toString();
      final ref = BlobRef(
        sha256Hex: sha256Hex,
        byteSize: totalBytes,
        width: 100,
        height: 100,
        format: BlobFormat.webp,
      );

      await storeA.put(ref, blobBytes, campaignId: 'c1');

      final serviceA = BlobTransferService(
        channel: adapterA,
        store: storeA,
        servableRefs: () => [ref],
      )..start();
      final serviceB = BlobTransferService(
        channel: adapterB,
        store: storeB,
        servableRefs: () => [],
      )..start();

      try {
        await adapterA.initializeRoom('ROOM-RT1', 'node-a');
        await adapterB.initializeRoom('ROOM-RT1', 'node-b');

        await _waitFor(() =>
            adapterA.openBlobPeers.contains('node-b') &&
            adapterB.openBlobPeers.contains('node-a'));

        final progressList = <BlobDownloadProgress>[];
        final progressSub = serviceB.downloadProgress.listen(progressList.add);

        final fetchResult = await serviceB.fetch(ref, campaignId: 'c1');
        expect(fetchResult, equals(const BlobFetched()));

        final storedOnB = await storeB.get(ref.sha256Hex);
        expect(storedOnB, isNotNull);
        expect(storedOnB.bytes, equals(blobBytes));

        expect(progressList.isNotEmpty, isTrue);
        final expectedChunks = (totalBytes + 65535) ~/ 65536;
        expect(progressList.last.chunksReceived, equals(expectedChunks));
        expect(progressList.last.chunksTotal, equals(expectedChunks));

        await progressSub.cancel();
      } finally {
        serviceA.dispose();
        serviceB.dispose();
        await adapterA.disconnect();
        await adapterB.disconnect();
        await storeA.close();
        await storeB.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('RT2 Three devices: A has blob, B fetches it, A disconnects, C joins later and fetches from B', () async {
      final hub = LoopbackSignalingHub();
      final signalingA = LoopbackSignaling(hub);
      final signalingB = LoopbackSignaling(hub);
      final signalingC = LoopbackSignaling(hub);

      final adapterA = WebRtcMeshAdapter(signalingAdapter: signalingA);
      final adapterB = WebRtcMeshAdapter(signalingAdapter: signalingB);
      final adapterC = WebRtcMeshAdapter(signalingAdapter: signalingC);

      final dbNameA = 'db_rt2_a_${DateTime.now().microsecondsSinceEpoch}';
      final dbNameB = 'db_rt2_b_${DateTime.now().microsecondsSinceEpoch}';
      final dbNameC = 'db_rt2_c_${DateTime.now().microsecondsSinceEpoch}';
      final storeA = BlobStoreAdapter(databaseName: dbNameA);
      final storeB = BlobStoreAdapter(databaseName: dbNameB);
      final storeC = BlobStoreAdapter(databaseName: dbNameC);

      final totalBytes = (1.5 * 1024 * 1024).toInt() + 123;
      final blobBytes = Uint8List(totalBytes);
      blobBytes.setRange(0, 4, 'RIFF'.codeUnits);
      final riffSize = totalBytes - 8;
      blobBytes[4] = riffSize & 0xff;
      blobBytes[5] = (riffSize >> 8) & 0xff;
      blobBytes[6] = (riffSize >> 16) & 0xff;
      blobBytes[7] = (riffSize >> 24) & 0xff;
      blobBytes.setRange(8, 12, 'WEBP'.codeUnits);
      blobBytes.setRange(12, 16, 'VP8 '.codeUnits);
      final rng = math.Random(2026);
      for (var i = 16; i < totalBytes; i++) {
        blobBytes[i] = rng.nextInt(256);
      }

      final sha256Hex = crypto.sha256.convert(blobBytes).toString();
      final ref = BlobRef(
        sha256Hex: sha256Hex,
        byteSize: totalBytes,
        width: 100,
        height: 100,
        format: BlobFormat.webp,
      );

      await storeA.put(ref, blobBytes, campaignId: 'c1');

      final serviceA = BlobTransferService(
        channel: adapterA,
        store: storeA,
        servableRefs: () => [ref],
      )..start();
      final serviceB = BlobTransferService(
        channel: adapterB,
        store: storeB,
        servableRefs: () => [ref],
      )..start();
      final serviceC = BlobTransferService(
        channel: adapterC,
        store: storeC,
        servableRefs: () => [],
      )..start();

      try {
        // Step 1: A and B connect
        await adapterA.initializeRoom('ROOM-RT2', 'node-a');
        await adapterB.initializeRoom('ROOM-RT2', 'node-b');

        await _waitFor(() =>
            adapterA.openBlobPeers.contains('node-b') &&
            adapterB.openBlobPeers.contains('node-a'));

        // Step 2: B fetches from A
        final resB = await serviceB.fetch(ref, campaignId: 'c1');
        expect(resB, equals(const BlobFetched()));

        final storedOnB = await storeB.get(ref.sha256Hex);
        expect(storedOnB, isNotNull);
        expect(storedOnB.bytes, equals(blobBytes));

        // Step 3: A disconnects
        serviceA.dispose();
        await adapterA.disconnect();
        await storeA.close();

        // Wait until B sees A disconnected
        await _waitFor(() => !adapterB.openBlobPeers.contains('node-a'));

        // Step 4: C joins later and connects to B
        await adapterC.initializeRoom('ROOM-RT2', 'node-c');
        await _waitFor(() =>
            adapterB.openBlobPeers.contains('node-c') &&
            adapterC.openBlobPeers.contains('node-b'));

        // Step 5: C fetches from B
        final resC = await serviceC.fetch(ref, campaignId: 'c1');
        expect(resC, equals(const BlobFetched()));

        final storedOnC = await storeC.get(ref.sha256Hex);
        expect(storedOnC, isNotNull);
        expect(storedOnC.bytes, equals(blobBytes));
      } finally {
        serviceB.dispose();
        serviceC.dispose();
        await adapterB.disconnect();
        await adapterC.disconnect();
        await storeB.close();
        await storeC.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('RT3 (the map end to end) Real ActiveMapController, canvas intake, and transfer to player', () async {
      final hub = LoopbackSignalingHub();
      final signalingDm = LoopbackSignaling(hub);
      final signalingPlayer = LoopbackSignaling(hub);

      final adapterDm = WebRtcMeshAdapter(signalingAdapter: signalingDm);
      final adapterPlayer = WebRtcMeshAdapter(signalingAdapter: signalingPlayer);

      final dbNameDm = 'db_rt3_dm_${DateTime.now().microsecondsSinceEpoch}';
      final dbNamePlayer = 'db_rt3_player_${DateTime.now().microsecondsSinceEpoch}';
      final storeDm = BlobStoreAdapter(databaseName: dbNameDm);
      final storePlayer = BlobStoreAdapter(databaseName: dbNamePlayer);

      final repoDm = FakeCampaignRepository();
      final repoPlayer = FakeCampaignRepository();

      const campaignId = 'c-map-rt3';
      final initialProfile = CampaignProfile(
        id: campaignId,
        name: 'Map Campaign',
        nodeId: 'node-dm',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: const RoomNodeState.empty(),
      );
      await repoDm.putProfile(initialProfile);
      await repoPlayer.putProfile(initialProfile);

      final clockDm = StatefulHlcClock(replicaId: ReplicaId('dm-clock'));
      const webIntake = MapImageIntakeAdapter();
      final intakeServiceDm = MapIntakeService(
        intake: webIntake,
        store: storeDm,
        campaignRepo: repoDm,
        clock: clockDm,
      );

      final serviceDm = BlobTransferService(
        channel: adapterDm,
        store: storeDm,
        servableRefs: () => activeMapServableRefs(repoDm),
      )..start();

      final controllerDm = ActiveMapController(
        campaignRepo: repoDm,
        transfer: serviceDm,
        store: storeDm,
        channel: adapterDm,
        transportState: () => TransportState.webRtc,
      );

      final servicePlayer = BlobTransferService(
        channel: adapterPlayer,
        store: storePlayer,
        servableRefs: () => activeMapServableRefs(repoPlayer),
      )..start();

      final controllerPlayer = ActiveMapController(
        campaignRepo: repoPlayer,
        transfer: servicePlayer,
        store: storePlayer,
        channel: adapterPlayer,
        transportState: () => TransportState.webRtc,
      );

      controllerDm.start();
      controllerPlayer.start();

      try {
        await adapterDm.initializeRoom('ROOM-RT3', 'dm-node');
        await adapterPlayer.initializeRoom('ROOM-RT3', 'player-node');

        await _waitFor(() =>
            adapterDm.openBlobPeers.contains('player-node') &&
            adapterPlayer.openBlobPeers.contains('dm-node'));

        // DM draws 1,200 x 800 PNG and sets map
        final pngBytes = await _renderPngCanvas(1200, 800);
        final source = _makeSourceFromBytes(pngBytes, 'map1200x800.png', 'image/png');
        final setResult = await intakeServiceDm.setMapFromSource(source, campaignId: campaignId);

        // Copy DM's activeMapRegister into player's profile (standing in for room sync)
        final dmProfile = repoDm.activeProfile!;
        expect(dmProfile.activeMap, isNotNull);
        await repoPlayer.putProfile(dmProfile);

        // Wait for player's controller to reach MapReady
        await _waitFor(() => controllerPlayer.current is MapReady);

        final playerState = controllerPlayer.current as MapReady;
        expect(playerState.ref.sha256Hex, equals(setResult.ref.sha256Hex));
        final stateSha256 = crypto.sha256.convert(playerState.bytes).toString();
        expect(stateSha256, equals(setResult.ref.sha256Hex));
      } finally {
        controllerDm.dispose();
        controllerPlayer.dispose();
        serviceDm.dispose();
        servicePlayer.dispose();
        await adapterDm.disconnect();
        await adapterPlayer.disconnect();
        await storeDm.close();
        await storePlayer.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
