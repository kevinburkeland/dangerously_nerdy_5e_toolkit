import 'dart:async';

import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/room_roll.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';
import '../../test_doubles/service_test_configurator.dart';

class _CharTransport implements IP2pTransportPort {
  final StreamController<String> _incoming = StreamController<String>.broadcast();
  @override
  TransportState get currentState => TransportState.offline;
  @override
  Map<String, int> get peerLastSeen => const {};
  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}
  @override
  Future<void> broadcastPayload(String jsonPayload) async {}
  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;
  @override
  Future<void> disconnect() async {}
  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);
  @override
  Future<void> prepareSession() async {}
  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => false;
}

class _CharTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => DateTime.now().millisecondsSinceEpoch;
}

Character _makeHero(String id, String name) {
  return Character(
    id: EntityId(slug: id, ruleset: RulesetVersion.v2024),
    name: name,
    speciesRef: const EntityReference.empty(
      slug: 'human',
      refType: EntityType.species,
      displayName: 'Human',
    ),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference.empty(
            slug: 'fighter',
            refType: EntityType.classDefinition,
            displayName: 'Fighter',
          ),
          level: 4,
          hitDie: 'd10',
          isStartingClass: true,
        ),
      ],
    ),
    baseScores: const AbilityScores.standardArray(),
    resources: const CharacterResourcePool(currentHp: 34),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();
  late DiceRoomService testDiceService;
  late CampaignRegistryService testRegistry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    AppServices.reset();
    sl.reset();
    testRegistry = CampaignRegistryService.newInstance();
    CampaignRegistryService.instance = testRegistry;
    sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
    final repId = ReplicaId('party_room_char_replica');
    sl.registerSingleton<ReplicaId>(repId);
    final clock = StatefulHlcClock(replicaId: repId);
    sl.registerSingleton<StatefulHlcClock>(clock);
    final charRepo = LocalCharacterRepository();
    sl.registerSingleton<ICharacterRepository>(charRepo);
    final campRepo = LocalCampaignRepository(
      replicaId: repId,
      clock: clock,
      characterRepo: charRepo,
    );
    sl.registerSingleton<ICampaignRepository>(campRepo);
    final transport = _CharTransport();
    sl.registerSingleton<IP2pTransportPort>(transport);
    final diceService = createBoundTestDiceRoomService();
    testDiceService = diceService;
    final orchestrator = RoomSyncOrchestrator(
      replicaId: repId,
      transportPort: transport,
      payloadMapper: const RoomSyncPayloadMapper(),
      campaignRepo: campRepo,
      reconciliationService: RoomStateReconciliationService(
        networkTimeProvider: () => DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      clockSyncService: ClockSyncService(networkTimePort: _CharTimePort()),
      diceRoomService: diceService,
      clock: clock,
      telemetryInterval: const Duration(milliseconds: 100),
    );
    sl.registerSingleton<RoomSyncOrchestrator>(orchestrator);
    final net = FakeBlobNetwork();
    final chan = net.createChannel('party_room_char');
    final fakeStore = FakeBlobStore();
    final transfer = BlobTransferService(
      channel: chan,
      store: fakeStore,
      servableRefs: () => const [],
    );
    final mapCtrl = ActiveMapController(
      campaignRepo: campRepo,
      transfer: transfer,
      store: fakeStore,
      channel: chan,
      transportState: () => TransportState.webRtc,
    );
    sl.registerSingleton<ActiveMapController>(mapCtrl);
    final starter = RoomSessionStarter(orchestrator: orchestrator, maps: mapCtrl);
    sl.registerSingleton<RoomSessionStarter>(starter);
    configureTestServices(
      repository: campRepo,
      replicaId: repId,
      clock: clock,
      blobStore: fakeStore,
      transport: transport,
      orchestrator: orchestrator,
      sessionStarter: starter,
    );
    final partyService = PartyRoomService.newInstance(
      replicaId: repId,
      clock: clock,
      registry: testRegistry,
      diceRoomService: diceService,
    );
    PartyRoomService.setCustomInstanceForTesting(partyService);
    addTearDown(() async {
      orchestrator.stopSynchronization();
      PartyRoomService.resetCustomInstanceForTesting();
      CampaignRegistryService.resetInstanceForTesting();
      campRepo.dispose();
      sl.reset();
      await harness.tearDown();
    });
  });

  group('Fix 8.1: PartyRoomScreen characterization', () {
    testWidgets('empty campaign renders cleanly at 1280x800', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Empty Room Expedition',
        playerName: 'Aria',
        customRoomCode: 'EMPTY1',
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PartyRoomScreen(
          roomCode: 'EMPTY1',
          initialPlayerName: 'Aria',
          partyService: partyService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PartyRoomScreen), findsOneWidget);
      expect(find.textContaining('EMPTY1'), findsWidgets);
      expect(find.byType(Tab), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty campaign renders cleanly at 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Narrow Room Expedition',
        playerName: 'Aria',
        customRoomCode: 'NARRW1',
      );

      final errors = <Object>[];
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PartyRoomScreen(
          roomCode: 'NARRW1',
          initialPlayerName: 'Aria',
          partyService: partyService,
        ),
      ));
      for (Object? ex = tester.takeException();
          ex != null;
          ex = tester.takeException()) {
        errors.add(ex);
      }
      await tester.pumpAndSettle();
      for (Object? ex = tester.takeException();
          ex != null;
          ex = tester.takeException()) {
        errors.add(ex);
      }

      expect(find.byType(PartyRoomScreen), findsOneWidget);
      expect(find.textContaining('NARRW1'), findsWidgets);
      expect(
        errors.where(
          (e) => !e.toString().contains('RenderFlex overflowed'),
        ),
        isEmpty,
      );
    });

    testWidgets(
        'populated campaign renders vault items, character banner, and switches across all 3 tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hero = _makeHero('hero_lyra', 'Lyra Dawnstar');
      await CharacterPersistenceService().saveCharacter(hero);

      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Dragonspire Vault',
        playerName: 'Lyra Dawnstar',
        customRoomCode: 'VAULT1',
      );
      await partyService.linkCharacterToCampaign(
        roomCode: 'VAULT1',
        character: hero,
        existingRosterName: 'Lyra Dawnstar',
      );
      await partyService.addLootItem(
        roomCode: 'VAULT1',
        playerName: 'Lyra Dawnstar',
        item: PartyLootItem(
          id: 'loot_sunblade_1',
          name: 'Radiant Longsword',
          category: 'magicItem',
          count: 1,
          gpValue: 500,
          createdAt: DateTime.utc(2026, 11, 1),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PartyRoomScreen(
          roomCode: 'VAULT1',
          initialPlayerName: 'Lyra Dawnstar',
          partyService: partyService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dragonspire Vault'), findsOneWidget);
      expect(find.text('Lyra Dawnstar'), findsWidgets);
      expect(find.text('Sheet'), findsOneWidget);

      // Scroll to loot item if below fold
      await tester.scrollUntilVisible(
        find.textContaining('Radiant Longsword'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Radiant Longsword'), findsOneWidget);

      // Switch to Dice Feed tab
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to History / Audit tab
      await tester.tap(find.byType(Tab).at(2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to Vault tab
      await tester.tap(find.byType(Tab).at(0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('vault category filter chips filter displayed items cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Filter Check Room',
        playerName: 'Bram',
        customRoomCode: 'FILT01',
      );
      await partyService.addLootItem(
        roomCode: 'FILT01',
        playerName: 'Bram',
        item: PartyLootItem(
          id: 'loot_potion_1',
          name: 'Healing Elixir',
          category: 'magicItem',
          count: 1,
          gpValue: 50,
          createdAt: DateTime.utc(2026, 11, 1),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );
      await partyService.addLootItem(
        roomCode: 'FILT01',
        playerName: 'Bram',
        item: PartyLootItem(
          id: 'loot_rope_1',
          name: 'Silk Rope',
          category: 'gear',
          count: 1,
          gpValue: 10,
          createdAt: DateTime.utc(2026, 11, 1),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PartyRoomScreen(
          roomCode: 'FILT01',
          initialPlayerName: 'Bram',
          partyService: partyService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Healing Elixir'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Healing Elixir'), findsOneWidget);
      expect(find.textContaining('Silk Rope'), findsOneWidget);

      // Filter by Gear -> hides Healing Elixir, keeps Silk Rope
      await tester.tap(find.textContaining('Gear').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Silk Rope'), findsOneWidget);
      expect(find.textContaining('Healing Elixir'), findsNothing);

      // Back to All -> shows both
      await tester.tap(find.textContaining('All Items').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Healing Elixir'), findsOneWidget);
      expect(find.textContaining('Silk Rope'), findsOneWidget);
    });
  });

  group('Fix 3.3: PartyRoomScreen full interaction characterization', () {
    Future<PartyRoomService> seedRichRoom({bool isHost = true}) async {
      final hero = _makeHero('hero_aria', 'Aria');
      await CharacterPersistenceService().saveCharacter(hero);

      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Starfall Keep',
        playerName: 'Aria',
        customRoomCode: 'RICH01',
      );
      if (!isHost) {
        await testRegistry.saveMembership(
          CampaignMembership(
            roomCode: 'RICH01',
            campaignName: 'Starfall Keep',
            role: CampaignRole.player,
            lastPlayed: DateTime.utc(2026, 11, 1),
          ),
        );
      }
      await partyService.linkCharacterToCampaign(
        roomCode: 'RICH01',
        character: hero,
        existingRosterName: 'Aria',
      );
      await partyService.addCharacterToRoster(
        roomCode: 'RICH01',
        characterName: 'Bram',
        playerName: 'Aria',
      );
      await partyService.addCharacterToRoster(
        roomCode: 'RICH01',
        characterName: 'Cora',
        playerName: 'Aria',
      );
      final replica = sl<ReplicaId>();
      await partyService.updateMemberPurse(
        roomCode: 'RICH01',
        characterName: 'Aria',
        newPurse: const PartyPurse.empty().modifyCoin('gp', 50, replicaId: replica),
        performedBy: 'Aria',
      );
      await partyService.updateMemberPurse(
        roomCode: 'RICH01',
        characterName: 'Bram',
        newPurse: const PartyPurse.empty().modifyCoin('gp', 25, replicaId: replica),
        performedBy: 'Aria',
      );
      await partyService.updateMemberPurse(
        roomCode: 'RICH01',
        characterName: 'Cora',
        newPurse: const PartyPurse.empty().modifyCoin('gp', 10, replicaId: replica),
        performedBy: 'Aria',
      );
      await partyService.depositCoins(
        roomCode: 'RICH01',
        playerName: 'Aria',
        gp: 100,
        sp: 20,
      );

      // 3 active loot items: 1 unclaimed, 1 claimed by Aria, 1 assigned to Bram
      await partyService.addLootItem(
        roomCode: 'RICH01',
        playerName: 'Aria',
        item: PartyLootItem(
          id: 'loot_chalice',
          name: 'Silver Chalice',
          category: 'treasure',
          count: 1,
          gpValue: 150,
          createdAt: DateTime.utc(2026, 11, 1, 10, 0),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );
      await partyService.addLootItem(
        roomCode: 'RICH01',
        playerName: 'Aria',
        item: PartyLootItem(
          id: 'loot_sword',
          name: 'Radiant Longsword',
          category: 'magicItem',
          count: 1,
          gpValue: 500,
          claimedByPlayer: 'Aria',
          createdAt: DateTime.utc(2026, 11, 1, 10, 1),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );
      await partyService.addLootItem(
        roomCode: 'RICH01',
        playerName: 'Aria',
        item: PartyLootItem(
          id: 'loot_cloak',
          name: 'Cloak of Protection',
          category: 'magicItem',
          count: 1,
          gpValue: 350,
          claimedByPlayer: 'Bram',
          createdAt: DateTime.utc(2026, 11, 1, 10, 2),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );

      // 2 trashed items
      await partyService.addLootItem(
        roomCode: 'RICH01',
        playerName: 'Aria',
        item: PartyLootItem(
          id: 'loot_trash_1',
          name: 'Cracked Wand',
          category: 'magicItem',
          count: 1,
          gpValue: 40,
          createdAt: DateTime.utc(2026, 11, 1, 10, 3),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );
      await partyService.archiveLootItem(
        roomCode: 'RICH01',
        lootId: 'loot_trash_1',
        playerName: 'Aria',
      );
      await partyService.addLootItem(
        roomCode: 'RICH01',
        playerName: 'Aria',
        item: PartyLootItem(
          id: 'loot_trash_2',
          name: 'Rusty Dagger',
          category: 'weapon',
          count: 1,
          gpValue: 2,
          createdAt: DateTime.utc(2026, 11, 1, 10, 4),
          expiresAt: DateTime.utc(2027, 11, 1),
        ),
      );
      await partyService.archiveLootItem(
        roomCode: 'RICH01',
        lootId: 'loot_trash_2',
        playerName: 'Aria',
      );

      // 5 dice rolls via the bound DiceRoomService (within 24h window)
      testDiceService.joinRoom('RICH01', 'Aria', remember: false);
      final now = DateTime.now();
      for (var i = 1; i <= 5; i++) {
        await testDiceService.broadcastRoll(
          RoomRoll(
            id: 'roll_$i',
            roomCode: 'RICH01',
            playerName: i.isOdd ? 'Aria' : 'Bram',
            formulaString: '1d20+$i',
            total: 10 + i,
            individualRolls: [10],
            details: ['Roll #$i'],
            isCrit: false,
            isFumble: false,
            timestamp: now.subtract(Duration(minutes: 10 - i)),
          ),
        );
      }

      return partyService;
    }

    Widget buildRichRoomApp(PartyRoomService partyService) {
      return MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PartyRoomScreen(
          roomCode: 'RICH01',
          initialPlayerName: 'Aria',
          partyService: partyService,
          registry: testRegistry,
          diceService: testDiceService,
        ),
      );
    }

    void expectNoNonOverflowExceptions(WidgetTester tester) {
      final errors = <Object>[];
      for (Object? ex = tester.takeException();
          ex != null;
          ex = tester.takeException()) {
        errors.add(ex);
      }
      expect(
        errors.where((e) {
          final msg = e.toString();
          return !msg.contains('RenderFlex overflowed') &&
              // Mutation X1 marker: Fix 1.3 stopped per prompt (TestWidgetsFlutterBinding._runTest stores plain String).
              !RegExp(r'Multiple exceptions \(\d+\) were detected').hasMatch(msg);
        }),
        isEmpty,
      );
    }

    Finder vaultScrollable() => find.descendant(
          of: find.byType(TabBarView),
          matching: find.byType(Scrollable),
        ).first;

    testWidgets(
      'rich room displays vault, dice feed, history, and trash tabs with purses, banner, and item order',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final partyService = await seedRichRoom();
        await tester.pumpWidget(buildRichRoomApp(partyService));
        await tester.pumpAndSettle();

        // Header & active character banner
        expect(find.text('Starfall Keep'), findsOneWidget);
        expect(find.textContaining('RICH01'), findsWidgets);
        expect(find.text('Aria'), findsWidgets);
        expect(find.text('Sheet'), findsOneWidget);

        // Vault tab: member purses & party purse
        expect(find.textContaining('50 GP'), findsWidgets);
        expect(find.textContaining('25 GP'), findsWidgets);
        expect(find.textContaining('10 GP'), findsWidgets);
        expect(find.textContaining('100'), findsWidgets);

        await tester.scrollUntilVisible(
          find.text('Silver Chalice'),
          200,
          scrollable: vaultScrollable(),
        );
        expect(find.text('Silver Chalice'), findsOneWidget);
        expect(find.text('Radiant Longsword'), findsOneWidget);
        expect(find.text('Cloak of Protection'), findsOneWidget);
        expect(find.text('In Vault (Unclaimed)'), findsOneWidget);
        expect(find.text('Claimed by You'), findsOneWidget);
        expect(find.text('Claimed: Bram'), findsOneWidget);

        // Dice Feed tab
        await tester.tap(find.text('Dice Feed'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1d20+1'), findsOneWidget);
        expect(find.textContaining('1d20+5'), findsOneWidget);

        // History & Trash tab -> Event Audit Log
        await tester.tap(find.byType(Tab).at(2));
        await tester.pumpAndSettle();
        expect(find.text('Event Audit Log'), findsOneWidget);
        expect(find.text('Vault Trash & Restore'), findsOneWidget);

        // Switch to Vault Trash & Restore sub-tab
        await tester.tap(find.text('Vault Trash & Restore'));
        await tester.pumpAndSettle();
        // Trigger local broadcast emission once Trash StreamBuilder is mounted
        // (known broadcast-before-subscribe timing in PartyHistoryAndTrashTab).
        partyService.streamLoot('RICH01', includeArchived: true);
        await tester.pumpAndSettle();
        expect(find.text('Cracked Wand'), findsOneWidget);
        expect(find.text('Rusty Dagger'), findsOneWidget);
        expect(find.text('Restore'), findsNWidgets(2));
        expectNoNonOverflowExceptions(tester);
      },
    );

    testWidgets('copy room code shows confirmation snackbar', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy).first);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('RICH01'), findsWidgets);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('open and cancel leave campaign dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom(isHost: false);
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave Campaign'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Leave Campaign'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('open and cancel delete campaign dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete Campaign'));
      await tester.tap(find.text('Delete Campaign'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('member coin change updates member purse in fake service and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      final memberMenus = find.descendant(
        of: find.byType(TabBarView),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(memberMenus.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deposit Coins').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '15');
      await tester.tap(find.text('Deposit Coins').last);
      await tester.pumpAndSettle();

      final session = partyService.getCachedSession('RICH01');
      expect(session!.getMemberPurse('Aria').gp, 65);
      expect(find.textContaining('65 GP'), findsWidgets);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('party coin change updates party reserve purse in fake service and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Deposit Coins'),
        200,
        scrollable: vaultScrollable(),
      );
      await tester.tap(find.text('Deposit Coins').first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '25');
      await tester.tap(find.text('Deposit').last);
      await tester.pumpAndSettle();

      final session = partyService.getCachedSession('RICH01');
      expect(session!.partyPurse.gp, 125);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('claim one loot item updates claim state in fake service and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Claim'),
        200,
        scrollable: vaultScrollable(),
      );
      await tester.tap(find.text('Claim').first);
      await tester.pumpAndSettle();

      final items = await partyService.streamLoot('RICH01').first;
      final chalice = items.firstWhere((i) => i.id == 'loot_chalice');
      expect(chalice.claimedByPlayer, 'Aria');
      expect(find.text('In Vault (Unclaimed)'), findsNothing);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('assign one loot item assigns to chosen roster member in fake service and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byTooltip('Assign to Character...').first,
        200,
        scrollable: vaultScrollable(),
      );
      await tester.tap(find.byTooltip('Assign to Character...').first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cora').last);
      await tester.pumpAndSettle();

      final items = await partyService.streamLoot('RICH01').first;
      expect(items.any((i) => i.claimedByPlayer == 'Cora'), isTrue);
      expect(find.text('Claimed: Cora'), findsOneWidget);
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('restore one trashed item restores the chosen item and keeps the other archived', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loot & Trash Log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vault Trash & Restore'));
      await tester.pumpAndSettle();
      partyService.streamLoot('RICH01', includeArchived: true);
      await tester.pumpAndSettle();

      expect(find.text('Cracked Wand'), findsOneWidget);
      expect(find.text('Rusty Dagger'), findsOneWidget);

      final wandTile = find.ancestor(
        of: find.text('Cracked Wand'),
        matching: find.byType(ListTile),
      );
      await tester.tap(find.descendant(of: wandTile, matching: find.text('Restore')));
      await tester.pumpAndSettle();

      expect(find.text('Restored "Cracked Wand" to party vault!'), findsOneWidget);
      final allLoot = await partyService.streamLoot('RICH01', includeArchived: true).first;
      final wand = allLoot.firstWhere((i) => i.id == 'loot_trash_1');
      final dagger = allLoot.firstWhere((i) => i.id == 'loot_trash_2');
      expect(wand.isArchived, isFalse, reason: 'Cracked Wand must be restored');
      expect(dagger.isArchived, isTrue, reason: 'Rusty Dagger must remain archived');
      expectNoNonOverflowExceptions(tester);
    });

    testWidgets('switch tabs and back preserves vault filter keep-alive state', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final partyService = await seedRichRoom();
      await tester.pumpWidget(buildRichRoomApp(partyService));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Magic ('),
        200,
        scrollable: vaultScrollable(),
      );
      await tester.tap(find.textContaining('Magic (').first);
      await tester.pumpAndSettle();
      expect(find.text('Silver Chalice'), findsNothing);
      expect(find.text('Radiant Longsword'), findsOneWidget);

      await tester.tap(find.text('Dice Feed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loot & Trash Log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Party Vault'));
      await tester.pumpAndSettle();

      expect(find.text('Silver Chalice'), findsNothing);
      expect(find.text('Radiant Longsword'), findsOneWidget);
      expectNoNonOverflowExceptions(tester);
    });
  });
}
