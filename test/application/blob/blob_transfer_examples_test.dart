import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_protocol.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';

Uint8List _makeWebp(int byteSize) {
  final bytes = Uint8List(byteSize);
  bytes[0] = 0x52; bytes[1] = 0x49; bytes[2] = 0x46; bytes[3] = 0x46; // RIFF
  bytes[8] = 0x57; bytes[9] = 0x45; bytes[10] = 0x42; bytes[11] = 0x50; // WEBP
  for (var i = 12; i < byteSize; i++) {
    bytes[i] = (i * 31) % 256;
  }
  return bytes;
}

Uint8List _makeJpeg(int byteSize) {
  final bytes = Uint8List(byteSize);
  bytes[0] = 0xFF; bytes[1] = 0xD8; bytes[2] = 0xFF; // JPEG
  for (var i = 3; i < byteSize; i++) {
    bytes[i] = (i * 17) % 256;
  }
  return bytes;
}

BlobRef _makeRef(Uint8List bytes, BlobFormat format) {
  return BlobRef(
    sha256Hex: sha256.convert(bytes).toString().toLowerCase(),
    byteSize: bytes.length,
    width: 200,
    height: 200,
    format: format,
  );
}

void main() {
  group('BlobTransferService Examples (E1 - E14)', () {
    test('E1: DM has the file, player fetches: BlobFetched, player store holds exact bytes, owner is campaign id', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final dmStore = FakeBlobStore();
        final playerStore = FakeBlobStore();

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);
        dmStore.put(ref, bytes, campaignId: 'c_dm');

        final dmService = BlobTransferService(
          channel: dmPort,
          store: dmStore,
          servableRefs: () => [ref],
        )..start();

        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        expect(result, isA<BlobFetched>());
        expect(playerStore.count, equals(1));
        final stored = playerStore.get(ref.sha256Hex);
        async.flushMicrotasks();
        stored.then((s) {
          expect(s.bytes, equals(bytes));
          expect(playerStore.getOwners(ref.sha256Hex), contains('c_player'));
        });

        dmService.dispose();
        playerService.dispose();
      });
    });

    test('E2: already stored: BlobFetched, zero messages sent, owner added', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final playerPort = net.createChannel('player');
        final playerStore = FakeBlobStore();

        final bytes = _makeWebp(500);
        final ref = _makeRef(bytes, BlobFormat.webp);
        playerStore.put(ref, bytes, campaignId: 'c_original');

        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_new').then((r) => result = r);
        async.flushMicrotasks();

        expect(result, isA<BlobFetched>());
        expect(net.sentMessages, isEmpty);
        expect(playerStore.getOwners(ref.sha256Hex), containsAll({'c_original', 'c_new'}));

        playerService.dispose();
      });
    });

    test('E3: no open blob peer (mesh-only or relay-only): noDirectPeers, zero messages sent', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final playerPort = net.createChannel('player');
        final playerStore = FakeBlobStore();

        final bytes = _makeWebp(500);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);
        async.flushMicrotasks();

        expect(result, equals(BlobFetchIncomplete(BlobIncompleteReason.noDirectPeers, blobChunkCount(ref.byteSize))));
        expect(net.sentMessages, isEmpty);

        playerService.dispose();
      });
    });

    test('E4: first peer answers none, second has it: fetched from the second', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final p1Port = net.createChannel('p1');
        final p2Port = net.createChannel('p2');
        final playerPort = net.createChannel('player');

        net.openChannelBetween('player', 'p1');
        net.openChannelBetween('player', 'p2');

        final p1Store = FakeBlobStore();
        final p2Store = FakeBlobStore();
        final playerStore = FakeBlobStore();

        final bytes = _makeWebp(2000);
        final ref = _makeRef(bytes, BlobFormat.webp);
        p2Store.put(ref, bytes, campaignId: 'c_p2');

        final p1Service = BlobTransferService(channel: p1Port, store: p1Store, servableRefs: () => [])..start();
        final p2Service = BlobTransferService(channel: p2Port, store: p2Store, servableRefs: () => [ref])..start();
        final playerService = BlobTransferService(channel: playerPort, store: playerStore, servableRefs: () => [])..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);
        async.elapse(const Duration(milliseconds: 100));

        expect(result, isA<BlobFetched>());
        expect(playerStore.count, equals(1));

        p1Service.dispose();
        p2Service.dispose();
        playerService.dispose();
      });
    });

    test('E5: first peer stalls after 3 chunks: after stallTimeout second peer is asked for missing indices', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final p1Port = net.createChannel('p1');
        final p2Port = net.createChannel('p2');
        final playerPort = net.createChannel('player');

        net.openChannelBetween('player', 'p1');
        net.openChannelBetween('player', 'p2');

        final bytes = _makeWebp(5 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);

        // p1 stalls after 3 chunks
        final p1Prog = ProgrammedServingPeer(
          peerId: 'p1',
          channel: p1Port,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.stallsAfterK,
          kParam: 3,
        )..start();

        // p2 is honest
        final p2Prog = ProgrammedServingPeer(
          peerId: 'p2',
          channel: p2Port,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
          stallTimeout: const Duration(seconds: 10),
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        // p1 delivers 3 chunks right away
        async.elapse(const Duration(milliseconds: 50));
        expect(result, isNull);

        // Advance until stallTimeout fires (10 seconds)
        async.elapse(const Duration(seconds: 10));

        expect(result, isA<BlobFetched>());
        expect(playerStore.count, equals(1));

        // Check that p2 was asked for exactly [3, 4]
        final wantsToP2 = net.sentMessages
            .where((m) => m.sender == 'player' && m.recipient == 'p2' && m.isText)
            .map((m) => parseBlobControl(m.text!))
            .whereType<BlobWantMessage>()
            .toList();
        expect(wantsToP2.length, equals(1));
        expect(wantsToP2.first.missingIndices, equals([3, 4]));

        p1Prog.stop();
        p2Prog.stop();
        playerService.dispose();
      });
    });

    test('E6: first peer leaves after 3 chunks: second peer asked before stallTimeout passes, only for missing indices', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final p1Port = net.createChannel('p1');
        final p2Port = net.createChannel('p2');
        final playerPort = net.createChannel('player');

        net.openChannelBetween('player', 'p1');
        net.openChannelBetween('player', 'p2');

        final bytes = _makeWebp(5 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final p1Prog = ProgrammedServingPeer(
          peerId: 'p1',
          channel: p1Port,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.leavesAfterK,
          kParam: 3,
        )..start();

        final p2Prog = ProgrammedServingPeer(
          peerId: 'p2',
          channel: p2Port,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
          stallTimeout: const Duration(seconds: 10),
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        // Only 50ms pass (much less than 10s stallTimeout)
        async.elapse(const Duration(milliseconds: 50));

        expect(result, isA<BlobFetched>());
        expect(playerStore.count, equals(1));

        final wantsToP2 = net.sentMessages
            .where((m) => m.sender == 'player' && m.recipient == 'p2' && m.isText)
            .map((m) => parseBlobControl(m.text!))
            .whereType<BlobWantMessage>()
            .toList();
        expect(wantsToP2.length, equals(1));
        expect(wantsToP2.first.missingIndices, equals([3, 4]));

        p1Prog.stop();
        p2Prog.stop();
        playerService.dispose();
      });
    });

    test('E7: first peer serves copy with one flipped byte: nothing stored from it, second peer asked for whole file, first peer not asked again, final bytes correct', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final p1Port = net.createChannel('p1');
        final p2Port = net.createChannel('p2');
        final playerPort = net.createChannel('player');

        net.openChannelBetween('player', 'p1');
        net.openChannelBetween('player', 'p2');

        final bytes = _makeWebp(2 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final p1Prog = ProgrammedServingPeer(
          peerId: 'p1',
          channel: p1Port,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.servesFlippedByte,
        )..start();

        final p2Prog = ProgrammedServingPeer(
          peerId: 'p2',
          channel: p2Port,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        async.elapse(const Duration(milliseconds: 100));

        expect(result, isA<BlobFetched>());
        expect(playerStore.putAttempts.length, equals(1));
        expect(playerStore.putAttempts.first.bytes, equals(bytes));

        // p1 was asked once
        final wantsToP1 = net.sentMessages
            .where((m) => m.sender == 'player' && m.recipient == 'p1' && m.isText)
            .toList();
        expect(wantsToP1.length, equals(1));

        // p2 was asked for the whole file
        final wantsToP2 = net.sentMessages
            .where((m) => m.sender == 'player' && m.recipient == 'p2' && m.isText)
            .map((m) => parseBlobControl(m.text!))
            .whereType<BlobWantMessage>()
            .toList();
        expect(wantsToP2.length, equals(1));
        expect(wantsToP2.first.missingIndices, equals([0, 1]));

        p1Prog.stop();
        p2Prog.stop();
        playerService.dispose();
      });
    });

    test('E8: ref format is webp while real file is JPEG: peers send hash-correct bytes, result is corrupt, nothing stored', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final jpegBytes = _makeJpeg(1000);
        // Create ref with webp format but hash of JPEG bytes
        final ref = BlobRef(
          sha256Hex: sha256.convert(jpegBytes).toString().toLowerCase(),
          byteSize: jpegBytes.length,
          width: 100,
          height: 100,
          format: BlobFormat.webp, // Mismatch!
        );

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: jpegBytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        async.elapse(const Duration(milliseconds: 100));

        expect(result, isA<BlobFetchIncomplete>());
        final incomplete = result as BlobFetchIncomplete;
        expect(incomplete.reason, equals(BlobIncompleteReason.corrupt));
        expect(playerStore.count, equals(0));

        dmProg.stop();
        playerService.dispose();
      });
    });

    test('E9: peer sends index = chunk count, payload too long, last chunk longer than remainder: dropped, next peer asked, file correct', () {
      for (final badCase in ['indexOutOfRange', 'payloadTooLong', 'lastChunkLonger']) {
        fakeAsync((async) {
          final net = FakeBlobNetwork();
          final p1Port = net.createChannel('p1');
          final p2Port = net.createChannel('p2');
          final playerPort = net.createChannel('player');

          net.openChannelBetween('player', 'p1');
          net.openChannelBetween('player', 'p2');

          final bytes = _makeWebp(kBlobChunkBytes + 100); // 2 chunks: chunk 0 = 65536, chunk 1 = 100
          final ref = _makeRef(bytes, BlobFormat.webp);

          // p1 sends bad frame
          final p1Sub = p1Port.blobMessages.listen((msg) async {
            if (!msg.isText) return;
            if (badCase == 'indexOutOfRange') {
              // Send index = 2 (chunk count is 2, valid indices 0, 1)
              final frame = encodeChunkFrame(sha256Hex: ref.sha256Hex, index: 2, payload: Uint8List(100));
              await p1Port.sendBlobFrame('player', frame);
            } else if (badCase == 'payloadTooLong') {
              // Expected 100 bytes for chunk 1, send 101 bytes
              final badFrame = encodeChunkFrame(sha256Hex: ref.sha256Hex, index: 1, payload: Uint8List(101));
              await p1Port.sendBlobFrame('player', badFrame);
            } else if (badCase == 'lastChunkLonger') {
              final badFrame = encodeChunkFrame(sha256Hex: ref.sha256Hex, index: 1, payload: Uint8List(150)); // expected 100
              await p1Port.sendBlobFrame('player', badFrame);
            }
          });

          final p2Prog = ProgrammedServingPeer(
            peerId: 'p2',
            channel: p2Port,
            ref: ref,
            originalBytes: bytes,
            behavior: PeerBehavior.honest,
          )..start();

          final playerStore = FakeBlobStore();
          final playerService = BlobTransferService(
            channel: playerPort,
            store: playerStore,
            servableRefs: () => [],
          )..start();

          BlobFetchResult? result;
          playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

          async.elapse(const Duration(milliseconds: 100));

          expect(result, isA<BlobFetched>(), reason: 'Failed for badCase: $badCase');
          expect(playerStore.count, equals(1));

          p1Sub.cancel();
          p2Prog.stop();
          playerService.dispose();
        });
      }
    });

    test('E10: frames for another hash and frames from peer not asked are ignored and do not reset stall timer', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final p1Port = net.createChannel('p1');
        final unaskedPort = net.createChannel('unasked');
        final playerPort = net.createChannel('player');

        net.openChannelBetween('player', 'p1');
        net.openChannelBetween('player', 'unasked');

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final otherBytes = _makeWebp(1000);
        otherBytes[15] ^= 0x55;
        final otherRef = _makeRef(otherBytes, BlobFormat.webp);

        // p1 stalls (sends nothing for ref)
        // Send stray frames from unasked and stray frames for otherRef
        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
          stallTimeout: const Duration(seconds: 10),
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        // At 2s, send frame for other hash from p1
        async.elapse(const Duration(seconds: 2));
        final otherFrame = encodeChunkFrame(sha256Hex: otherRef.sha256Hex, index: 0, payload: otherBytes);
        p1Port.sendBlobFrame('player', otherFrame);

        // At 5s, send frame from unasked peer
        async.elapse(const Duration(seconds: 3));
        final unaskedFrame = encodeChunkFrame(sha256Hex: ref.sha256Hex, index: 0, payload: bytes);
        unaskedPort.sendBlobFrame('player', unaskedFrame);

        // At exactly 10s from start (5s more), p1 stallTimeout fires and unasked is asked!
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // If stray frames reset the timer, unasked would not be asked at 10s
        final wantsToUnasked = net.sentMessages
            .where((m) => m.sender == 'player' && m.recipient == 'unasked' && m.isText)
            .map((m) => parseBlobControl(m.text!))
            .whereType<BlobWantMessage>()
            .toList();
        expect(wantsToUnasked, hasLength(1));
        expect(result, isNull); // unasked is now being asked

        // Elapse 10s more for unasked to stall
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(result, isA<BlobFetchIncomplete>());
        expect((result as BlobFetchIncomplete).reason, equals(BlobIncompleteReason.notAvailable));

        playerService.dispose();
      });
    });

    test('E11: every frame duplicated: file correct, each index kept once', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        net.duplicateAllFrames = true;

        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final bytes = _makeWebp(2 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        async.elapse(const Duration(milliseconds: 100));

        expect(result, isA<BlobFetched>());
        expect(playerStore.count, equals(1));
        expect(playerStore.putAttempts.length, equals(1));

        dmProg.stop();
        playerService.dispose();
      });
    });

    test('E12: two fetch calls for same hash at once: exactly one want sent, both return BlobFetched, both campaigns are owners', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? res1;
        BlobFetchResult? res2;
        playerService.fetch(ref, campaignId: 'c_one').then((r) => res1 = r);
        playerService.fetch(ref, campaignId: 'c_two').then((r) => res2 = r);

        async.elapse(const Duration(milliseconds: 100));

        expect(res1, isA<BlobFetched>());
        expect(res2, isA<BlobFetched>());

        final wants = net.sentMessages
            .where((m) => m.sender == 'player' && m.recipient == 'dm' && m.isText)
            .toList();
        expect(wants.length, equals(1));

        expect(playerStore.getOwners(ref.sha256Hex), containsAll({'c_one', 'c_two'}));

        dmProg.stop();
        playerService.dispose();
      });
    });

    test('E13: fake store throws on put: fetch throws that error', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore()..throwOnPut = true;
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        Object? caughtError;
        playerService.fetch(ref, campaignId: 'c_player').catchError((e) {
          caughtError = e;
          return const BlobFetched();
        });

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        expect(caughtError, isNotNull);
        expect(caughtError, isA<StateError>());

        dmProg.stop();
        playerService.dispose();
      });
    });

    test('E14: peer whose blob channel never opens (older build) is never asked', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        net.markAsOldBuild('oldPeer');
        final oldPort = net.createChannel('oldPeer');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('player', 'oldPeer'); // old build ignores opening blob channel

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final playerStore = FakeBlobStore();
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? result;
        playerService.fetch(ref, campaignId: 'c_player').then((r) => result = r);

        async.flushMicrotasks();

        expect(result, isA<BlobFetchIncomplete>());
        expect((result as BlobFetchIncomplete).reason, equals(BlobIncompleteReason.noDirectPeers));
        expect(net.sentMessages, isEmpty);

        playerService.dispose();
        oldPort.close();
      });
    });
  });

  group('BlobTransferService Serving (S1 - S5)', () {
    test('S1: want for stored hash not in servableRefs and for hash not stored: both get none', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final serverPort = net.createChannel('server');
        final clientPort = net.createChannel('client');
        net.openChannelBetween('server', 'client');

        final serverStore = FakeBlobStore();

        final bytes1 = _makeWebp(1000);
        final ref1 = _makeRef(bytes1, BlobFormat.webp);
        serverStore.put(ref1, bytes1, campaignId: 'c1');

        final bytes2 = _makeWebp(1000);
        bytes2[15] ^= 0x33;
        final ref2 = _makeRef(bytes2, BlobFormat.webp); // not stored

        // servableRefs does NOT include ref1
        final serverService = BlobTransferService(
          channel: serverPort,
          store: serverStore,
          servableRefs: () => [],
        )..start();

        // client sends want for ref1 (stored, but not servable)
        clientPort.sendBlobText('server', encodeBlobWant(ref1.sha256Hex, [0]));
        async.flushMicrotasks();

        // client sends want for ref2 (not stored)
        clientPort.sendBlobText('server', encodeBlobWant(ref2.sha256Hex, [0]));
        async.flushMicrotasks();

        final replies = net.sentMessages
            .where((m) => m.sender == 'server' && m.recipient == 'client' && m.isText)
            .map((m) => parseBlobControl(m.text!))
            .whereType<BlobNoneMessage>()
            .toList();

        expect(replies.length, equals(2));
        expect(replies[0].sha256Hex, equals(ref1.sha256Hex));
        expect(replies[1].sha256Hex, equals(ref2.sha256Hex));

        serverService.dispose();
      });
    });

    test('S2: want for indices [0, 2, 5] gets exactly those three frames, each correct', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final serverPort = net.createChannel('server');
        final clientPort = net.createChannel('client');
        net.openChannelBetween('server', 'client');

        final bytes = _makeWebp(6 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);
        final serverStore = FakeBlobStore();
        serverStore.put(ref, bytes, campaignId: 'c_srv');

        final serverService = BlobTransferService(
          channel: serverPort,
          store: serverStore,
          servableRefs: () => [ref],
        )..start();

        clientPort.sendBlobText('server', encodeBlobWant(ref.sha256Hex, [0, 2, 5]));
        async.flushMicrotasks();

        final frames = net.sentMessages
            .where((m) => m.sender == 'server' && m.recipient == 'client' && m.isFrame)
            .map((m) => decodeChunkFrame(m.frame!))
            .whereType<BlobChunkFrame>()
            .toList();

        expect(frames.length, equals(3));
        expect(frames.map((f) => f.index).toList(), equals([0, 2, 5]));

        for (final f in frames) {
          expect(f.sha256Hex, equals(ref.sha256Hex));
          final expectedLen = blobChunkLength(ref.byteSize, f.index);
          expect(f.payload.length, equals(expectedLen));
        }

        serverService.dispose();
      });
    });

    test('S3: want with index at chunk count: no reply, no exception', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final serverPort = net.createChannel('server');
        final clientPort = net.createChannel('client');
        net.openChannelBetween('server', 'client');

        final bytes = _makeWebp(2 * kBlobChunkBytes); // 2 chunks: 0, 1
        final ref = _makeRef(bytes, BlobFormat.webp);
        final serverStore = FakeBlobStore();
        serverStore.put(ref, bytes, campaignId: 'c_srv');

        final serverService = BlobTransferService(
          channel: serverPort,
          store: serverStore,
          servableRefs: () => [ref],
        )..start();

        // Index 2 is at chunk count
        clientPort.sendBlobText('server', encodeBlobWant(ref.sha256Hex, [0, 2]));
        async.flushMicrotasks();

        final serverReplies = net.sentMessages
            .where((m) => m.sender == 'server' && m.recipient == 'client')
            .toList();

        expect(serverReplies, isEmpty);

        serverService.dispose();
      });
    });

    test('S4: requester leaves mid-serve: fewer frames than asked, no exception escapes', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final serverPort = net.createChannel('server');
        final clientPort = net.createChannel('client');
        net.openChannelBetween('server', 'client');

        final bytes = _makeWebp(10 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);
        final serverStore = FakeBlobStore();
        serverStore.put(ref, bytes, campaignId: 'c_srv');

        final serverService = BlobTransferService(
          channel: serverPort,
          store: serverStore,
          servableRefs: () => [ref],
        )..start();

        // Hook into client to leave after 2 frames
        var framesReceived = 0;
        final sub = clientPort.blobMessages.listen((msg) {
          if (msg.isBinary) {
            framesReceived++;
            if (framesReceived == 2) {
              net.closeChannelBetween('server', 'client');
            }
          }
        });

        clientPort.sendBlobText('server', encodeBlobWant(ref.sha256Hex, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
        async.flushMicrotasks();

        final framesSent = net.sentMessages
            .where((m) => m.sender == 'server' && m.recipient == 'client' && m.isFrame)
            .length;

        expect(framesSent, lessThan(10));

        sub.cancel();
        serverService.dispose();
      });
    });

    test('S5: two peers request same hash at once: store.get is called once', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final serverPort = net.createChannel('server');
        final c1Port = net.createChannel('c1');
        final c2Port = net.createChannel('c2');
        net.openChannelBetween('server', 'c1');
        net.openChannelBetween('server', 'c2');

        final bytes = _makeWebp(2 * kBlobChunkBytes);
        final ref = _makeRef(bytes, BlobFormat.webp);

        var getCallCount = 0;
        final serverStore = _CountingBlobStore(onGet: () => getCallCount++);
        serverStore.put(ref, bytes, campaignId: 'c_srv');

        final serverService = BlobTransferService(
          channel: serverPort,
          store: serverStore,
          servableRefs: () => [ref],
        )..start();

        c1Port.sendBlobText('server', encodeBlobWant(ref.sha256Hex, [0, 1]));
        c2Port.sendBlobText('server', encodeBlobWant(ref.sha256Hex, [0, 1]));
        async.flushMicrotasks();

        expect(getCallCount, equals(1));

        serverService.dispose();
      });
    });

    test('F1a: second fetch joins while put is running: both owners recorded, releases work correctly', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore()..putDelay = const Duration(milliseconds: 50);
        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? res1;
        BlobFetchResult? res2;
        playerService.fetch(ref, campaignId: 'c1').then((r) => res1 = r);
        async.elapse(const Duration(milliseconds: 20));

        playerService.fetch(ref, campaignId: 'c2').then((r) => res2 = r);
        async.elapse(const Duration(milliseconds: 100));

        expect(res1, isA<BlobFetched>());
        expect(res2, isA<BlobFetched>());
        expect(playerStore.getOwners(ref.sha256Hex), equals({'c1', 'c2'}));

        // Release c1: blob is still there
        playerStore.releaseCampaign('c1');
        expect(playerStore.hasSync(ref.sha256Hex), isTrue);

        // Release c2: blob is gone
        playerStore.releaseCampaign('c2');
        expect(playerStore.hasSync(ref.sha256Hex), isFalse);

        dmProg.stop();
        playerService.dispose();
      });
    });

    test('F1b: third fetch joins while owner loop is recording second campaign: all three are owners', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore()
          ..putDelay = const Duration(milliseconds: 50)
          ..addOwnerDelay = const Duration(milliseconds: 50);

        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        BlobFetchResult? res1;
        BlobFetchResult? res2;
        BlobFetchResult? res3;

        // Fetch 1 starts at t=0
        playerService.fetch(ref, campaignId: 'c1').then((r) => res1 = r);
        async.elapse(const Duration(milliseconds: 20));

        // Fetch 2 joins while put is running (t=20ms)
        playerService.fetch(ref, campaignId: 'c2').then((r) => res2 = r);

        // Advance to t=60ms (put finished at t=50ms, owner loop started addOwner for c2)
        async.elapse(const Duration(milliseconds: 40));

        // Fetch 3 joins while addOwner for c2 is running (t=60ms)
        playerService.fetch(ref, campaignId: 'c3').then((r) => res3 = r);

        // Advance past all completions
        async.elapse(const Duration(milliseconds: 150));

        expect(res1, isA<BlobFetched>());
        expect(res2, isA<BlobFetched>());
        expect(res3, isA<BlobFetched>());
        expect(playerStore.getOwners(ref.sha256Hex), equals({'c1', 'c2', 'c3'}));

        dmProg.stop();
        playerService.dispose();
      });
    });

    test('F1c: fetch for c2 joins while put is running and put throws: both callers get error, no owner recorded', () {
      fakeAsync((async) {
        final net = FakeBlobNetwork();
        final dmPort = net.createChannel('dm');
        final playerPort = net.createChannel('player');
        net.openChannelBetween('dm', 'player');

        final bytes = _makeWebp(1000);
        final ref = _makeRef(bytes, BlobFormat.webp);

        final dmProg = ProgrammedServingPeer(
          peerId: 'dm',
          channel: dmPort,
          ref: ref,
          originalBytes: bytes,
          behavior: PeerBehavior.honest,
        )..start();

        final playerStore = FakeBlobStore()
          ..putDelay = const Duration(milliseconds: 50)
          ..throwOnPut = true;

        final playerService = BlobTransferService(
          channel: playerPort,
          store: playerStore,
          servableRefs: () => [],
        )..start();

        Object? err1;
        Object? err2;
        playerService.fetch(ref, campaignId: 'c1').catchError((e) {
          err1 = e;
          return const BlobFetched();
        });
        async.elapse(const Duration(milliseconds: 20));

        playerService.fetch(ref, campaignId: 'c2').catchError((e) {
          err2 = e;
          return const BlobFetched();
        });
        async.elapse(const Duration(milliseconds: 100));

        expect(err1, isNotNull);
        expect(err2, isNotNull);
        expect(playerStore.hasSync(ref.sha256Hex), isFalse);
        expect(playerStore.getOwners(ref.sha256Hex), isEmpty);

        dmProg.stop();
        playerService.dispose();
      });
    });
  });
}

class _CountingBlobStore extends FakeBlobStore {
  final void Function() onGet;
  _CountingBlobStore({required this.onGet});

  @override
  Future<StoredBlob> get(String sha256Hex) {
    onGet();
    return super.get(sha256Hex);
  }
}
