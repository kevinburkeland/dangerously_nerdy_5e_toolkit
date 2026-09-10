import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart' show TransportState;
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/room_connection_badge.dart';

class _MockSyncTransport implements IP2pTransportPort {
  final StreamController<String> _incoming = StreamController<String>.broadcast();
  bool disconnected = false;

  @override
  TransportState currentState = TransportState.connecting;

  @override
  Map<String, int> peerLastSeen = const {};

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    disconnected = true;
    await _incoming.close();
  }
}

class _MockTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => DateTime.now().millisecondsSinceEpoch;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest(
    String roomCode,
    PartyRoomService partyService,
    CampaignRegistryService registry, {
    String? initialPlayerName,
    DiceRoomService? diceService,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: PartyRoomScreen(
        roomCode: roomCode,
        initialPlayerName: initialPlayerName ?? 'DM',
        partyService: partyService,
        registry: registry,
        diceService: diceService,
      ),
    );
  }

  group('PartyRoomScreen Widget Tests', () {
    late CampaignRegistryService registry;
    late PartyRoomService partyService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      registry = CampaignRegistryService.newInstance();
      partyService = PartyRoomService.newInstance(registry: registry);
    });

    testWidgets('Renders header, coin purse card, and tabs', (tester) async {
      const roomCode = 'ROOM-TEST01';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Chronicles of the Dragon',
        role: CampaignRole.host,
        hostKey: 'secret-key-1',
        characterId: 'DM Kevin',
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);

      await partyService.depositCoins(
        roomCode: roomCode,
        playerName: 'DM',
        gp: 250,
        pp: 5,
      );

      await tester.pumpWidget(createWidgetUnderTest(roomCode, partyService, registry));
      await tester.pumpAndSettle();

      expect(find.text('Chronicles of the Dragon'), findsOneWidget);
      expect(find.text(roomCode), findsOneWidget);
      expect(find.text('DM'), findsWidgets);

      expect(find.text('Party Coin Vault & Reserve'), findsOneWidget);
      expect(find.text('Deposit Coins'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Party Share Calculator'), findsOneWidget);

      // Verify coin counters
      expect(find.text('250'), findsOneWidget); // GP
      expect(find.text('5'), findsOneWidget);   // PP
    });

    testWidgets('Tapping Deposit Coins opens CoinTransactionDialog', (tester) async {
      const roomCode = 'ROOM-TEST02';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Test Campaign',
        role: CampaignRole.player,
        characterId: 'Legolas',
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);

      await tester.pumpWidget(createWidgetUnderTest(roomCode, partyService, registry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deposit Coins'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Add Gold (GP):'), findsOneWidget);
      expect(find.text('+10 GP'), findsOneWidget);
      expect(find.text('+100 GP'), findsOneWidget);
    });

    testWidgets('Displays vault loot items with Claim and Attunement actions', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const roomCode = 'ROOM-TEST03';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Item Test Campaign',
        role: CampaignRole.host,
        hostKey: 'test-key',
        characterId: 'DM',
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);

      final ring = PartyLootItem(
        id: 'ring_protection_1',
        name: 'Ring of Protection',
        category: 'magicItem',
        count: 1,
        gpValue: 3500.0,
        requiresAttunement: true,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await partyService.addLootItem(roomCode: roomCode, playerName: 'DM', item: ring);

      await tester.pumpWidget(createWidgetUnderTest(roomCode, partyService, registry));
      await tester.pumpAndSettle();

      expect(find.text('Ring of Protection'), findsOneWidget);
      expect(find.text('In Vault (Unclaimed)'), findsOneWidget);
      expect(find.text('Claim'), findsOneWidget);

      // Claim item
      await tester.ensureVisible(find.text('Claim'));
      await tester.tap(find.text('Claim'));
      await tester.pumpAndSettle();

      expect(find.text('Claimed by You'), findsOneWidget);
      expect(find.text('Attune'), findsOneWidget);
    });

    testWidgets('Switching tabs to Dice Feed and Audit Log', (tester) async {
      const roomCode = 'ROOM-TEST04';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Tab Test',
        role: CampaignRole.player,
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);

      await tester.pumpWidget(createWidgetUnderTest(roomCode, partyService, registry));
      await tester.pumpAndSettle();

      // Switch to Dice Feed tab
      await tester.tap(find.text('Dice Feed'));
      await tester.pumpAndSettle();

      expect(find.text('Open Dice Roller'), findsOneWidget);

      // Switch to Loot & Trash Log tab
      await tester.tap(find.text('Loot & Trash Log'));
      await tester.pumpAndSettle();

      expect(find.text('Event Audit Log'), findsOneWidget);
      expect(find.text('Vault Trash & Restore'), findsOneWidget);
    });

    testWidgets('Active Character Banner, Switch Dialog, and Roster Manager', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const roomCode = 'ROOM-ROSTER01';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Fellowship Campaign',
        role: CampaignRole.host,
        hostKey: 'host-secret',
        characterId: 'Gandalf',
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);

      await partyService.addCharacterToRoster(
        roomCode: roomCode,
        characterName: 'Gandalf',
        playerName: 'DM',
      );
      await partyService.addCharacterToRoster(
        roomCode: roomCode,
        characterName: 'Frodo (Rogue)',
        playerName: 'DM',
      );

      await tester.pumpWidget(createWidgetUnderTest(roomCode, partyService, registry, initialPlayerName: 'Gandalf'));
      await tester.pumpAndSettle();

      // Check Active Character Banner
      expect(find.text('ACTIVE CHARACTER / SESSION IDENTITY'), findsOneWidget);
      expect(find.text('Gandalf'), findsWidgets);
      expect(find.text('Frodo (Rogue)'), findsWidgets);

      // Tap Quick Roster Select chip for 'Frodo (Rogue)'
      await tester.tap(find.text('Frodo (Rogue)').first);
      await tester.pumpAndSettle();

      expect(find.text('Frodo (Rogue)'), findsWidgets);

      // Open Switch Dialog
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      expect(find.text('Select Active Character'), findsOneWidget);
      expect(find.text('Character / Player Name'), findsOneWidget);
      expect(find.text('Confirm Identity'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Open Party Roster Dialog via AppBar icon
      await tester.tap(find.byTooltip('Party Roster & Characters'));
      await tester.pumpAndSettle();

      expect(find.text('Party Character Roster'), findsOneWidget);
      expect(find.text('Add Character / Player'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    });

    testWidgets('PartyRoomScreen embeds RoomConnectionBadge and receives telemetry', (tester) async {
      const roomCode = 'ROOM-CONN01';
      final transport = _MockSyncTransport();
      final orchestrator = RoomSyncOrchestrator(
        transportPort: transport,
        campaignRepo: LocalCampaignRepository(),
        reconciliationService: RoomStateReconciliationService(),
        clockSyncService: ClockSyncService(networkTimePort: _MockTimePort()),
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: PartyRoomScreen(
          roomCode: roomCode,
          initialPlayerName: 'DM',
          partyService: partyService,
          registry: registry,
          orchestrator: orchestrator,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RoomConnectionBadge), findsOneWidget);
      expect(find.text('Connecting... (0)'), findsOneWidget);

      orchestrator.stopSynchronization();
    });

    testWidgets('Live dice feed immediately renders cached rolls and persists across tab switches', (tester) async {
      const roomCode = 'ROOM-FEED-TEST';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Dice Feed Campaign',
        role: CampaignRole.player,
        characterId: 'Aragorn',
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);

      final diceService = DiceRoomService.newInstance();
      final roll1 = RoomRoll(
        id: 'feed-roll-1',
        roomCode: roomCode,
        playerName: 'Legolas',
        timestamp: DateTime.now(),
        formulaString: '1d20 + 7',
        total: 24,
        individualRolls: [17],
        isCrit: false,
        isFumble: false,
      );
      diceService.ingestRemoteRoll(roll1);

      await tester.pumpWidget(createWidgetUnderTest(
        roomCode,
        partyService,
        registry,
        initialPlayerName: 'Aragorn',
        diceService: diceService,
      ));
      await tester.pumpAndSettle();

      // Switch to Dice Feed tab
      await tester.tap(find.text('Dice Feed'));
      await tester.pumpAndSettle();

      // Verify roll1 is immediately visible without visiting roll app
      expect(find.text('Legolas'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('No dice rolls logged yet for this room.\nRoll dice to broadcast in real time!'), findsNothing);

      // Switch to Party Vault tab (tab 0)
      await tester.tap(find.text('Party Vault'));
      await tester.pumpAndSettle();
      expect(find.text('Party Coin Vault & Reserve'), findsOneWidget);

      // Switch back to Dice Feed tab (tab 1)
      await tester.tap(find.text('Dice Feed'));
      await tester.pumpAndSettle();

      // Verify roll1 is STILL visible and did NOT disappear
      expect(find.text('Legolas'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);

      // Ingest a second roll in real-time
      final roll2 = RoomRoll(
        id: 'feed-roll-2',
        roomCode: roomCode,
        playerName: 'Gimli',
        timestamp: DateTime.now(),
        formulaString: '1d12 + 5',
        total: 16,
        individualRolls: [11],
        isCrit: false,
        isFumble: false,
      );
      diceService.ingestRemoteRoll(roll2);
      await tester.pumpAndSettle();

      // Both rolls should now be present in the live feed
      expect(find.text('Gimli'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('Legolas'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
    });
  });
}
