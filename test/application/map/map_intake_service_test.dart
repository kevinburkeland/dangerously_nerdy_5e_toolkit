import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_intake_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/fake_map_image_intake.dart';

Uint8List _makePngHeader(int width, int height) {
  final bd = ByteData(33);
  // PNG signature
  bd.setUint8(0, 0x89);
  bd.setUint8(1, 0x50);
  bd.setUint8(2, 0x4E);
  bd.setUint8(3, 0x47);
  bd.setUint8(4, 0x0D);
  bd.setUint8(5, 0x0A);
  bd.setUint8(6, 0x1A);
  bd.setUint8(7, 0x0A);
  // IHDR length 13
  bd.setUint32(8, 13);
  // IHDR
  bd.setUint8(12, 0x49);
  bd.setUint8(13, 0x48);
  bd.setUint8(14, 0x44);
  bd.setUint8(15, 0x52);
  // width, height
  bd.setUint32(16, width);
  bd.setUint32(20, height);
  // 8-bit truecolor with alpha, etc.
  bd.setUint8(24, 8);
  bd.setUint8(25, 6);
  bd.setUint8(26, 0);
  bd.setUint8(27, 0);
  bd.setUint8(28, 0);
  // CRC
  bd.setUint32(29, 0);
  return bd.buffer.asUint8List();
}

void main() {
  group('MapIntakeService', () {
    late FakeMapImageIntake intake;
    late FakeBlobStore store;
    late FakeCampaignRepository repo;
    late StatefulHlcClock clock;
    late MapIntakeService service;

    setUp(() {
      intake = FakeMapImageIntake();
      store = FakeBlobStore();
      const stamp = HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 0,
        nodeId: 'node-1',
      );
      final profile = CampaignProfile.raw(
        id: 'camp-1',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Camp 1',
          timestamp: stamp,
        ),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: stamp,
        ),
        activeMapRegister: const CrdtLwwRegister<BlobRef?>(
          value: null,
          timestamp: stamp,
        ),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: const RoomNodeState.empty(),
      );
      repo = FakeCampaignRepository(profile);
      clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      service = MapIntakeService(
        intake: intake,
        store: store,
        campaignRepo: repo,
        clock: clock,
      );
    });

    test('S1: valid source puts to store, updates register, reports scaledDown', () async {
      // 1. 6000 x 3000 -> scaledDown: true
      final source1 = FakeMapImageSource(bytes: _makePngHeader(6000, 3000));
      final res1 = await service.setMapFromSource(source1, campaignId: 'camp-1');
      expect(res1.scaledDown, isTrue);
      expect(res1.originalWidth, equals(6000));
      expect(res1.originalHeight, equals(3000));
      expect(store.putAttempts.length, equals(1));
      expect(store.putAttempts.first.campaignId, equals('camp-1'));
      final storedRef = repo.activeProfile!.activeMapRegister.value!;
      expect(storedRef.sha256Hex, equals(sha256.convert(store.putAttempts.first.bytes).toString().toLowerCase()));
      expect(res1.ref, equals(storedRef));

      // 2. 1000 x 800 -> scaledDown: false
      final source2 = FakeMapImageSource(bytes: _makePngHeader(1000, 800));
      final res2 = await service.setMapFromSource(source2, campaignId: 'camp-1');
      expect(res2.scaledDown, isFalse);
      expect(res2.originalWidth, equals(1000));
      expect(res2.originalHeight, equals(800));
      expect(store.putAttempts.length, equals(2));
    });

    test('S2: header rejections never call normalize, store nothing, leave register unchanged', () async {
      final initialRef = repo.activeProfile!.activeMapRegister.value;

      // fileTooLarge
      final bigSource = FakeMapImageSource(
        bytes: _makePngHeader(100, 100),
      );
      // Pretend byteSize is too large by custom MapImageSource
      final tooBigSource = _FakeSizedSource(bigSource, 209715201);
      expect(
        () => service.setMapFromSource(tooBigSource, campaignId: 'camp-1'),
        throwsA(isA<MapIntakeRejected>().having((e) => e.reason, 'reason', MapRejectReason.fileTooLarge)),
      );
      expect(intake.normalizeCalls, equals(0));
      expect(store.putAttempts, isEmpty);
      expect(repo.activeProfile!.activeMapRegister.value, equals(initialRef));

      // tooManyPixels
      final tooManyPx = FakeMapImageSource(bytes: _makePngHeader(8193, 100));
      expect(
        () => service.setMapFromSource(tooManyPx, campaignId: 'camp-1'),
        throwsA(isA<MapIntakeRejected>().having((e) => e.reason, 'reason', MapRejectReason.tooManyPixels)),
      );
      expect(intake.normalizeCalls, equals(0));

      // unsupportedFormat
      final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0, 0, 0]);
      final gifSource = FakeMapImageSource(bytes: gifBytes);
      expect(
        () => service.setMapFromSource(gifSource, campaignId: 'camp-1'),
        throwsA(isA<MapIntakeRejected>().having((e) => e.reason, 'reason', MapRejectReason.unsupportedFormat)),
      );
      expect(intake.normalizeCalls, equals(0));

      // unreadable
      final corruptBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
      final corruptSource = FakeMapImageSource(bytes: corruptBytes);
      expect(
        () => service.setMapFromSource(corruptSource, campaignId: 'camp-1'),
        throwsA(isA<MapIntakeRejected>().having((e) => e.reason, 'reason', MapRejectReason.unreadable)),
      );
      expect(intake.normalizeCalls, equals(0));
      expect(store.putAttempts, isEmpty);
      expect(repo.activeProfile!.activeMapRegister.value, equals(initialRef));
    });

    test('S3: put throws leaves register unchanged and error reaches caller', () async {
      final initialRef = repo.activeProfile!.activeMapRegister.value;
      store.throwOnPut = true;
      final source = FakeMapImageSource(bytes: _makePngHeader(100, 100));

      expect(
        () => service.setMapFromSource(source, campaignId: 'camp-1'),
        throwsA(isA<StateError>()),
      );
      expect(repo.activeProfile!.activeMapRegister.value, equals(initialRef));
    });

    test('S4: normalize returns wrong signature -> encoderMismatch, nothing stored', () async {
      final initialRef = repo.activeProfile!.activeMapRegister.value;
      final badBytes = Uint8List(20); // Not valid WebP RIFF...WEBP
      intake.nextNormalized = NormalizedMapImage(
        bytes: badBytes,
        width: 100,
        height: 100,
        format: BlobFormat.webp,
      );
      final source = FakeMapImageSource(bytes: _makePngHeader(100, 100));

      expect(
        () => service.setMapFromSource(source, campaignId: 'camp-1'),
        throwsA(isA<MapIntakeRejected>().having((e) => e.reason, 'reason', MapRejectReason.encoderMismatch)),
      );
      expect(store.putAttempts, isEmpty);
      expect(repo.activeProfile!.activeMapRegister.value, equals(initialRef));
    });

    test('S5: normalize returns 10 MiB + 1 bytes -> outputTooLarge, nothing stored', () async {
      final initialRef = repo.activeProfile!.activeMapRegister.value;
      final hugeBytes = Uint8List(BlobRef.maxByteSize + 1);
      hugeBytes[0] = 0x52; // R
      hugeBytes[1] = 0x49; // I
      hugeBytes[2] = 0x46; // F
      hugeBytes[3] = 0x46; // F
      hugeBytes[8] = 0x57; // W
      hugeBytes[9] = 0x45; // E
      hugeBytes[10] = 0x42; // B
      hugeBytes[11] = 0x50; // P
      intake.nextNormalized = NormalizedMapImage(
        bytes: hugeBytes,
        width: 100,
        height: 100,
        format: BlobFormat.webp,
      );
      final source = FakeMapImageSource(bytes: _makePngHeader(100, 100));

      expect(
        () => service.setMapFromSource(source, campaignId: 'camp-1'),
        throwsA(isA<MapIntakeRejected>().having((e) => e.reason, 'reason', MapRejectReason.outputTooLarge)),
      );
      expect(store.putAttempts, isEmpty);
      expect(repo.activeProfile!.activeMapRegister.value, equals(initialRef));
    });

    test('S6: clearMap sets register to null with newer timestamp, store untouched', () async {
      // First set a map
      final source = FakeMapImageSource(bytes: _makePngHeader(100, 100));
      await service.setMapFromSource(source, campaignId: 'camp-1');
      final firstTs = repo.activeProfile!.activeMapRegister.timestamp;
      expect(repo.activeProfile!.activeMapRegister.value, isNotNull);

      // Now clearMap
      await service.clearMap(campaignId: 'camp-1');
      expect(repo.activeProfile!.activeMapRegister.value, isNull);
      expect(repo.activeProfile!.activeMapRegister.timestamp.compareTo(firstTs), greaterThan(0));
      // store untouched: still only 1 put attempt
      expect(store.putAttempts.length, equals(1));
    });
  });
}

class _FakeSizedSource implements MapImageSource {
  final MapImageSource delegate;
  @override
  final int byteSize;

  _FakeSizedSource(this.delegate, this.byteSize);

  @override
  String get name => delegate.name;

  @override
  Future<Uint8List> readRange(int start, int end) => delegate.readRange(start, end);
}
