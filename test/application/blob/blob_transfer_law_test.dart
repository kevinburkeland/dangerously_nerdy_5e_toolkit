import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_protocol.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';

Uint8List _generateLawFile(BlobFormat format, int size, Random rand) {
  final bytes = Uint8List(size);
  if (format == BlobFormat.webp) {
    // RIFF....WEBP
    bytes[0] = 0x52; // R
    bytes[1] = 0x49; // I
    bytes[2] = 0x46; // F
    bytes[3] = 0x46; // F
    bytes[8] = 0x57; // W
    bytes[9] = 0x45; // E
    bytes[10] = 0x42; // B
    bytes[11] = 0x50; // P
    for (var i = 12; i < size; i++) {
      bytes[i] = rand.nextInt(256);
    }
  } else {
    // FF D8 FF
    bytes[0] = 0xFF;
    bytes[1] = 0xD8;
    bytes[2] = 0xFF;
    for (var i = 3; i < size; i++) {
      bytes[i] = rand.nextInt(256);
    }
  }
  return bytes;
}

void main() {
  const stallTimeout = Duration(seconds: 1);

  group('BlobTransferService Law Test (300 seeds)', () {
    test('Control: flipped-byte-only gives corrupt, honest-only gives BlobFetched', () {
      fakeAsync((async) {
        // Control 1: only peer serves flipped byte => corrupt
        {
          final net = FakeBlobNetwork();
          final playerPort = net.createChannel('player');
          final p1Port = net.createChannel('p1');
          net.openChannelBetween('player', 'p1');

          final bytes = _generateLawFile(BlobFormat.webp, 1000, Random(42));
          final hash = sha256.convert(bytes).toString();
          final ref = BlobRef(
            sha256Hex: hash,
            byteSize: bytes.length,
            width: 100,
            height: 100,
            format: BlobFormat.webp,
          );

          final server = ProgrammedServingPeer(
            peerId: 'p1',
            channel: p1Port,
            ref: ref,
            originalBytes: bytes,
            behavior: PeerBehavior.servesFlippedByte,
          )..start();

          final store = FakeBlobStore();
          final service = BlobTransferService(
            channel: playerPort,
            store: store,
            servableRefs: () => [],
            stallTimeout: stallTimeout,
          )..start();

          BlobFetchResult? result;
          service.fetch(ref, campaignId: 'c1').then((r) => result = r);

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(result, isA<BlobFetchIncomplete>());
          expect((result as BlobFetchIncomplete).reason, equals(BlobIncompleteReason.corrupt));

          server.stop();
          service.dispose();
        }

        // Control 2: one honest peer => BlobFetched
        {
          final net = FakeBlobNetwork();
          final playerPort = net.createChannel('player');
          final p1Port = net.createChannel('p1');
          net.openChannelBetween('player', 'p1');

          final bytes = _generateLawFile(BlobFormat.jpeg, 1000, Random(43));
          final hash = sha256.convert(bytes).toString();
          final ref = BlobRef(
            sha256Hex: hash,
            byteSize: bytes.length,
            width: 100,
            height: 100,
            format: BlobFormat.jpeg,
          );

          final server = ProgrammedServingPeer(
            peerId: 'p1',
            channel: p1Port,
            ref: ref,
            originalBytes: bytes,
            behavior: PeerBehavior.honest,
          )..start();

          final store = FakeBlobStore();
          final service = BlobTransferService(
            channel: playerPort,
            store: store,
            servableRefs: () => [],
            stallTimeout: stallTimeout,
          )..start();

          BlobFetchResult? result;
          service.fetch(ref, campaignId: 'c1').then((r) => result = r);

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();

          expect(result, isA<BlobFetched>());
          expect(store.hasSync(ref.sha256Hex), isTrue);

          server.stop();
          service.dispose();
        }
      });
    });

    test('300 randomized seeds satisfy L1, L2, L3, L4', () {
      const fixedSizes = [12, 65535, 65536, 65537, 131072, 196615];
      const allBehaviors = PeerBehavior.values;

      for (var seed = 0; seed < 300; seed++) {
        final rand = Random(seed);

        final format = rand.nextBool() ? BlobFormat.webp : BlobFormat.jpeg;
        final int size;
        if (rand.nextInt(3) < 2) {
          size = fixedSizes[rand.nextInt(fixedSizes.length)];
        } else {
          size = 12 + rand.nextInt(600000 - 12 + 1);
        }

        final bytes = _generateLawFile(format, size, rand);
        final hash = sha256.convert(bytes).toString();
        final ref = BlobRef(
          sha256Hex: hash,
          byteSize: bytes.length,
          width: 100,
          height: 100,
          format: format,
        );

        final peerCount = 1 + rand.nextInt(4); // 1 to 4 peers
        final peerBehaviors = <String, PeerBehavior>{};

        try {
          fakeAsync((async) {
            final servers = <ProgrammedServingPeer>[];
            final net = FakeBlobNetwork();
            final playerPort = net.createChannel('player');

            var hasHonestPeer = false;
            for (var p = 0; p < peerCount; p++) {
              final peerId = 'peer_$p';
              final behavior = allBehaviors[rand.nextInt(allBehaviors.length)];
              peerBehaviors[peerId] = behavior;
              if (behavior == PeerBehavior.honest) {
                hasHonestPeer = true;
              }

              final peerPort = net.createChannel(peerId);
              net.openChannelBetween('player', peerId);

              final server = ProgrammedServingPeer(
                peerId: peerId,
                channel: peerPort,
                ref: ref,
                originalBytes: bytes,
                behavior: behavior,
                kParam: 1 + rand.nextInt(max(1, blobChunkCount(ref.byteSize))),
                random: Random(seed * 100 + p),
              )..start();
              servers.add(server);
            }

            final store = FakeBlobStore();
            final service = BlobTransferService(
              channel: playerPort,
              store: store,
              servableRefs: () => [],
              stallTimeout: stallTimeout,
            )..start();

            try {
              BlobFetchResult? result;
              Object? fetchError;
              service.fetch(ref, campaignId: 'c_$seed').then(
                (r) => result = r,
                onError: (e) => fetchError = e,
              );

              // L1: fetch always completes within stallTimeout * (peers + 1) * (peers + 1) of fake time
              final maxDuration = stallTimeout * (peerCount + 1) * (peerCount + 1);
              var elapsed = Duration.zero;
              const step = Duration(milliseconds: 100);

              while (result == null && fetchError == null && elapsed < maxDuration) {
                async.elapse(step);
                async.flushMicrotasks();
                elapsed += step;
              }

              // Verify L1
              if (result == null && fetchError == null) {
                fail('Seed $seed failed L1: Did not complete within $maxDuration. Behaviors: $peerBehaviors');
              }

              // Verify L2: BlobFetched => store holds original bytes. BlobFetchIncomplete => store doesn't hold.
              if (result is BlobFetched) {
                final stored = store.getSync(ref.sha256Hex);
                expect(
                  stored?.bytes,
                  equals(bytes),
                  reason: 'Seed $seed failed L2: Stored bytes mismatch. Behaviors: $peerBehaviors',
                );
              } else if (result is BlobFetchIncomplete) {
                expect(
                  store.hasSync(ref.sha256Hex),
                  isFalse,
                  reason: 'Seed $seed failed L2: Store holds hash despite Incomplete. Behaviors: $peerBehaviors',
                );
              }

              // Verify L3: every put attempt the fake store recorded carries exactly the original bytes.
              for (final attempt in store.putAttempts) {
                expect(
                  attempt.bytes,
                  equals(bytes),
                  reason: 'Seed $seed failed L3: Put attempt had corrupted bytes. Behaviors: $peerBehaviors',
                );
              }

              // Verify L4: if at least one honest peer stays connected the whole time, result is BlobFetched
              if (hasHonestPeer) {
                expect(
                  result,
                  isA<BlobFetched>(),
                  reason: 'Seed $seed failed L4: Had honest peer but got $result. Behaviors: $peerBehaviors',
                );
              }
            } finally {
              for (final s in servers) {
                s.stop();
              }
              service.dispose();
            }
          });
        } catch (e) {
          // ignore: avoid_print
          print('Failure at seed $seed with behaviors: $peerBehaviors');
          rethrow;
        }
      }
    });
  });
}
