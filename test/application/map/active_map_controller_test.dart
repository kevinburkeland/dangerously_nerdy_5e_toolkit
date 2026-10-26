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
  MapGrid? grid,
  String notes = '',
  CrdtOrSet<MapToken>? mapTokens,
  CrdtOrSet<MapTokenCell>? mapTokenCells,
  CrdtOrSet<String>? minionOwners,
  CrdtOrSet<dynamic>? activeMinions,
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
    mapTokens: mapTokens ?? const CrdtOrSet<MapToken>.empty(),
    mapTokenCells: mapTokenCells ?? const CrdtOrSet<MapTokenCell>.empty(),
    minionOwners: minionOwners ?? const CrdtOrSet<String>.empty(),
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    roomState: const RoomNodeState.empty().copyWith(
      activeMinions: activeMinions,
    ),
  );
}

class _CountingBlobStore extends FakeBlobStore {
  int getCalls = 0;

  @override
  Future<StoredBlob> get(String sha256Hex) {
    getCalls++;
    return super.get(sha256Hex);
  }
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

    test('GC2: Grid updates on ready map emit MapReady with grid without new fetch/get, non-matching hash gives null grid, sharing new map makes grid null, hiding grid gives visible: false', () {
      fakeAsync((async) {
        final countingStore = _CountingBlobStore();
        final bytes1 = _makeWebp(50);
        final ref1 = _makeRef(bytes1);
        countingStore.put(ref1, bytes1, campaignId: 'camp-1');

        final bytes2 = _makeWebp(60);
        final ref2 = _makeRef(bytes2);
        countingStore.put(ref2, bytes2, campaignId: 'camp-1');

        transfer.onFetch = (r, c) async => const BlobFetched();

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: countingStore,
          channel: channel,
          transportState: () => currentTransportState,
        );

        final states = <ActiveMapViewState>[];
        final sub = controller.states.listen(states.add);

        // 1. Initial profile with map ref1, no grid
        repo.putProfile(_makeProfile(mapRef: ref1));
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref1, bytes1, grid: null)));
        final fetchCallsBefore = transfer.fetchCalls;
        final getCallsBefore = countingStore.getCalls;

        // 2. Setting a matching grid emits MapReady with that grid, no new fetch or store get
        final grid1 = MapGrid(
          mapSha256Hex: ref1.sha256Hex,
          cellCentiPx: 4500,
          offsetXCentiPx: 100,
          offsetYCentiPx: 200,
          feetPerCell: 5,
          visible: true,
        );
        repo.putProfile(_makeProfile(mapRef: ref1, grid: grid1));
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref1, bytes1, grid: grid1)));
        expect((controller.current as MapReady).bytes, equals(bytes1));
        expect(transfer.fetchCalls, equals(fetchCallsBefore));
        expect(countingStore.getCalls, equals(getCallsBefore));

        // 3. Changing only the grid emits again with the same bytes and no new fetch or store get
        final grid2 = MapGrid(
          mapSha256Hex: ref1.sha256Hex,
          cellCentiPx: 5000,
          offsetXCentiPx: 0,
          offsetYCentiPx: 0,
          feetPerCell: 10,
          visible: true,
        );
        repo.putProfile(_makeProfile(mapRef: ref1, grid: grid2));
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref1, bytes1, grid: grid2)));
        expect((controller.current as MapReady).bytes, equals(bytes1));
        expect(transfer.fetchCalls, equals(fetchCallsBefore));
        expect(countingStore.getCalls, equals(getCallsBefore));

        // 4. A grid with a different hash gives grid == null
        final gridOther = MapGrid(
          mapSha256Hex: 'b' * 64,
          cellCentiPx: 5000,
          offsetXCentiPx: 0,
          offsetYCentiPx: 0,
          feetPerCell: 5,
          visible: true,
        );
        repo.putProfile(_makeProfile(mapRef: ref1, grid: gridOther));
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref1, bytes1, grid: null)));
        expect((controller.current as MapReady).bytes, equals(bytes1));
        expect(transfer.fetchCalls, equals(fetchCallsBefore));
        expect(countingStore.getCalls, equals(getCallsBefore));

        // 5. Sharing a new map makes grid null even though the old grid is still in the profile
        repo.putProfile(_makeProfile(mapRef: ref2, grid: grid1));
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref2, bytes2, grid: null)));
        expect((controller.current as MapReady).bytes, equals(bytes2));

        // 6. Hiding the grid gives MapReady with a grid whose visible is false
        final grid2Hidden = MapGrid(
          mapSha256Hex: ref2.sha256Hex,
          cellCentiPx: 5000,
          offsetXCentiPx: 0,
          offsetYCentiPx: 0,
          feetPerCell: 5,
          visible: false,
        );
        repo.putProfile(_makeProfile(mapRef: ref2, grid: grid2Hidden));
        async.flushMicrotasks();

        expect(controller.current, equals(MapReady(ref2, bytes2, grid: grid2Hidden)));
        expect((controller.current as MapReady).grid!.visible, isFalse);

        sub.cancel();
        controller.dispose();
      });
    });

    test('CT1: Token placement, move, removal, and minion owner changes emit MapReady with identical bytes, no new store.get calls, and exactly one state per action', () {
      fakeAsync((async) {
        final countingStore = _CountingBlobStore();
        final bytes1 = _makeWebp(1024);
        final ref1 = _makeRef(bytes1);
        final bytes2 = _makeWebp(2048);
        final ref2 = _makeRef(bytes2);
        countingStore.put(ref1, bytes1, campaignId: 'camp-1');
        countingStore.put(ref2, bytes2, campaignId: 'camp-1');

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: _TestTransferService(
            channel: channel,
            store: countingStore,
            servableRefs: () => activeMapServableRefs(repo),
          ),
          store: countingStore,
          channel: channel,
          transportState: () => currentTransportState,
        );

        final emittedStates = <ActiveMapViewState>[];
        final sub = controller.states.listen(emittedStates.add);

        // Active minions in room
        const stamp = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
        final minions = const CrdtOrSet<dynamic>.empty().add('m1', {'id': 'm1'}, stamp);

        var currentProfile = _makeProfile(mapRef: ref1, activeMinions: minions);
        repo.putProfile(currentProfile);
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, isA<MapReady>());
        final initialReady = controller.current as MapReady;
        final getCallsBefore = countingStore.getCalls;
        expect(getCallsBefore, equals(1));
        final stateCountBefore = emittedStates.length;

        // 1. Placing a token on this map emits exactly 1 MapReady listing it, with identical bytes and no new store.get
        final tok1 = MapToken(id: 'tok_00000000000000000000000000000001', mapSha256Hex: ref1.sha256Hex, kind: MapTokenKind.character, refId: 'c1', label: 'T1');
        final cell1 = MapTokenCell(col: 2, row: 3);
        currentProfile = currentProfile.withTokenPlaced(tok1, cell1, const HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(stateCountBefore + 1));
        final readyAfterPlace = controller.current as MapReady;
        expect(identical(readyAfterPlace.bytes, initialReady.bytes), isTrue);
        expect(countingStore.getCalls, equals(getCallsBefore));
        expect(readyAfterPlace.tokens.length, equals(1));
        expect(readyAfterPlace.tokens.first.token.id, equals(tok1.id));
        expect(readyAfterPlace.tokens.first.cell, equals(cell1));

        // 2. Token on another map isn't listed and emits nothing (target map tokens unchanged)
        final tokOther = MapToken(id: 'tok_00000000000000000000000000000002', mapSha256Hex: ref2.sha256Hex, kind: MapTokenKind.character, refId: 'c2', label: 'T2');
        currentProfile = currentProfile.withTokenPlaced(tokOther, MapTokenCell(col: 5, row: 5), const HybridLogicalClock(physicalTime: 250, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(stateCountBefore + 1)); // No new state emitted
        expect((controller.current as MapReady).tokens.length, equals(1));

        // 3. Move emits the new cell (exactly one state)
        final cell1Moved = MapTokenCell(col: 4, row: 6);
        currentProfile = currentProfile.withTokenMoved(tok1.id, cell1Moved, const HybridLogicalClock(physicalTime: 300, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(stateCountBefore + 2));
        final readyAfterMove = controller.current as MapReady;
        expect(readyAfterMove.tokens.first.cell, equals(cell1Moved));
        expect(identical(readyAfterMove.bytes, initialReady.bytes), isTrue);
        expect(countingStore.getCalls, equals(getCallsBefore));

        // 4. Setting an owner changes minionOwners (exactly one state)
        currentProfile = currentProfile.withMinionOwner('m1', 'thorin', const HybridLogicalClock(physicalTime: 400, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(stateCountBefore + 3));
        final readyAfterOwnerSet = controller.current as MapReady;
        expect(readyAfterOwnerSet.minionOwners['m1'], equals('thorin'));
        expect(identical(readyAfterOwnerSet.bytes, initialReady.bytes), isTrue);

        // 5. Clearing an owner changes minionOwners (exactly one state)
        currentProfile = currentProfile.withMinionOwner('m1', null, const HybridLogicalClock(physicalTime: 500, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(stateCountBefore + 4));
        final readyAfterOwnerClear = controller.current as MapReady;
        expect(readyAfterOwnerClear.minionOwners.containsKey('m1'), isFalse);
        expect(identical(readyAfterOwnerClear.bytes, initialReady.bytes), isTrue);

        // 6. Removal emits a list without it (exactly one state)
        currentProfile = currentProfile.withTokenRemoved(tok1.id, const HybridLogicalClock(physicalTime: 600, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(stateCountBefore + 5));
        final readyAfterRemove = controller.current as MapReady;
        expect(readyAfterRemove.tokens, isEmpty);
        expect(identical(readyAfterRemove.bytes, initialReady.bytes), isTrue);
        expect(countingStore.getCalls, equals(getCallsBefore));

        sub.cancel();
        controller.dispose();
      });
    });

    test('CT2: Profile change to notes only emits nothing', () {
      fakeAsync((async) {
        final bytes = _makeWebp(1024);
        final ref = _makeRef(bytes);
        store.put(ref, bytes, campaignId: 'camp-1');

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );

        final emittedStates = <ActiveMapViewState>[];
        final sub = controller.states.listen(emittedStates.add);

        var currentProfile = _makeProfile(mapRef: ref, notes: 'Original notes');
        repo.putProfile(currentProfile);
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, isA<MapReady>());
        final countAfterReady = emittedStates.length;

        // Change notes only
        currentProfile = currentProfile.copyWith(
          notesRegister: const CrdtLwwRegister<String>(
            value: 'Updated notes',
            timestamp: HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1'),
          ),
        );
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(emittedStates.length, equals(countAfterReady));

        sub.cancel();
        controller.dispose();
      });
    });

    test('CT3: Switching to another map and back brings old map tokens back with their cells', () {
      fakeAsync((async) {
        final bytes1 = _makeWebp(1024);
        final ref1 = _makeRef(bytes1);
        final bytes2 = _makeWebp(2048);
        final ref2 = _makeRef(bytes2);
        store.put(ref1, bytes1, campaignId: 'camp-1');
        store.put(ref2, bytes2, campaignId: 'camp-1');

        final controller = ActiveMapController(
          campaignRepo: repo,
          transfer: transfer,
          store: store,
          channel: channel,
          transportState: () => currentTransportState,
        );

        final sub = controller.states.listen((_) {});

        final tok1 = MapToken(id: 'tok_00000000000000000000000000000001', mapSha256Hex: ref1.sha256Hex, kind: MapTokenKind.character, refId: 'c1', label: 'T1');
        final cell1 = MapTokenCell(col: 5, row: 8);

        var currentProfile = _makeProfile(mapRef: ref1).withTokenPlaced(tok1, cell1, const HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1'));
        repo.putProfile(currentProfile);
        controller.start();
        async.flushMicrotasks();

        expect(controller.current, isA<MapReady>());
        expect((controller.current as MapReady).ref, equals(ref1));
        expect((controller.current as MapReady).tokens.length, equals(1));
        expect((controller.current as MapReady).tokens.first.cell, equals(cell1));

        // Switch to map 2
        currentProfile = currentProfile.copyWith(
          activeMapRegister: CrdtLwwRegister<BlobRef?>(
            value: ref2,
            timestamp: const HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1'),
          ),
        );
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(controller.current, isA<MapReady>());
        expect((controller.current as MapReady).ref, equals(ref2));
        expect((controller.current as MapReady).tokens, isEmpty);

        // Switch back to map 1
        currentProfile = currentProfile.copyWith(
          activeMapRegister: CrdtLwwRegister<BlobRef?>(
            value: ref1,
            timestamp: const HybridLogicalClock(physicalTime: 300, logicalCounter: 0, nodeId: 'n1'),
          ),
        );
        repo.putProfile(currentProfile);
        async.flushMicrotasks();

        expect(controller.current, isA<MapReady>());
        final readyBack = controller.current as MapReady;
        expect(readyBack.ref, equals(ref1));
        expect(readyBack.tokens.length, equals(1));
        expect(readyBack.tokens.first.token.id, equals(tok1.id));
        expect(readyBack.tokens.first.cell, equals(cell1));

        sub.cancel();
        controller.dispose();
      });
    });
  });
}
