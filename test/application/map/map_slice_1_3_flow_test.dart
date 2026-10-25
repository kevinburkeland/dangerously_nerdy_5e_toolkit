import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_protocol.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_image_intake_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_intake_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/fake_map_image_intake.dart';

Uint8List _makeWebp(int byteSize, {int seed = 0}) {
  final bytes = Uint8List(byteSize);
  bytes[0] = 0x52; bytes[1] = 0x49; bytes[2] = 0x46; bytes[3] = 0x46; // RIFF
  bytes[8] = 0x57; bytes[9] = 0x45; bytes[10] = 0x42; bytes[11] = 0x50; // WEBP
  for (var i = 12; i < byteSize; i++) {
    bytes[i] = (i * 31 + seed) % 256;
  }
  return bytes;
}

Uint8List _makePngHeader(int width, int height) {
  final bd = ByteData(33);
  bd.setUint8(0, 0x89);
  bd.setUint8(1, 0x50);
  bd.setUint8(2, 0x4E);
  bd.setUint8(3, 0x47);
  bd.setUint8(4, 0x0D);
  bd.setUint8(5, 0x0A);
  bd.setUint8(6, 0x1A);
  bd.setUint8(7, 0x0A);
  bd.setUint32(8, 13);
  bd.setUint8(12, 0x49);
  bd.setUint8(13, 0x48);
  bd.setUint8(14, 0x44);
  bd.setUint8(15, 0x52);
  bd.setUint32(16, width);
  bd.setUint32(20, height);
  bd.setUint8(24, 8);
  bd.setUint8(25, 6);
  return bd.buffer.asUint8List();
}

class TestDevice {
  final String peerId;
  final FakeBlobStore store;
  final FakeCampaignRepository repo;
  final FakeBlobChannelPort channel;
  final StatefulHlcClock clock;
  final BlobTransferService transfer;
  final ActiveMapController controller;
  final FakeMapImageIntake intake;
  final MapIntakeService intakeService;
  TransportState transportState = TransportState.webRtc;

  TestDevice({
    required this.peerId,
    required FakeBlobNetwork network,
    CampaignProfile? initialProfile,
  })  : store = FakeBlobStore(),
        repo = FakeCampaignRepository(initialProfile),
        channel = network.createChannel(peerId),
        clock = StatefulHlcClock(replicaId: ReplicaId(peerId)),
        intake = FakeMapImageIntake(),
        transfer = BlobTransferService(
          channel: network.createChannel('${peerId}_tmp'), // re-assigned below
          store: FakeBlobStore(), // re-assigned below
          servableRefs: () => const [],
        ),
        controller = ActiveMapController(
          campaignRepo: FakeCampaignRepository(),
          transfer: BlobTransferService(
            channel: network.createChannel('${peerId}_tmp2'),
            store: FakeBlobStore(),
            servableRefs: () => const [],
          ),
          store: FakeBlobStore(),
          channel: network.createChannel('${peerId}_tmp3'),
          transportState: () => TransportState.webRtc,
        ),
        intakeService = MapIntakeService(
          intake: FakeMapImageIntake(),
          store: FakeBlobStore(),
          campaignRepo: FakeCampaignRepository(),
          clock: StatefulHlcClock(replicaId: ReplicaId(peerId)),
        );

  static TestDevice create({
    required String peerId,
    required FakeBlobNetwork network,
    CampaignProfile? initialProfile,
  }) {
    final store = FakeBlobStore();
    final repo = FakeCampaignRepository(initialProfile);
    final channel = network.createChannel(peerId);
    final clock = StatefulHlcClock(replicaId: ReplicaId(peerId));
    final intake = FakeMapImageIntake();

    final transfer = BlobTransferService(
      channel: channel,
      store: store,
      servableRefs: () => activeMapServableRefs(repo),
    );

    late final TestDevice dev;
    final controller = ActiveMapController(
      campaignRepo: repo,
      transfer: transfer,
      store: store,
      channel: channel,
      transportState: () => dev.transportState,
    );

    final intakeService = MapIntakeService(
      intake: intake,
      store: store,
      campaignRepo: repo,
      clock: clock,
    );

    dev = TestDevice._(
      peerId: peerId,
      store: store,
      repo: repo,
      channel: channel,
      clock: clock,
      transfer: transfer,
      controller: controller,
      intake: intake,
      intakeService: intakeService,
    );
    return dev;
  }

  TestDevice._({
    required this.peerId,
    required this.store,
    required this.repo,
    required this.channel,
    required this.clock,
    required this.transfer,
    required this.controller,
    required this.intake,
    required this.intakeService,
  });

  void start() {
    controller.start();
  }

  void dispose() {
    controller.dispose();
    transfer.dispose();
  }
}

void _syncProfiles(TestDevice from, TestDevice to) {
  final fromProfile = from.repo.activeProfile;
  if (fromProfile == null) return;
  final toProfile = to.repo.activeProfile;
  final merged = toProfile == null ? fromProfile : CampaignProfile.join(toProfile, fromProfile);
  to.repo.putProfile(merged);
}

CampaignProfile _buildInitialProfile(String id, String dmNodeId) {
  final stamp = HybridLogicalClock(
    physicalTime: 1700000000000,
    logicalCounter: 0,
    nodeId: dmNodeId,
  );
  return CampaignProfile.raw(
    id: id,
    nameRegister: CrdtLwwRegister<String>(
      value: 'Campaign $id',
      timestamp: stamp,
    ),
    notesRegister: CrdtLwwRegister<String>(
      value: '',
      timestamp: stamp,
    ),
    activeMapRegister: CrdtLwwRegister<BlobRef?>(
      value: null,
      timestamp: stamp,
    ),
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    roomState: const RoomNodeState.empty(),
  );
}

void main() {
  group('Map Slice 1.3 Flow Tests (F1 - F5)', () {
    late FakeBlobNetwork network;
    late TestDevice dm;
    late TestDevice p1;
    late TestDevice p2;

    setUp(() {
      network = FakeBlobNetwork();
      final profile = _buildInitialProfile('camp-1', 'dm');
      dm = TestDevice.create(peerId: 'dm', network: network, initialProfile: profile);
      p1 = TestDevice.create(peerId: 'p1', network: network, initialProfile: profile);
      p2 = TestDevice.create(peerId: 'p2', network: network, initialProfile: profile);
    });

    tearDown(() {
      dm.dispose();
      p1.dispose();
      p2.dispose();
    });

    test('F1: DM sets map, P1 receives profile and ends MapReady with bytes identical to DM output', () {
      fakeAsync((async) {
        dm.start();
        p1.start();
        network.openChannelBetween('dm', 'p1');

        final outputBytes = _makeWebp(1024, seed: 1);
        dm.intake.nextNormalized = NormalizedMapImage(
          bytes: outputBytes,
          width: 800,
          height: 600,
          format: BlobFormat.webp,
        );

        final source = FakeMapImageSource(bytes: _makePngHeader(800, 600));
        dm.intakeService.setMapFromSource(source, campaignId: 'camp-1');
        async.flushMicrotasks();

        expect(dm.controller.current, isA<MapReady>());

        // Sync profile to P1
        _syncProfiles(dm, p1);
        async.flushMicrotasks();

        expect(p1.controller.current, equals(MapReady(
          (dm.controller.current as MapReady).ref,
          outputBytes,
        )));
      });
    });

    test('F2: Late joiner P2 connects only after DM left, gets profile from P1, served by P1', () {
      fakeAsync((async) {
        dm.start();
        p1.start();
        p2.start();

        network.openChannelBetween('dm', 'p1');

        final outputBytes = _makeWebp(1024, seed: 2);
        dm.intake.nextNormalized = NormalizedMapImage(
          bytes: outputBytes,
          width: 800,
          height: 600,
          format: BlobFormat.webp,
        );
        final source = FakeMapImageSource(bytes: _makePngHeader(800, 600));
        dm.intakeService.setMapFromSource(source, campaignId: 'camp-1');
        async.flushMicrotasks();

        _syncProfiles(dm, p1);
        async.flushMicrotasks();
        expect(p1.controller.current, isA<MapReady>());

        // DM leaves: channel between dm and p1 is closed.
        network.closeChannelBetween('dm', 'p1');
        async.flushMicrotasks();

        // P2 connects only to P1 (channel to DM NEVER opens)
        network.openChannelBetween('p1', 'p2');
        _syncProfiles(p1, p2);
        async.flushMicrotasks();

        expect(p2.controller.current, equals(MapReady(
          (p1.controller.current as MapReady).ref,
          outputBytes,
        )));
      });
    });

    test('F3: DM sets map B: P1 and P2 end on B. DM clears: both end MapNone', () {
      fakeAsync((async) {
        dm.start();
        p1.start();
        p2.start();
        network.openChannelBetween('dm', 'p1');
        network.openChannelBetween('dm', 'p2');
        network.openChannelBetween('p1', 'p2');

        // Initial map A
        final bytesA = _makeWebp(1000, seed: 10);
        dm.intake.nextNormalized = NormalizedMapImage(
          bytes: bytesA,
          width: 500,
          height: 500,
          format: BlobFormat.webp,
        );
        dm.intakeService.setMapFromSource(FakeMapImageSource(bytes: _makePngHeader(500, 500)), campaignId: 'camp-1');
        async.flushMicrotasks();
        _syncProfiles(dm, p1);
        _syncProfiles(dm, p2);
        async.flushMicrotasks();

        expect(p1.controller.current, isA<MapReady>());
        expect(p2.controller.current, isA<MapReady>());

        // DM sets map B
        final bytesB = _makeWebp(1200, seed: 20);
        dm.intake.nextNormalized = NormalizedMapImage(
          bytes: bytesB,
          width: 600,
          height: 600,
          format: BlobFormat.webp,
        );
        dm.intakeService.setMapFromSource(FakeMapImageSource(bytes: _makePngHeader(600, 600)), campaignId: 'camp-1');
        async.flushMicrotasks();
        _syncProfiles(dm, p1);
        _syncProfiles(dm, p2);
        async.flushMicrotasks();

        final mapBRef = (dm.controller.current as MapReady).ref;
        expect((p1.controller.current as MapReady).ref, equals(mapBRef));
        expect((p2.controller.current as MapReady).ref, equals(mapBRef));

        // DM clears map
        dm.intakeService.clearMap(campaignId: 'camp-1');
        async.flushMicrotasks();
        _syncProfiles(dm, p1);
        _syncProfiles(dm, p2);
        async.flushMicrotasks();

        expect(p1.controller.current, equals(const MapNone()));
        expect(p2.controller.current, equals(const MapNone()));
      });
    });

    test('F4: Serving rule: P1 has second profile whose active map M2 is stored on P1; want for M2 or old map answers none', () {
      fakeAsync((async) {
        dm.start();
        p1.start();
        p2.start();
        network.openChannelBetween('p1', 'p2');

        // P1 has active profile 'camp-1' with map M1
        final bytesM1 = _makeWebp(500, seed: 1);
        final refM1 = BlobRef(
          sha256Hex: sha256.convert(bytesM1).toString().toLowerCase(),
          byteSize: bytesM1.length,
          width: 100,
          height: 100,
          format: BlobFormat.webp,
        );
        p1.store.put(refM1, bytesM1, campaignId: 'camp-1');
        p1.repo.updateProfile('camp-1', (c) => c.copyWith(
          activeMapRegister: CrdtLwwRegister<BlobRef?>(
            value: refM1,
            timestamp: p1.clock.nextTimestamp(),
          ),
        ));

        // P1 has a second local profile 'camp-2' whose active map M2 is stored on P1
        final bytesM2 = _makeWebp(600, seed: 2);
        final refM2 = BlobRef(
          sha256Hex: sha256.convert(bytesM2).toString().toLowerCase(),
          byteSize: bytesM2.length,
          width: 100,
          height: 100,
          format: BlobFormat.webp,
        );
        p1.store.put(refM2, bytesM2, campaignId: 'camp-2');
        final profile2 = _buildInitialProfile('camp-2', 'p1').copyWith(
          activeMapRegister: CrdtLwwRegister<BlobRef?>(
            value: refM2,
            timestamp: p1.clock.nextTimestamp(),
          ),
        );
        p1.repo.profiles['camp-2'] = profile2;

        // Also an old map Mold stored under camp-1
        final bytesOld = _makeWebp(700, seed: 3);
        final refOld = BlobRef(
          sha256Hex: sha256.convert(bytesOld).toString().toLowerCase(),
          byteSize: bytesOld.length,
          width: 100,
          height: 100,
          format: BlobFormat.webp,
        );
        p1.store.put(refOld, bytesOld, campaignId: 'camp-1');

        p1.start();
        async.flushMicrotasks();

        // P2 asks P1 for M2
        p2.channel.sendBlobText('p1', encodeBlobWant(refM2.sha256Hex, [0]));
        async.flushMicrotasks();

        // P1 must have sent 'none' for M2
        final noneM2Messages = network.sentMessages.where(
          (m) => m.sender == 'p1' && m.recipient == 'p2' && m.isText && m.text!.contains('"t":"none"') && m.text!.contains(refM2.sha256Hex),
        );
        expect(noneM2Messages, isNotEmpty);

        // P2 asks P1 for Mold
        p2.channel.sendBlobText('p1', encodeBlobWant(refOld.sha256Hex, [0]));
        async.flushMicrotasks();

        // P1 must have sent 'none' for Mold
        final noneOldMessages = network.sentMessages.where(
          (m) => m.sender == 'p1' && m.recipient == 'p2' && m.isText && m.text!.contains('"t":"none"') && m.text!.contains(refOld.sha256Hex),
        );
        expect(noneOldMessages, isNotEmpty);
      });
    });

    test('F5: P1 on relay shows MapRelayOnly; when direct channel to DM opens, P1 ends MapReady', () {
      fakeAsync((async) {
        dm.start();
        p1.start();

        // P1 transport is fallbackRelay, no open blob peers
        p1.transportState = TransportState.fallbackRelay;

        final bytes = _makeWebp(800, seed: 50);
        dm.intake.nextNormalized = NormalizedMapImage(
          bytes: bytes,
          width: 400,
          height: 400,
          format: BlobFormat.webp,
        );
        dm.intakeService.setMapFromSource(FakeMapImageSource(bytes: _makePngHeader(400, 400)), campaignId: 'camp-1');
        async.flushMicrotasks();

        _syncProfiles(dm, p1);
        async.flushMicrotasks();

        // P1 has no direct peers and is on fallbackRelay -> MapRelayOnly
        expect(p1.controller.current, equals(const MapRelayOnly()));

        // Now direct WebRTC channel opens between DM and P1
        network.openChannelBetween('dm', 'p1');
        async.flushMicrotasks();

        expect(p1.controller.current, equals(MapReady(
          (dm.controller.current as MapReady).ref,
          bytes,
        )));
      });
    });
  });
}
