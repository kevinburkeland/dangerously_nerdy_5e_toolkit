import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest(
    String roomCode,
    PartyRoomService partyService,
    CampaignRegistryService registry, {
    String? initialPlayerName,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: PartyRoomScreen(
        roomCode: roomCode,
        initialPlayerName: initialPlayerName ?? 'DM',
        partyService: partyService,
        registry: registry,
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
        campaignName: 'Dragonlance Chronicles',
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

      expect(find.text('Dragonlance Chronicles'), findsOneWidget);
      expect(find.text(roomCode), findsOneWidget);
      expect(find.text('DM'), findsOneWidget);

      expect(find.text('Party Coin Vault'), findsOneWidget);
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
  });
}
