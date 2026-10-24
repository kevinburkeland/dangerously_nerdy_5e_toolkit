import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart'
    hide Character, EntityType, CharacterResourcePool;
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';

class _ThrowingSharedPrefsStore extends SharedPreferencesStorePlatform {
  final SharedPreferencesStorePlatform delegate;
  _ThrowingSharedPrefsStore(this.delegate);

  @override
  Future<bool> clear() => delegate.clear();

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();

  @override
  Future<bool> remove(String key) => delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    throw StateError('Simulated SharedPreferences setValue disk failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    sl.reset();
  });

  tearDown(() async {
    PartyRoomService.resetCustomInstanceForTesting();
    CampaignRegistryService.resetInstanceForTesting();
    sl.reset();
    await harness.tearDown();
  });

  Future<_TestContext> setupContext({required String replicaName}) async {
    final replica = ReplicaId(replicaName);
    final clock = StatefulHlcClock(replicaId: replica);
    final charRepo = LocalCharacterRepository();
    final campRepo = LocalCampaignRepository(
      replicaId: replica,
      clock: clock,
      characterRepo: charRepo,
    );
    final recordingPort = RecordingRoomDocumentPort();

    sl.registerSingleton<ReplicaId>(replica);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(campRepo);
    sl.registerSingleton<ICharacterRepository>(charRepo);
    sl.registerSingleton<IRoomDocumentPort>(recordingPort);

    final registry = CampaignRegistryService.newInstance();
    CampaignRegistryService.instance = registry;

    final diceService = DiceRoomService.newInstance();
    final partyService = PartyRoomService.newInstance(
      replicaId: replica,
      clock: clock,
      registry: registry,
      diceRoomService: diceService,
    );
    partyService.setFirebaseAvailableForTesting(true);
    PartyRoomService.setCustomInstanceForTesting(partyService);

    return _TestContext(
      replica: replica,
      clock: clock,
      charRepo: charRepo,
      campRepo: campRepo,
      recordingPort: recordingPort,
      registry: registry,
      partyService: partyService,
    );
  }

  CampaignProfile createProfile({
    required String id,
    required String roomCode,
    required StatefulHlcClock clock,
    required String name,
  }) {
    final ts = clock.nextTimestamp();
    return CampaignProfile.raw(
      id: id,
      nameRegister: CrdtLwwRegister<String>(value: name, timestamp: ts),
      edition: RulesetEdition.v2024,
      createdAt: DateTime.now().toUtc(),
      lastPlayedAt: DateTime.now().toUtc(),
      partyRoster: const CrdtOrSet.empty(),
      roomState: RoomNodeState(
        roomId: 'room_$roomCode',
        roomCode: roomCode,
        title: '$name Staging',
        titleTimestamp: ts,
        description: '',
        descriptionTimestamp: ts,
      ),
      partyPurse: const PartyPurse.empty(),
      memberPurses: const {},
      pinnedRules: const CrdtOrSet<String>.empty(),
      notesRegister: CrdtLwwRegister<String>(value: '', timestamp: ts),
      changeLog: const [],
    );
  }

  test('R1: Keyless DM removal removes membership and claiming profiles without online writes', () async {
    final ctx = await setupContext(replicaName: 'replica_r1');

    // 1. Set up keyless host membership ROOMX1
    final membership = CampaignMembership(
      roomCode: 'ROOMX1',
      campaignName: 'Room X1 Campaign',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    );
    await ctx.registry.saveMembership(membership);

    // Profile 1: campaign_ROOMX1
    final prof1 = createProfile(
      id: 'campaign_ROOMX1',
      roomCode: 'ROOMX1',
      clock: ctx.clock,
      name: 'Room X1 Profile 1',
    );
    await ctx.campRepo.putProfile(prof1);

    // Profile 2: id is different, but roomState.roomCode is roomx1
    final prof2 = createProfile(
      id: 'custom_profile_for_roomx1',
      roomCode: 'roomx1',
      clock: ctx.clock,
      name: 'Room X1 Profile 2',
    );
    await ctx.campRepo.putProfile(prof2);

    // Unrelated profile
    final unrelated = createProfile(
      id: 'campaign_UNRELATED',
      roomCode: 'UNRELATED',
      clock: ctx.clock,
      name: 'Unrelated Campaign',
    );
    await ctx.campRepo.putProfile(unrelated);

    // One saved character
    const testChar = Character(
      id: EntityId(slug: 'hero_r1', ruleset: RulesetVersion.v2024),
      name: 'Hero R1',
      speciesRef: EntityReference.empty(
        slug: 'human',
        refType: EntityType.species,
        displayName: 'Human',
      ),
      progression: CharacterProgression(classes: []),
      baseScores: AbilityScores.standardArray(),
      resources: CharacterResourcePool(currentHp: 20),
    );
    await ctx.charRepo.saveCharacter(testChar);

    // Cache a lobby in party service to verify it gets cleared
    ctx.partyService.cacheLobbyForTesting(
      PartyRoomLobby(
        roomCode: 'ROOMX1',
        campaignName: 'Room X1',
        hostKeyHash: 'some_hash',
        activePlayers: const [],
        partyTelemetry: const {},
        sharedCharacters: const {},
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    expect(ctx.partyService.getCachedLobby('ROOMX1'), isNotNull);

    // Remove from this device
    await ctx.partyService.removeCampaignFromThisDevice(roomCode: 'roomx1');

    // Assertions:
    // - Membership is gone
    expect(ctx.registry.getMembership('ROOMX1'), isNull);
    expect(ctx.registry.getMembership('roomx1'), isNull);

    // - Both claiming profiles are gone
    final allProfiles = await ctx.campRepo.loadAllProfiles();
    final profileIds = allProfiles.map((p) => p.id).toSet();
    expect(profileIds.contains('campaign_ROOMX1'), isFalse);
    expect(profileIds.contains('custom_profile_for_roomx1'), isFalse);

    // - Unrelated profile and character remain
    expect(profileIds.contains('campaign_UNRELATED'), isTrue);
    final characters = await ctx.charRepo.loadCharacters();
    expect(characters.any((c) => c.id.slug == 'hero_r1'), isTrue);

    // - Recording port saw zero calls of any kind
    expect(ctx.recordingPort.totalCalls, equals(0));

    // - getCachedLobby('ROOMX1') is null
    expect(ctx.partyService.getCachedLobby('ROOMX1'), isNull);
  });

  test('R2 (no come-back): Startup migration does not re-create profile after removal', () async {
    final ctx = await setupContext(replicaName: 'replica_r2');

    final membership = CampaignMembership(
      roomCode: 'ROOMX1',
      campaignName: 'Room X1 Campaign',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    );
    await ctx.registry.saveMembership(membership);

    final prof1 = createProfile(
      id: 'campaign_ROOMX1',
      roomCode: 'ROOMX1',
      clock: ctx.clock,
      name: 'Room X1 Campaign',
    );
    await ctx.campRepo.putProfile(prof1);

    // Remove from this device
    await ctx.partyService.removeCampaignFromThisDevice(roomCode: 'ROOMX1');

    // Run startup migration with the same storage
    await CampaignStorageMigration.runStartupMigration(
      repository: ctx.campRepo,
      registryService: ctx.registry,
      clock: ctx.clock,
    );

    // Verify no profile for ROOMX1 was re-created
    final profilesAfterMigration = await ctx.campRepo.loadAllProfiles();
    expect(
      profilesAfterMigration.any((p) => p.roomState.roomCode.toUpperCase() == 'ROOMX1'),
      isFalse,
    );
    expect(
      profilesAfterMigration.any((p) => p.id == 'campaign_ROOMX1'),
      isFalse,
    );

    // CONTROL: delete only the profile and keep the membership, migration DOES re-create it
    final controlMembership = CampaignMembership(
      roomCode: 'CONTROL99',
      campaignName: 'Control 99',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    );
    await ctx.registry.saveMembership(controlMembership);
    // Profile is absent. Run migration:
    await CampaignStorageMigration.runStartupMigration(
      repository: ctx.campRepo,
      registryService: ctx.registry,
      clock: ctx.clock,
    );
    final profilesAfterControl = await ctx.campRepo.loadAllProfiles();
    expect(
      profilesAfterControl.any((p) => p.roomState.roomCode.toUpperCase() == 'CONTROL99'),
      isTrue,
    );
  });

  test('R3 (fail closed): Membership write failure throws and leaves profile untouched', () async {
    final ctx = await setupContext(replicaName: 'replica_r3');

    final membership = CampaignMembership(
      roomCode: 'ROOMX1',
      campaignName: 'Room X1 Campaign',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    );
    await ctx.registry.saveMembership(membership);

    final prof1 = createProfile(
      id: 'campaign_ROOMX1',
      roomCode: 'ROOMX1',
      clock: ctx.clock,
      name: 'Room X1 Campaign',
    );
    await ctx.campRepo.putProfile(prof1);

    // Install throwing SharedPreferencesStorePlatform
    final currentStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _ThrowingSharedPrefsStore(currentStore);

    try {
      expect(
        () => ctx.partyService.removeCampaignFromThisDevice(roomCode: 'ROOMX1'),
        throwsA(isA<StateError>()),
      );

      // Verify profile is still there
      final loaded = await ctx.campRepo.getProfile('campaign_ROOMX1');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('campaign_ROOMX1'));
    } finally {
      SharedPreferencesStorePlatform.instance = currentStore;
    }
  });

  test('R4: Removing the only profile leaves exactly one fresh default profile', () async {
    final ctx = await setupContext(replicaName: 'replica_r4');

    final membership = CampaignMembership(
      roomCode: 'SOLO_ROOM',
      campaignName: 'Solo Campaign',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    );
    await ctx.registry.saveMembership(membership);

    final soloProf = createProfile(
      id: 'campaign_SOLO_ROOM',
      roomCode: 'SOLO_ROOM',
      clock: ctx.clock,
      name: 'Solo Campaign',
    );
    await ctx.campRepo.putProfile(soloProf);
    await ctx.campRepo.setActiveProfileId(soloProf.id);

    expect((await ctx.campRepo.loadAllProfiles()).length, equals(1));

    await ctx.partyService.removeCampaignFromThisDevice(roomCode: 'SOLO_ROOM');

    final profiles = await ctx.campRepo.loadAllProfiles();
    expect(profiles.length, equals(1));
    expect(profiles.first.id, isNot(equals('campaign_SOLO_ROOM')));
    expect(profiles.first.name, equals('My Campaign'));
  });

  testWidgets('R5 (widget): Landing screen menu shows "Remove from this device" only for keyless DM and removes membership on confirm', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ctx = await setupContext(replicaName: 'replica_r5');

    // 1. Keyless DM membership
    final keylessDm = CampaignMembership(
      roomCode: 'KEYLESS1',
      campaignName: 'Keyless DM Campaign',
      role: CampaignRole.host,
      hostKey: null,
      lastPlayed: DateTime.now(),
    );

    // 2. DM with passkey
    final keyedDm = CampaignMembership(
      roomCode: 'KEYED02',
      campaignName: 'Keyed DM Campaign',
      role: CampaignRole.host,
      hostKey: 'secret_host_key',
      lastPlayed: DateTime.now().subtract(const Duration(hours: 1)),
    );

    // 3. Player membership
    final player = CampaignMembership(
      roomCode: 'PLAYER03',
      campaignName: 'Player Campaign',
      role: CampaignRole.player,
      hostKey: null,
      lastPlayed: DateTime.now().subtract(const Duration(hours: 2)),
    );

    ctx.registry.membershipsNotifier.value = [keylessDm, keyedDm, player];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const LandingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 3 cards are rendered
    expect(find.text('KEYLESS1'), findsOneWidget);
    expect(find.text('KEYED02'), findsOneWidget);
    expect(find.text('PLAYER03'), findsOneWidget);

    // Find the campaign card PopupMenuButtons in the ListView
    final menuButtons = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(PopupMenuButton<String>),
    );
    expect(menuButtons, findsNWidgets(3));

    // Test 1: Keyless DM card menu (index 0)
    await tester.tap(menuButtons.at(0));
    await tester.pumpAndSettle();

    final removeLocalItem = find.text('Remove from this device');
    expect(removeLocalItem, findsOneWidget);

    // Tap "Remove from this device" in the menu
    await tester.tap(removeLocalItem);
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Remove "Keyless DM Campaign" (KEYLESS1) from this device?'), findsOneWidget);
    expect(find.text('This removes the campaign, its DM notes and party ledger from this device only. The online room and other devices are not changed. Without the DM passkey, this device cannot delete the online room.'), findsOneWidget);

    // Tap confirm button in dialog
    final confirmBtn = find.widgetWithText(ElevatedButton, 'Remove from this device');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify KEYLESS1 membership is removed
    expect(ctx.registry.getMembership('KEYLESS1'), isNull);

    // Test 2: Keyed DM card menu (was at index 1, now index 0 of remaining 2)
    final remainingMenusAfterFirstRemoval = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(PopupMenuButton<String>),
    );
    expect(remainingMenusAfterFirstRemoval, findsNWidgets(2));

    await tester.tap(remainingMenusAfterFirstRemoval.at(0)); // KEYED02
    await tester.pumpAndSettle();

    expect(find.text('Remove from this device'), findsNothing);
    expect(find.text('Delete Campaign'), findsOneWidget);
    // Dismiss menu
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // Test 3: Player card menu (index 1)
    await tester.tap(remainingMenusAfterFirstRemoval.at(1)); // PLAYER03
    await tester.pumpAndSettle();

    expect(find.text('Remove from this device'), findsNothing);
    expect(find.text('Leave Campaign'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  });
}

class _TestContext {
  final ReplicaId replica;
  final StatefulHlcClock clock;
  final LocalCharacterRepository charRepo;
  final LocalCampaignRepository campRepo;
  final RecordingRoomDocumentPort recordingPort;
  final CampaignRegistryService registry;
  final PartyRoomService partyService;

  _TestContext({
    required this.replica,
    required this.clock,
    required this.charRepo,
    required this.campRepo,
    required this.recordingPort,
    required this.registry,
    required this.partyService,
  });
}
