// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _LawFakeStore extends FakeBlobStore {
  bool isPutActive = false;
  bool isOwnerLoopActive = false;

  @override
  Future<void> put(
    BlobRef ref,
    Uint8List bytes, {
    required String campaignId,
  }) async {
    isPutActive = true;
    try {
      await super.put(ref, bytes, campaignId: campaignId);
    } finally {
      isPutActive = false;
    }
  }

  @override
  Future<bool> addOwner(String sha256Hex, String campaignId) async {
    isOwnerLoopActive = true;
    try {
      return await super.addOwner(sha256Hex, campaignId);
    } finally {
      isOwnerLoopActive = false;
    }
  }
}

void main() {
  test('Blob owner law test (300 seeds, VM only)', () {
    var seedsWithCallDuringPut = 0;
    var seedsWithCallDuringOwnerLoop = 0;

    for (var seed = 0; seed < 300; seed++) {
      fakeAsync((async) {
        final rng = Random(seed);

        final isWebp = rng.nextBool();
        final byteSize = 1000 + rng.nextInt(30000); // 1 to 2 chunks
        final bytes = isWebp ? _makeWebp(byteSize) : _makeJpeg(byteSize);
        final ref = _makeRef(bytes, isWebp ? BlobFormat.webp : BlobFormat.jpeg);

        final net = FakeBlobNetwork();
        final playerPort = net.createChannel('player');

        final numPeers = rng.nextInt(2) + 1; // 1 or 2
        final servingPeers = <ProgrammedServingPeer>[];
        for (var p = 0; p < numPeers; p++) {
          final peerId = 'peer_$p';
          final peerPort = net.createChannel(peerId);
          net.openChannelBetween(peerId, 'player');

          final prog = ProgrammedServingPeer(
            peerId: peerId,
            channel: peerPort,
            ref: ref,
            originalBytes: bytes,
            behavior: PeerBehavior.honest,
          )..start();
          servingPeers.add(prog);
        }

        final putDelayMs = (seed % 6 == 0) ? 0 : 20 + rng.nextInt(60);
        final addOwnerDelayMs = (seed % 7 == 0) ? 0 : 15 + rng.nextInt(45);

        final store = _LawFakeStore()
          ..putDelay = Duration(milliseconds: putDelayMs)
          ..addOwnerDelay = Duration(milliseconds: addOwnerDelayMs);

        final playerService = BlobTransferService(
          channel: playerPort,
          store: store,
          servableRefs: () => [],
        )..start();

        final numCampaigns = rng.nextInt(4) + 2; // 2 to 5
        final campaigns = List.generate(numCampaigns, (i) => 'c_$i');

        // Target phases:
        // C0 starts at t=0 (initiates download)
        // If putDelayMs > 0, C1 calls during put
        // If addOwnerDelayMs > 0, C2 calls during owner loop
        // Others call before, during, or after
        final callTimes = <String, List<int>>{};
        var hadCallDuringPut = false;
        var hadCallDuringOwnerLoop = false;

        final results = <String, List<BlobFetchResult>>{};
        final activeFutures = <Future<void>>[];

        void scheduleCall(String campaignId, int delayMs) {
          callTimes.putIfAbsent(campaignId, () => []).add(delayMs);
          Timer(Duration(milliseconds: delayMs), () {
            if (store.isPutActive) {
              hadCallDuringPut = true;
            }
            if (store.isOwnerLoopActive) {
              hadCallDuringOwnerLoop = true;
            }
            final f = playerService.fetch(ref, campaignId: campaignId).then((res) {
              results.putIfAbsent(campaignId, () => []).add(res);
            });
            activeFutures.add(f);
          });
        }

        // C0 initiates at t=0
        scheduleCall(campaigns[0], 0);

        // Put starts virtually at t=0 (since peer is local fake network without artificial frame delay)
        // Put runs from t=0 to t=putDelayMs.
        if (numCampaigns >= 2) {
          if (putDelayMs > 5) {
            final callDuringPut = rng.nextInt(putDelayMs - 4) + 2;
            scheduleCall(campaigns[1], callDuringPut);
          } else {
            scheduleCall(campaigns[1], rng.nextInt(20));
          }
        }

        // Owner loop starts after put commits (t=putDelayMs) and runs while addOwner is processing
        final ownerLoopStart = putDelayMs;
        if (numCampaigns >= 3) {
          if (addOwnerDelayMs > 5) {
            final callDuringOwner = ownerLoopStart + rng.nextInt(addOwnerDelayMs - 4) + 2;
            scheduleCall(campaigns[2], callDuringOwner);
          } else {
            scheduleCall(campaigns[2], ownerLoopStart + rng.nextInt(20));
          }
        }

        // Remaining campaigns call either during owner loop, after, or duplicate
        for (var i = 3; i < numCampaigns; i++) {
          final afterDownload = ownerLoopStart + (addOwnerDelayMs * 3) + 30 + rng.nextInt(50);
          scheduleCall(campaigns[i], afterDownload);
        }

        // Some seeds call fetch twice for the same campaign
        if (rng.nextBool()) {
          final dupCampaign = campaigns[rng.nextInt(numCampaigns)];
          final dupTime = rng.nextInt(ownerLoopStart + addOwnerDelayMs + 50);
          scheduleCall(dupCampaign, dupTime);
        }

        // Advance fake time until all timers and futures complete
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        if (hadCallDuringPut) seedsWithCallDuringPut++;
        if (hadCallDuringOwnerLoop) seedsWithCallDuringOwnerLoop++;

        final owners = store.getOwners(ref.sha256Hex);

        try {
          // L7: no fetch call is left unfinished
          for (final c in campaigns) {
            final expectedCount = callTimes[c]?.length ?? 0;
            final actualCount = results[c]?.length ?? 0;
            expect(actualCount, equals(expectedCount),
                reason: 'Seed $seed: L7 failed for campaign $c (unfinished fetch)');
          }

          // L5: every campaign whose fetch returned BlobFetched is an owner of the hash
          final fetchedCampaigns = <String>{};
          for (final entry in results.entries) {
            for (final res in entry.value) {
              if (res is BlobFetched) {
                fetchedCampaigns.add(entry.key);
                expect(owners, contains(entry.key),
                    reason: 'Seed $seed: L5 failed for campaign ${entry.key}');
              }
            }
          }

          // L6: releasing every campaign except one that got BlobFetched leaves blob stored; releasing last removes it
          if (fetchedCampaigns.isNotEmpty) {
            final list = fetchedCampaigns.toList();
            for (var i = 0; i < list.length - 1; i++) {
              store.releaseCampaign(list[i]);
              expect(store.hasSync(ref.sha256Hex), isTrue,
                  reason: 'Seed $seed: L6 failed while releasing ${list[i]}');
            }
            store.releaseCampaign(list.last);
            expect(store.hasSync(ref.sha256Hex), isFalse,
                reason: 'Seed $seed: L6 failed on final release of ${list.last}');
          }
        } catch (_) {
          // On failure, print the seed, the call times and the owners
          print('FAILURE at seed: $seed');
          print('Call times: $callTimes');
          print('Owners: $owners');
          rethrow;
        }

        for (final prog in servingPeers) {
          prog.stop();
        }
        playerService.dispose();
      });
    }

    print('Coverage control: seeds with call during put: $seedsWithCallDuringPut, seeds with call during owner loop: $seedsWithCallDuringOwnerLoop');
    expect(seedsWithCallDuringPut, greaterThanOrEqualTo(30),
        reason: 'Coverage control: seeds with call during put must be at least 30');
    expect(seedsWithCallDuringOwnerLoop, greaterThanOrEqualTo(30),
        reason: 'Coverage control: seeds with call during owner loop must be at least 30');
  });
}
