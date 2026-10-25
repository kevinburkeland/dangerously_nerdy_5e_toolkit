import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

import 'package:crypto/crypto.dart';
import '../test_doubles/fake_blob_store.dart';
import '../test_doubles/fake_map_image_intake.dart';
import '../test_doubles/fake_room_document_port.dart';
import '../test_doubles/hive_test_harness.dart';

class _ThrowingReleaseBlobStore extends FakeBlobStore {
  final Object errorToThrow;

  _ThrowingReleaseBlobStore([this.errorToThrow = 'disk I/O error']);

  @override
  Future<void> releaseCampaign(String campaignId) async {
    throw errorToThrow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  late ReplicaId replica;
  late StatefulHlcClock clock;
  late LocalCharacterRepository charRepo;
  late LocalCampaignRepository campRepo;
  late CampaignRegistryService registry;
  late PartyRoomService partyService;
  late FakeBlobStore fakeStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    sl.reset();

    replica = ReplicaId('release_test_replica');
    clock = StatefulHlcClock(replicaId: replica);
    charRepo = LocalCharacterRepository();
    campRepo = LocalCampaignRepository(
      replicaId: replica,
      clock: clock,
      characterRepo: charRepo,
    );
    fakeStore = FakeBlobStore();

    sl.registerSingleton<ReplicaId>(replica);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(campRepo);
    sl.registerSingleton<ICharacterRepository>(charRepo);
    sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
    sl.registerSingleton<BlobStorePort>(fakeStore);

    registry = CampaignRegistryService.newInstance();
    CampaignRegistryService.instance = registry;

    partyService = PartyRoomService.newInstance(
      replicaId: replica,
      clock: clock,
      registry: registry,
    );
    PartyRoomService.setCustomInstanceForTesting(partyService);
  });

  tearDown(() async {
    PartyRoomService.resetCustomInstanceForTesting();
    CampaignRegistryService.resetInstanceForTesting();
    campRepo.dispose();
    sl.reset();
    await harness.tearDown();
  });

  ({BlobRef ref, Uint8List bytes}) makeValidBlob() {
    final norm = FakeMapImageIntake.createValidWebpNormalized();
    final hash = sha256.convert(norm.bytes).toString();
    final ref = BlobRef(
      sha256Hex: hash,
      byteSize: norm.bytes.length,
      width: norm.width,
      height: norm.height,
      format: norm.format,
    );
    return (ref: ref, bytes: norm.bytes);
  }

  test('R1: Campaign A owns map M. removeCampaignFromThisDevice for A\'s room -> FakeBlobStore no longer has M', () async {
    const roomA = 'ROOM-A';
    const campA = 'campaign_$roomA';

    final blob = makeValidBlob();
    await fakeStore.put(blob.ref, blob.bytes, campaignId: campA);
    expect(await fakeStore.has(blob.ref.sha256Hex), isTrue);

    final profileA = CampaignProfile.defaultProfile(
      id: campA,
      name: 'Campaign A',
      nodeId: replica.value,
      clock: clock,
    ).copyWith(
      roomState: const RoomNodeState.empty().copyWith(roomCode: roomA),
    );
    await campRepo.putProfile(profileA);
    await registry.saveMembership(CampaignMembership(
      roomCode: roomA,
      campaignName: 'Campaign A',
      role: CampaignRole.host,
      lastPlayed: DateTime.now(),
    ));

    await partyService.removeCampaignFromThisDevice(roomCode: roomA);

    expect(await fakeStore.has(blob.ref.sha256Hex), isFalse);
    expect(await campRepo.getProfile(campA), isNull);
  });

  test('R2: Campaigns A and B both own M. Remove A -> M is still there. Remove B -> gone', () async {
    const roomA = 'ROOM-A';
    const campA = 'campaign_$roomA';
    const roomB = 'ROOM-B';
    const campB = 'campaign_$roomB';

    final blob = makeValidBlob();
    await fakeStore.put(blob.ref, blob.bytes, campaignId: campA);
    await fakeStore.addOwner(blob.ref.sha256Hex, campB);

    final profileA = CampaignProfile.defaultProfile(
      id: campA,
      name: 'Campaign A',
      nodeId: replica.value,
      clock: clock,
    ).copyWith(
      roomState: const RoomNodeState.empty().copyWith(roomCode: roomA),
    );
    final profileB = CampaignProfile.defaultProfile(
      id: campB,
      name: 'Campaign B',
      nodeId: replica.value,
      clock: clock,
    ).copyWith(
      roomState: const RoomNodeState.empty().copyWith(roomCode: roomB),
    );
    await campRepo.putProfile(profileA);
    await campRepo.putProfile(profileB);
    await registry.saveMembership(CampaignMembership(
      roomCode: roomA,
      campaignName: 'Campaign A',
      role: CampaignRole.host,
      lastPlayed: DateTime.now(),
    ));
    await registry.saveMembership(CampaignMembership(
      roomCode: roomB,
      campaignName: 'Campaign B',
      role: CampaignRole.host,
      lastPlayed: DateTime.now(),
    ));

    // Remove A
    await partyService.removeCampaignFromThisDevice(roomCode: roomA);
    expect(await fakeStore.has(blob.ref.sha256Hex), isTrue);

    // Remove B
    await partyService.removeCampaignFromThisDevice(roomCode: roomB);
    expect(await fakeStore.has(blob.ref.sha256Hex), isFalse);
  });

  test('R3: releaseCampaign throws -> the profile is deleted, MapFilesNotRemovedException reaches caller, and in-memory room state was still cleared', () async {
    const roomA = 'ROOM-THROW';
    const campA = 'campaign_$roomA';

    final throwingStore = _ThrowingReleaseBlobStore('simulated store release failure');
    sl.unregister<BlobStorePort>();
    sl.registerSingleton<BlobStorePort>(throwingStore);

    final profileA = CampaignProfile.defaultProfile(
      id: campA,
      name: 'Campaign Throw',
      nodeId: replica.value,
      clock: clock,
    ).copyWith(
      roomState: const RoomNodeState.empty().copyWith(roomCode: roomA),
    );
    await campRepo.putProfile(profileA);
    await registry.saveMembership(CampaignMembership(
      roomCode: roomA,
      campaignName: 'Campaign Throw',
      role: CampaignRole.host,
      lastPlayed: DateTime.now(),
    ));

    // Populate in-memory state
    await partyService.ensureRoomExists(roomCode: roomA, campaignName: 'Campaign Throw');
    expect(partyService.localRooms.containsKey(roomA), isTrue);

    await expectLater(
      () => partyService.removeCampaignFromThisDevice(roomCode: roomA),
      throwsA(isA<MapFilesNotRemovedException>().having(
        (e) => e.cause.toString(),
        'cause',
        contains('simulated store release failure'),
      )),
    );

    // Profile was still deleted
    expect(await campRepo.getProfile(campA), isNull);

    // In-memory room state was still cleared
    expect(partyService.localRooms.containsKey(roomA), isFalse);
  });

  testWidgets('R4: the "Removed. Map files on this device couldn\'t be deleted: ..." message appears when the exception is thrown', (tester) async {
    const roomCode = 'ROOM-WIDGET';
    const campId = 'campaign_$roomCode';

    final throwingStore = _ThrowingReleaseBlobStore('disk full');
    sl.unregister<BlobStorePort>();
    sl.registerSingleton<BlobStorePort>(throwingStore);

    final profile = CampaignProfile.defaultProfile(
      id: campId,
      name: 'Widget Test Campaign',
      nodeId: replica.value,
      clock: clock,
    );
    await campRepo.putProfile(profile);

    // Keyless DM membership allows "Remove from this device" in landing screen
    await registry.saveMembership(CampaignMembership(
      roomCode: roomCode,
      campaignName: 'Widget Test Campaign',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const LandingScreen(),
    ));
    await tester.pumpAndSettle();

    // Find the campaign card menu button
    final moreButton = find.byIcon(Icons.more_vert);
    expect(moreButton, findsWidgets);
    await tester.tap(moreButton.first);
    await tester.pumpAndSettle();

    // Select "Remove from this device"
    final removeOption = find.text('Remove from this device');
    expect(removeOption, findsWidgets);
    await tester.tap(removeOption.first);
    await tester.pumpAndSettle();

    // Confirm dialog
    final confirmButton = find.widgetWithText(ElevatedButton, 'Remove from this device');
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    // Expect the snackbar
    expect(
      find.text("Removed. Map files on this device couldn't be deleted: disk full"),
      findsOneWidget,
    );
  });
}
