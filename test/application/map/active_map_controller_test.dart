import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';

Uint8List _makeWebp(int byteSize) {
  final bytes = Uint8List(byteSize);
  bytes[0] = 0x52; bytes[1] = 0x49; bytes[2] = 0x46; bytes[3] = 0x46; // RIFF
  bytes[8] = 0x57; bytes[9] = 0x45; bytes[10] = 0x42; bytes[11] = 0x50; // WEBP
  for (var i = 12; i < byteSize; i++) {
    bytes[i] = (i * 31) % 256;
  }
  return bytes;
}

BlobRef _makeRef(Uint8List bytes) {
  return BlobRef(
    sha256Hex: sha256.convert(bytes).toString().toLowerCase(),
    byteSize: bytes.length,
    width: 200,
    height: 200,
    format: BlobFormat.webp,
  );
}

CampaignProfile _makeProfile({
  String id = 'camp-1',
  BlobRef? mapRef,
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
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    roomState: const RoomNodeState.empty(),
  );
}

class _TestTransferService extends BlobTransferService {
  int startCalls = 0;
  int fetchCalls = 0;
  Future<BlobFetchResult> Function(BlobRef ref, String campaignId)? onFetch;
  final StreamController<BlobDownloadProgress> progressController =
      StreamController<BlobDownloadProgress>.broadcast();

  _TestTransferService({
    required super.channel,
    required super.store,
    required super.servableRefs,
  });

  @override
  Stream<BlobDownloadProgress> get downloadProgress => progressController.stream;

  @override
  void start() {
    startCalls++;
    super.start();
  }

  @override
  Future<BlobFetchResult> fetch(BlobRef ref, {required String campaignId}) {
    fetchCalls++;
    if (onFetch != null) {
      return onFetch!(ref, campaignId);
    }
    return super.fetch(ref, campaignId: campaignId);
  }

  void emitProgress(BlobDownloadProgress p) {
    progressController.add(p);
  }
}

void main() {
  group('ActiveMapController Tests', () {
    late FakeBlobNetwork network;
    late FakeBlobChannelPort channel;
    late FakeBlobStore store;
    late FakeCampaignRepository repo;
    late _TestTransferService transfer;
    late TransportState currentTransportState;

    setUp(() {
      network = FakeBlobNetwork();
      channel = network.createChannel('me');
      store = FakeBlobStore();
      repo = FakeCampaignRepository();
      currentTransportState = TransportState.webRtc;
      transfer = _TestTransferService(
        channel: channel,
        store: store,
        servableRefs: () => activeMapServableRefs(repo),
      );
    });

    test('C1: Each row of the state table is reached from the condition in its When column', () {
      fakeAsync((async) {
        // 1. MapNone: active profile has no map
        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );
        controller.start();
        async.flushMicrotasks();
        expect(controller.current, equals(const MapNone()));

        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);

        // 2. MapLoading: fetch started and no progress yet
        final completer = Completer<BlobFetchResult>();
        transfer.onFetch = (r, c) => completer.future;

        repo.putProfile(_makeProfile(mapRef: ref));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapLoading()));

        // 3. MapDownloading: progress events for current hash
        transfer.emitProgress(BlobDownloadProgress(
          sha256Hex: ref.sha256Hex,
          chunksReceived: 2,
          chunksTotal: 5,
        ));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapDownloading(2, 5)));

        // 4. MapWaitingForPeer: fetch returns notAvailable or corrupt
        completer.complete(const BlobFetchIncomplete(BlobIncompleteReason.notAvailable, 3));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapWaitingForPeer()));

        // 5. MapConnecting: noDirectPeers and transportState != fallbackRelay
        transfer.onFetch = (r, c) async =>
            const BlobFetchIncomplete(BlobIncompleteReason.noDirectPeers, 3);
        final refConnecting = _makeRef(_makeWebp(60));
        repo.putProfile(_makeProfile(mapRef: refConnecting));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapConnecting()));

        // 6. MapRelayOnly: noDirectPeers and transportState == fallbackRelay
        currentTransportState = TransportState.fallbackRelay;
        final refRelay = _makeRef(_makeWebp(70));
        repo.putProfile(_makeProfile(mapRef: refRelay));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapRelayOnly()));

        // 7. MapStoreUnavailable: store threw BlobStoreUnavailableException
        transfer.onFetch = (r, c) => throw const BlobStoreUnavailableException('disk full');
        final refStoreUnavail = _makeRef(_makeWebp(80));
        repo.putProfile(_makeProfile(mapRef: refStoreUnavail));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapStoreUnavailable('disk full')));

        // 8. MapReady: bytes are on this device
        store.put(ref, bytes, campaignId: 'camp-1');
        transfer.onFetch = (r, c) async => const BlobFetched();
        repo.putProfile(_makeProfile(mapRef: ref));
        async.flushMicrotasks();
        expect(controller.current, equals(MapReady(ref, bytes)));

        // 9. MapFailed: any other error
        transfer.onFetch = (r, c) => throw StateError('unexpected error');
        final refFail = _makeRef(_makeWebp(90));
        repo.putProfile(_makeProfile(mapRef: refFail));
        async.flushMicrotasks();
        expect(controller.current, isA<MapFailed>());

        controller.dispose();
      });
    });

    test('C2: Profile event that changes only notes does not start a new fetch', () {
      fakeAsync((async) {
        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);
        store.put(ref, bytes, campaignId: 'camp-1');
        transfer.onFetch = (r, c) async => const BlobFetched();

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );
        repo.putProfile(_makeProfile(mapRef: ref, notes: 'Initial'));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref, bytes)));
        final callsBefore = transfer.fetchCalls;

        // Change only notes
        repo.putProfile(_makeProfile(mapRef: ref, notes: 'Updated notes'));
        async.flushMicrotasks();

        expect(transfer.fetchCalls, equals(callsBefore));
        controller.dispose();
      });
    });

    test('C3: Stale result dropped on target switch or clear', () {
      fakeAsync((async) {
        final bytesA = _makeWebp(50);
        final refA = _makeRef(bytesA);
        final bytesB = _makeWebp(60);
        final refB = _makeRef(bytesB);

        final compA = Completer<BlobFetchResult>();
        transfer.onFetch = (ref, campId) {
          if (ref.sha256Hex == refA.sha256Hex) {
            return compA.future;
          } else if (ref.sha256Hex == refB.sha256Hex) {
            store.put(refB, bytesB, campaignId: campId);
            return Future.value(const BlobFetched());
          }
          return Future.value(const BlobFetchIncomplete(BlobIncompleteReason.notAvailable, 1));
        };

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );

        final recordedStates = <ActiveMapViewState>[];
        controller.states.listen(recordedStates.add);

        repo.putProfile(_makeProfile(mapRef: refA));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(const MapLoading()));

        // Switch to map B while A is still pending
        repo.putProfile(_makeProfile(mapRef: refB));
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(refB, bytesB)));

        // Now A completes later
        store.put(refA, bytesA, campaignId: 'camp-1');
        compA.complete(const BlobFetched());
        async.flushMicrotasks();

        // Must still be Ready(B), never Ready(A)
        expect(controller.current, equals(MapReady(refB, bytesB)));
        for (final st in recordedStates) {
          if (st is MapReady) {
            expect(st.ref, equals(refB));
          }
        }

        // Now test: A downloading, then cleared -> ends MapNone
        final compA2 = Completer<BlobFetchResult>();
        transfer.onFetch = (ref, campId) => compA2.future;
        repo.putProfile(_makeProfile(mapRef: refA));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapLoading()));

        repo.putProfile(_makeProfile(mapRef: null));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapNone()));

        compA2.complete(const BlobFetched());
        async.flushMicrotasks();
        expect(controller.current, equals(const MapNone()));

        controller.dispose();
      });
    });

    test('C4: Relay to direct: fallbackRelay -> MapRelayOnly, new peer opens -> MapReady without timer; removing peer starts no fetch', () {
      fakeAsync((async) {
        currentTransportState = TransportState.fallbackRelay;
        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);

        transfer.onFetch = (r, c) async {
          if (channel.openBlobPeers.contains('dm')) {
            await store.put(ref, bytes, campaignId: c);
            return const BlobFetched();
          }
          return const BlobFetchIncomplete(BlobIncompleteReason.noDirectPeers, 1);
        };

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
          retryInterval: const Duration(hours: 1),
        );

        repo.putProfile(_makeProfile(mapRef: ref));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(const MapRelayOnly()));

        // Open peer 'dm'
        network.createChannel('dm');
        network.openChannelBetween('me', 'dm');
        async.flushMicrotasks();

        // Without advancing the 1-hour timer, it should have retried and become MapReady
        expect(controller.current, equals(MapReady(ref, bytes)));
        final fetchCount = transfer.fetchCalls;

        // Control: a peer event that only removes a peer starts no fetch
        network.closeChannelBetween('me', 'dm');
        async.flushMicrotasks();

        expect(transfer.fetchCalls, equals(fetchCount));
        controller.dispose();
      });
    });

    test('C5: Timer retry: notAvailable -> MapWaitingForPeer, after retryInterval -> MapReady', () {
      fakeAsync((async) {
        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);
        var peerHasMap = false;

        transfer.onFetch = (r, c) async {
          if (peerHasMap) {
            await store.put(ref, bytes, campaignId: c);
            return const BlobFetched();
          }
          return const BlobFetchIncomplete(BlobIncompleteReason.notAvailable, 1);
        };

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
          retryInterval: const Duration(seconds: 15),
        );

        repo.putProfile(_makeProfile(mapRef: ref));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(const MapWaitingForPeer()));

        // Serving peer gains the blob
        peerHasMap = true;

        // Advance timer by one retryInterval
        async.elapse(const Duration(seconds: 15));
        expect(controller.current, equals(MapReady(ref, bytes)));

        controller.dispose();
      });
    });

    test('C6: BlobStoreUnavailableException -> MapStoreUnavailable, no further fetch over 10 retry intervals', () {
      fakeAsync((async) {
        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);

        transfer.onFetch = (r, c) => throw const BlobStoreUnavailableException('quota');

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
          retryInterval: const Duration(seconds: 15),
        );

        repo.putProfile(_makeProfile(mapRef: ref));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(const MapStoreUnavailable('quota')));
        final fetchCount = transfer.fetchCalls;

        async.elapse(const Duration(seconds: 150)); // 10 intervals
        expect(transfer.fetchCalls, equals(fetchCount));

        controller.dispose();
      });
    });

    test('C7: Progress events for current hash update MapDownloading, other hash ignored', () {
      fakeAsync((async) {
        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);
        final comp = Completer<BlobFetchResult>();
        transfer.onFetch = (r, c) => comp.future;

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );

        repo.putProfile(_makeProfile(mapRef: ref));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(const MapLoading()));

        // Event for another hash -> ignored
        transfer.emitProgress(const BlobDownloadProgress(
          sha256Hex: 'otherhash00000000000000000000000000000000000000000000000000000000',
          chunksReceived: 1,
          chunksTotal: 10,
        ));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapLoading()));

        // Event for current hash -> MapDownloading
        transfer.emitProgress(BlobDownloadProgress(
          sha256Hex: ref.sha256Hex,
          chunksReceived: 2,
          chunksTotal: 5,
        ));
        async.flushMicrotasks();
        expect(controller.current, equals(const MapDownloading(2, 5)));
        expect((controller.current as MapDownloading).percent, equals(40));

        controller.dispose();
      });
    });

    test('C8: start() called three times starts transfer once and subscribes once', () {
      fakeAsync((async) {
        final bytes = _makeWebp(50);
        final ref = _makeRef(bytes);
        store.put(ref, bytes, campaignId: 'camp-1');
        transfer.onFetch = (r, c) async => const BlobFetched();

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );

        repo.putProfile(_makeProfile(mapRef: ref));
        controller.start();
        controller.start();
        controller.start();
        async.flushMicrotasks();

        expect(transfer.startCalls, equals(1));
        expect(transfer.fetchCalls, equals(1));

        controller.dispose();
      });
    });
  });
}
