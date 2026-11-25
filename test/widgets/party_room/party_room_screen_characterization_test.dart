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
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    AppServices.reset();
    sl.reset();
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
      diceRoomService: diceService,
    );
    PartyRoomService.setCustomInstanceForTesting(partyService);
    addTearDown(() async {
      orchestrator.stopSynchronization();
      PartyRoomService.resetCustomInstanceForTesting();
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
}
