import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/party/campaign_dialogs.dart';

import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';
import '../../test_doubles/service_test_configurator.dart';

class _SpyPartyRoomService extends PartyRoomService {
  final List<String> calls = <String>[];
  final Map<String, Object?> lastArgs = <String, Object?>{};
  final Map<String, PartySessionState> sessionsByCode =
      <String, PartySessionState>{};

  _SpyPartyRoomService({
    required super.replicaId,
    required super.clock,
    required super.registry,
    required super.diceRoomService,
  }) : super.newInstance();

  @override
  PartySessionState? getCachedSession(String roomCode) =>
      sessionsByCode[roomCode.toUpperCase()];

  @override
  Stream<PartySessionState?> streamSession(String roomCode) =>
      Stream<PartySessionState?>.value(sessionsByCode[roomCode.toUpperCase()]);

  @override
  Future<PartySessionState> createCampaign({
    required String campaignName,
    required String playerName,
    String? customRoomCode,
    String? linkProfileId,
  }) async {
    calls.add('createCampaign');
    lastArgs['createCampaign'] = {
      'campaignName': campaignName,
      'playerName': playerName,
      'linkProfileId': linkProfileId,
    };
    return PartySessionState(
      roomCode: 'ROOM-NEW111',
      campaignName: campaignName,
      hostKeyHash: 'hash',
      activePlayers: [playerName],
      characterRoster: const [],
      lastUpdated: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 2, 1),
    );
  }

  @override
  Future<PartySessionState> joinCampaign({
    required String roomCode,
    required String playerName,
    String? hostKey,
    String? characterId,
    Character? characterSnapshot,
    String? existingRosterName,
    bool isNewImport = true,
    Map<String, dynamic>? rawDoc,
  }) async {
    calls.add('joinCampaign');
    lastArgs['joinCampaign'] = {
      'roomCode': roomCode,
      'playerName': playerName,
      'hostKey': hostKey,
      'characterId': characterId,
      'existingRosterName': existingRosterName,
      'isNewImport': isNewImport,
    };
    return PartySessionState(
      roomCode: roomCode,
      campaignName: 'Joined Campaign',
      hostKeyHash: 'hash',
      activePlayers: [playerName],
      characterRoster: const ['Aldric', 'Lyra', 'Kael'],
      lastUpdated: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 2, 1),
    );
  }

  @override
  Future<CampaignMembership> claimDmRole({
    required String roomCode,
    required String hostKeyOrPasskey,
    CampaignRole targetRole = CampaignRole.host,
    String? playerName,
  }) async {
    calls.add('claimDmRole');
    lastArgs['claimDmRole'] = {
      'roomCode': roomCode,
      'hostKeyOrPasskey': hostKeyOrPasskey,
      'playerName': playerName,
      'targetRole': targetRole,
    };
    return CampaignMembership(
      roomCode: roomCode,
      campaignName: 'Claimed Campaign',
      role: targetRole,
      hostKey: hostKeyOrPasskey,
      lastPlayed: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<void> addLootItem({
    required String roomCode,
    required String playerName,
    required PartyLootItem item,
  }) async {
    calls.add('addLootItem');
    lastArgs['addLootItem'] = {
      'roomCode': roomCode,
      'playerName': playerName,
      'item': item,
    };
  }

  @override
  Future<void> depositCoins({
    required String roomCode,
    required String playerName,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String? note,
  }) async {
    calls.add('depositCoins');
    lastArgs['depositCoins'] = {
      'roomCode': roomCode,
      'playerName': playerName,
      'cp': cp,
      'sp': sp,
      'ep': ep,
      'gp': gp,
      'pp': pp,
      'note': note,
    };
  }

  @override
  Future<void> withdrawCoins({
    required String roomCode,
    required String playerName,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String? note,
  }) async {
    calls.add('withdrawCoins');
    lastArgs['withdrawCoins'] = {
      'roomCode': roomCode,
      'playerName': playerName,
      'cp': cp,
      'sp': sp,
      'ep': ep,
      'gp': gp,
      'pp': pp,
      'note': note,
    };
  }

  @override
  Future<void> setActiveCharacter({
    required String roomCode,
    required String characterName,
    bool updateRegistryDefault = true,
  }) async {
    calls.add('setActiveCharacter');
    lastArgs['setActiveCharacter'] = {
      'roomCode': roomCode,
      'characterName': characterName,
    };
  }

  @override
  Future<void> addCharacterToRoster({
    required String roomCode,
    required String characterName,
    required String playerName,
  }) async {
    calls.add('addCharacterToRoster');
    lastArgs['addCharacterToRoster'] = {
      'roomCode': roomCode,
      'characterName': characterName,
      'playerName': playerName,
    };
  }

  @override
  Future<void> removeCharacterFromRoster({
    required String roomCode,
    required String characterName,
    required String playerName,
  }) async {
    calls.add('removeCharacterFromRoster');
    lastArgs['removeCharacterFromRoster'] = {
      'roomCode': roomCode,
      'characterName': characterName,
      'playerName': playerName,
    };
  }

  @override
  Future<void> disperseCoinsToParty({
    required String roomCode,
    required PartyPurse purseToDisperse,
    required List<String> recipientCharacters,
    required String performedBy,
    bool includePartyReserve = true,
    double liquidatedGemsAndArtGp = 0.0,
    bool includeLiquidatedInSplit = false,
    bool isVaultDispersal = false,
  }) async {
    calls.add('disperseCoinsToParty');
    lastArgs['disperseCoinsToParty'] = {
      'roomCode': roomCode,
      'recipientCharacters': recipientCharacters,
      'performedBy': performedBy,
      'includePartyReserve': includePartyReserve,
      'liquidatedGemsAndArtGp': liquidatedGemsAndArtGp,
      'includeLiquidatedInSplit': includeLiquidatedInSplit,
      'isVaultDispersal': isVaultDispersal,
    };
  }

  @override
  Future<void> updateMemberPurse({
    required String roomCode,
    required String characterName,
    String? characterSlug,
    required PartyPurse newPurse,
    required String performedBy,
    String? note,
  }) async {
    calls.add('updateMemberPurse');
    lastArgs['updateMemberPurse'] = {
      'roomCode': roomCode,
      'characterName': characterName,
      'newPurse': newPurse,
      'performedBy': performedBy,
      'note': note,
    };
  }

  @override
  Future<void> transferMemberToReserve({
    required String roomCode,
    required String characterName,
    required String performedBy,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
  }) async {
    calls.add('transferMemberToReserve');
    lastArgs['transferMemberToReserve'] = {
      'roomCode': roomCode,
      'characterName': characterName,
      'performedBy': performedBy,
      'cp': cp,
      'sp': sp,
      'ep': ep,
      'gp': gp,
      'pp': pp,
    };
  }

  @override
  Future<void> transferReserveToMember({
    required String roomCode,
    required String characterName,
    required String performedBy,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
  }) async {
    calls.add('transferReserveToMember');
    lastArgs['transferReserveToMember'] = {
      'roomCode': roomCode,
      'characterName': characterName,
      'performedBy': performedBy,
      'cp': cp,
      'sp': sp,
      'ep': ep,
      'gp': gp,
      'pp': pp,
    };
  }

  @override
  Future<PartySessionState> linkCharacterToCampaign({
    required String roomCode,
    required Character character,
    String? existingRosterName,
    bool isNewImport = true,
  }) async {
    calls.add('linkCharacterToCampaign');
    lastArgs['linkCharacterToCampaign'] = {
      'roomCode': roomCode,
      'character': character,
      'existingRosterName': existingRosterName,
      'isNewImport': isNewImport,
    };
    return PartySessionState(
      roomCode: roomCode,
      campaignName: 'Linked Campaign',
      hostKeyHash: 'hash',
      activePlayers: [character.name],
      characterRoster: [existingRosterName ?? character.name],
      lastUpdated: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 2, 1),
    );
  }
}

Character _makeTestCharacter(String id, String name) {
  return Character(
    id: EntityId(slug: id, ruleset: RulesetVersion.v2024),
    name: name,
    speciesRef: const EntityReference<DomainEntity>.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    baseScores: const AbilityScores(
      strength: 15,
      dexterity: 12,
      constitution: 14,
      intelligence: 10,
      wisdom: 10,
      charisma: 8,
    ),
  );
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required VoidCallback onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: onOpen,
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HiveTestHarness harness;
  late CampaignRegistryService registry;
  late DiceRoomService diceService;
  late _SpyPartyRoomService spyPartyService;
  late ReplicaId replica;
  late StatefulHlcClock clock;

  setUp(() async {
    harness = HiveTestHarness();
    await harness.setUpInMemory();
    SharedPreferences.setMockInitialValues({});
    registry = CampaignRegistryService.newInstance();
    diceService = createBoundTestDiceRoomService();
    replica = ReplicaId('campaign_dialogs_char_replica');
    clock = StatefulHlcClock(replicaId: replica);
    final campRepo = LocalCampaignRepository(
      replicaId: replica,
      clock: clock,
      characterRepo: LocalCharacterRepository(),
    );
    sl.registerSingleton<ICampaignRepository>(campRepo);
    sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
    configureTestServices(
      repository: campRepo,
      replicaId: replica,
      clock: clock,
      registryService: registry,
    );
    spyPartyService = _SpyPartyRoomService(
      replicaId: replica,
      clock: clock,
      registry: registry,
      diceRoomService: diceService,
    );
    PartyRoomService.setCustomInstanceForTesting(spyPartyService);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      if (call.method == 'Clipboard.getData') return const {'text': ''};
      return null;
    });

    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      campRepo.dispose();
      PartyRoomService.resetCustomInstanceForTesting();
      sl.reset();
      await harness.tearDown();
    });
  });

  group('1. CreateCampaignDialog characterization', () {
    testWidgets('texts, initial value, empty validation, confirm, and cancel',
        (tester) async {
      String? createdRoom;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CreateCampaignDialog.show(
                  context,
                  initialCampaignName: 'Stormwreck',
                  onCreated: (code) => createdRoom = code,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Campaign'), findsOneWidget);
      expect(find.text('Campaign / Party Name'), findsOneWidget);
      expect(find.text('e.g. Crown of the Dragon King, Vault of Winter'),
          findsOneWidget);
      expect(find.text('Your DM / Display Name'), findsOneWidget);
      expect(find.text('e.g. Dungeon Master Kevin'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Campaign'), findsOneWidget);
      expect(find.text('Stormwreck'), findsOneWidget);

      // Empty campaign name validation
      await tester.enterText(
        find.widgetWithText(TextField, 'Campaign / Party Name'),
        '',
      );
      await tester.tap(find.text('Create Campaign'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a campaign name.'), findsOneWidget);
      expect(spyPartyService.calls, isEmpty);

      // Cancel closes without calling service
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Create New Campaign'), findsNothing);
      expect(spyPartyService.calls, isEmpty);

      // Reopen and confirm
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Campaign / Party Name'),
        'Vault of Winter',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Your DM / Display Name'),
        'Kevin',
      );
      await tester.tap(find.text('Create Campaign'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['createCampaign']));
      expect(
        spyPartyService.lastArgs['createCampaign'],
        equals({
          'campaignName': 'Vault of Winter',
          'playerName': 'Kevin',
          'linkProfileId': null,
        }),
      );
      expect(createdRoom, equals('ROOM-NEW111'));
    });
  });

  group('2. JoinCampaignDialog characterization', () {
    testWidgets('texts, initial room code, empty validation, confirm, and cancel',
        (tester) async {
      String? joinedRoom;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => JoinCampaignDialog.show(
                  context,
                  initialRoomCode: 'ROOM-INIT12',
                  onJoined: (code) => joinedRoom = code,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Join Existing Campaign'), findsOneWidget);
      expect(find.text('Room Code'), findsOneWidget);
      expect(find.text('e.g. ROOM-A1B2C3'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Join Room'), findsOneWidget);
      expect(find.text('ROOM-INIT12'), findsOneWidget);

      // Empty room code validation
      await tester.enterText(find.widgetWithText(TextField, 'Room Code'), '');
      await tester.tap(find.text('Join Room'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a room code.'), findsOneWidget);
      expect(spyPartyService.calls, isEmpty);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Join Existing Campaign'), findsNothing);
      expect(spyPartyService.calls, isEmpty);

      // Confirm
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Room Code'), 'room-abc123');
      await tester.tap(find.text('Join Room'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['joinCampaign']));
      final args =
          spyPartyService.lastArgs['joinCampaign'] as Map<String, Object?>;
      expect(args['roomCode'], equals('ROOM-ABC123'));
      expect(args['playerName'], equals('Adventurer'));
      expect(joinedRoom, equals('ROOM-ABC123'));
    });
  });

  group('3. ShareDmPasskeyDialog characterization', () {
    testWidgets('texts, passkey display, copy snackbar, and Done close',
        (tester) async {
      final membership = CampaignMembership(
        roomCode: 'ROOM-SHARE1',
        campaignName: 'Dragon Spire',
        role: CampaignRole.host,
        hostKey: '11111111-2222-4333-8444-555555555555',
        lastPlayed: DateTime.utc(2026, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ShareDmPasskeyDialog(membership: membership),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('DM Passkey Delegation'), findsOneWidget);
      expect(find.text('Room Code:'), findsOneWidget);
      expect(find.text('ROOM-SHARE1'), findsOneWidget);
      expect(find.text('DM passkey:'), findsOneWidget);
      expect(find.text('11111111-2222-4333-8444-555555555555'), findsOneWidget);
      expect(find.text('Copy Passkey'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Copy Passkey'));
      await tester.pumpAndSettle();
      expect(find.text('DM Passkey copied to clipboard!'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('DM Passkey Delegation'), findsNothing);
    });
  });

  group('4. ClaimDmPasskeyDialog characterization', () {
    testWidgets('texts, initial values, empty validations, confirm, and cancel',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ClaimDmPasskeyDialog.show(
                  context,
                  initialRoomCode: 'ROOM-CLM001',
                  initialPlayerName: 'Dain',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Claim DM / Co-DM Status'), findsOneWidget);
      expect(find.text('Room Code'), findsOneWidget);
      expect(find.text('e.g. ROOM-A1B2C3'), findsOneWidget);
      expect(find.text('DM Passkey / Host Key'), findsOneWidget);
      expect(find.text('Paste DM passkey (host key)'), findsOneWidget);
      expect(find.text('Your DM / Display Name (Optional)'), findsOneWidget);
      expect(find.text('e.g. Dungeon Master Kevin'), findsOneWidget);
      expect(find.text('DM / Host'), findsOneWidget);
      expect(find.text('Co-DM'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Claim DM Role'), findsOneWidget);
      expect(find.text('ROOM-CLM001'), findsOneWidget);
      expect(find.text('Dain'), findsOneWidget);

      // Empty passkey validation
      await tester.tap(find.text('Claim DM Role'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter the DM passkey.'), findsOneWidget);
      expect(spyPartyService.calls, isEmpty);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Claim DM / Co-DM Status'), findsNothing);

      // Reopen, empty room code validation
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Room Code'), '');
      await tester.tap(find.text('Claim DM Role'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a room code.'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'Room Code'), 'ROOM-CLM001');
      await tester.enterText(
        find.widgetWithText(TextField, 'DM Passkey / Host Key'),
        'host-key-xyz',
      );
      await tester.tap(find.text('Co-DM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claim DM Role'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['claimDmRole']));
      expect(
        spyPartyService.lastArgs['claimDmRole'],
        equals({
          'roomCode': 'ROOM-CLM001',
          'hostKeyOrPasskey': 'host-key-xyz',
          'playerName': 'Dain',
          'targetRole': CampaignRole.coDm,
        }),
      );
    });
  });

  group('5. ImportDmPasskeyDialog alias characterization', () {
    testWidgets('is a typedef alias for ClaimDmPasskeyDialog and renders identically',
        (tester) async {
      const Widget w = ImportDmPasskeyDialog(
        initialRoomCode: 'ROOM-ALIAS1',
        initialPlayerName: 'AliasDM',
      );
      expect(w, isA<ClaimDmPasskeyDialog>());

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: w)));
      await tester.pumpAndSettle();
      expect(find.text('Claim DM / Co-DM Status'), findsOneWidget);
      expect(find.text('ROOM-ALIAS1'), findsOneWidget);
      expect(find.text('AliasDM'), findsOneWidget);
    });
  });

  group('6. AddLootItemDialog characterization', () {
    testWidgets('texts, initial values, empty-name guard, confirm, and cancel',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddLootItemDialog.show(
                  context,
                  roomCode: 'ROOM-LOOT01',
                  playerName: 'Valen',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add Vault Item'), findsOneWidget);
      expect(find.text('Item Name'), findsOneWidget);
      expect(find.text('e.g. Cloak of Protection'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('GP Value Each'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add to Vault'), findsOneWidget);

      // Empty item name does not call service or close
      await tester.tap(find.text('Add to Vault'));
      await tester.pumpAndSettle();
      expect(spyPartyService.calls, isEmpty);
      expect(find.text('Add Vault Item'), findsOneWidget);

      // Cancel closes without calling service
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add Vault Item'), findsNothing);

      // Confirm
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Item Name'), 'Healing Potion');
      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
      await tester.enterText(
          find.widgetWithText(TextField, 'GP Value Each'), '50');
      await tester.tap(find.text('Add to Vault'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['addLootItem']));
      final args =
          spyPartyService.lastArgs['addLootItem'] as Map<String, Object?>;
      expect(args['roomCode'], equals('ROOM-LOOT01'));
      expect(args['playerName'], equals('Valen'));
      final item = args['item'] as PartyLootItem;
      expect(item.name, equals('Healing Potion'));
      expect(item.count, equals(3));
      expect(item.gpValue, equals(50.0));
    });
  });

  group('7. CoinTransactionDialog characterization', () {
    testWidgets('deposit & withdraw texts, initial 0s, zero-amount close, confirm',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CoinTransactionDialog.show(
                  context,
                  roomCode: 'ROOM-COIN01',
                  playerName: 'Valen',
                  isDeposit: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit Coins'), findsOneWidget);
      expect(find.text('PP (Plat)'), findsOneWidget);
      expect(find.text('GP (Gold)'), findsOneWidget);
      expect(find.text('EP (Elec)'), findsOneWidget);
      expect(find.text('SP (Silv)'), findsOneWidget);
      expect(find.text('CP (Copp)'), findsOneWidget);
      expect(find.text('Transaction Note / Source'), findsOneWidget);
      expect(find.text('e.g. Goblin Lair chest'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Deposit'), findsOneWidget);

      // Submitting all zeros closes without calling service
      await tester.tap(find.text('Deposit'));
      await tester.pumpAndSettle();
      expect(spyPartyService.calls, isEmpty);

      // Reopen, tap +50 GP and confirm
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+50 GP'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Transaction Note / Source'),
        'Chest',
      );
      await tester.tap(find.text('Deposit'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['depositCoins']));
      expect(
        spyPartyService.lastArgs['depositCoins'],
        equals({
          'roomCode': 'ROOM-COIN01',
          'playerName': 'Valen',
          'cp': 0,
          'sp': 0,
          'ep': 0,
          'gp': 50,
          'pp': 0,
          'note': 'Chest',
        }),
      );
    });
  });

  group('8. SwitchActiveCharacterDialog characterization', () {
    testWidgets('empty roster vs 3-item roster, confirm pops name, cancel pops null',
        (tester) async {
      // List of none
      String? poppedEmpty = 'sentinel';
      await _pumpLauncher(
        tester,
        onOpen: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  poppedEmpty = await SwitchActiveCharacterDialog.show(
                    context,
                    roomCode: 'ROOM-SW01',
                    currentName: 'Valen',
                    roster: const [],
                  );
                },
                child: const Text('OpenEmpty'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenEmpty'));
      await tester.pumpAndSettle();
      expect(find.text('Select Active Character'), findsOneWidget);
      expect(find.text('Character / Player Name'), findsOneWidget);
      expect(find.text('e.g. Thorek Ironbreaker (Fighter)'), findsOneWidget);
      expect(find.text('Save to campaign party roster'), findsOneWidget);
      expect(find.text('Or Pick from Campaign Roster:'), findsNothing);
      expect(find.text('Valen'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(poppedEmpty, isNull);

      // List of three
      String? poppedThree;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  poppedThree = await SwitchActiveCharacterDialog.show(
                    context,
                    roomCode: 'ROOM-SW01',
                    currentName: 'Aldric',
                    roster: const ['Aldric', 'Lyra', 'Kael'],
                  );
                },
                child: const Text('OpenThree'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenThree'));
      await tester.pumpAndSettle();
      expect(find.text('Or Pick from Campaign Roster:'), findsOneWidget);
      expect(find.text('Lyra'), findsOneWidget);
      expect(find.text('Kael'), findsOneWidget);

      await tester.tap(find.text('Lyra'));
      await tester.pumpAndSettle();
      expect(poppedThree, equals('Lyra'));
      expect(spyPartyService.calls, contains('setActiveCharacter'));
      expect(
        spyPartyService.lastArgs['setActiveCharacter'],
        equals({'roomCode': 'ROOM-SW01', 'characterName': 'Lyra'}),
      );
    });
  });

  group('9. ManagePartyRosterDialog characterization', () {
    testWidgets('empty roster vs 3-item roster, add, play as, and Done',
        (tester) async {
      // List of none
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ManagePartyRosterDialog.show(
                  context,
                  roomCode: 'ROOM-RST1',
                  currentName: 'Aldric',
                  initialRoster: const [],
                ),
                child: const Text('OpenEmpty'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenEmpty'));
      await tester.pumpAndSettle();
      expect(find.text('Party Character Roster'), findsOneWidget);
      expect(find.text('Add Character / Player'), findsOneWidget);
      expect(find.text('e.g. Sylas (Ranger)'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // List of three
      String? activeChanged;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ManagePartyRosterDialog.show(
                  context,
                  roomCode: 'ROOM-RST1',
                  currentName: 'Aldric',
                  initialRoster: const ['Aldric', 'Lyra', 'Kael'],
                  onActiveCharacterChanged: (n) => activeChanged = n,
                ),
                child: const Text('OpenThree'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenThree'));
      await tester.pumpAndSettle();
      expect(find.text('Aldric'), findsOneWidget);
      expect(find.text('Lyra'), findsOneWidget);
      expect(find.text('Kael'), findsOneWidget);
      expect(find.text('Active Session Character'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Add Character / Player'), 'Mira');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(spyPartyService.calls, contains('addCharacterToRoster'));
      expect(find.text('Mira'), findsOneWidget);

      await tester.tap(find.text('Play As').first);
      await tester.pumpAndSettle();
      expect(activeChanged, equals('Lyra'));
      expect(spyPartyService.calls, contains('setActiveCharacter'));
    });
  });

  group('10. AssignLootDialog characterization', () {
    testWidgets('empty roster vs 3-item roster, assign, unclaim, and cancel',
        (tester) async {
      // List of none
      String? resultEmpty;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultEmpty = await AssignLootDialog.show(
                    context,
                    itemName: 'Bag of Holding',
                    currentActiveName: 'Aldric',
                    roster: const [],
                  );
                },
                child: const Text('OpenEmpty'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenEmpty'));
      await tester.pumpAndSettle();
      expect(find.text('Assign "Bag of Holding"'), findsOneWidget);
      expect(find.text('Aldric (You)'), findsOneWidget);
      expect(find.text('Return to Vault (Unclaim / Shared)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Return to Vault (Unclaim / Shared)'));
      await tester.pumpAndSettle();
      expect(resultEmpty, equals('__unclaim__'));

      // List of three
      String? resultThree;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultThree = await AssignLootDialog.show(
                    context,
                    itemName: 'Sun Blade',
                    currentActiveName: 'Aldric',
                    roster: const ['Aldric', 'Lyra', 'Kael'],
                  );
                },
                child: const Text('OpenThree'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenThree'));
      await tester.pumpAndSettle();
      expect(find.text('Aldric (You)'), findsOneWidget);
      expect(find.text('Lyra'), findsOneWidget);
      expect(find.text('Kael'), findsOneWidget);
      await tester.tap(find.text('Kael'));
      await tester.pumpAndSettle();
      expect(resultThree, equals('Kael'));
    });
  });

  group('11. DisperseLootDialog characterization', () {
    testWidgets('texts, empty room validation, reserve-only confirm, cancel',
        (tester) async {
      final purse = const PartyPurse.empty().depositCoins(
        gp: 100,
        replicaId: replica,
      );

      // Empty room validation (no memberships, no initialRoomCode)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DisperseLootDialog.show(
                  context,
                  purse: purse,
                ),
                child: const Text('OpenNoRoom'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenNoRoom'));
      await tester.pumpAndSettle();
      expect(find.text('Disperse Loot to Party'), findsOneWidget);
      expect(find.text('Total to Disperse:'), findsOneWidget);
      expect(find.text('A share for the Party Reserve'), findsOneWidget);
      await tester.tap(find.text('Disperse (1 Shares)'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a campaign room first.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // With room code and 0-member roster (non-empty roster hits AlertDialog
      // IntrinsicWidth + ListView.builder RenderShrinkWrappingViewport).
      spyPartyService.sessionsByCode['ROOM-DSP1'] = PartySessionState(
        roomCode: 'ROOM-DSP1',
        campaignName: 'Vault',
        hostKeyHash: 'hash',
        activePlayers: const [],
        characterRoster: const [],
        lastUpdated: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 2, 1),
      );

      bool? popped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  popped = await DisperseLootDialog.show(
                    context,
                    initialRoomCode: 'ROOM-DSP1',
                    purse: purse,
                  );
                },
                child: const Text('OpenWithRoom'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenWithRoom'));
      await tester.pumpAndSettle();
      expect(find.text('Disperse (1 Shares)'), findsOneWidget);
      await tester.tap(find.text('Disperse (1 Shares)'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(spyPartyService.calls, equals(['disperseCoinsToParty']));
      final args = spyPartyService.lastArgs['disperseCoinsToParty']
          as Map<String, Object?>;
      expect(args['roomCode'], equals('ROOM-DSP1'));
      expect(args['recipientCharacters'], isEmpty);
      expect(args['includePartyReserve'], isTrue);
    });
  });

  group('12. MemberCoinTransactionDialog characterization', () {
    testWidgets('texts, initial 0s, zero-amount close, confirm updateMemberPurse',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MemberCoinTransactionDialog.show(
                  context,
                  roomCode: 'ROOM-MEM1',
                  characterName: 'Lyra',
                  performedBy: 'DM',
                  isDeposit: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit to Lyra'), findsOneWidget);
      expect(find.text('Deposit Coins'), findsOneWidget);
      expect(find.text('Gold (GP)'), findsOneWidget);
      expect(find.text('Reason / Note (Optional)'), findsOneWidget);
      expect(find.text('e.g. Bought potions, Tavern bill'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Zero amount closes without calling service
      await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit Coins'));
      await tester.pumpAndSettle();
      expect(spyPartyService.calls, isEmpty);

      // Confirm non-zero deposit
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Gold (GP)'), '25');
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason / Note (Optional)'),
        'Quest reward',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit Coins'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['updateMemberPurse']));
      final args =
          spyPartyService.lastArgs['updateMemberPurse'] as Map<String, Object?>;
      expect(args['roomCode'], equals('ROOM-MEM1'));
      expect(args['characterName'], equals('Lyra'));
      expect(args['note'], equals('Quest reward'));
      expect((args['newPurse'] as PartyPurse).getBalance('gp'), equals(25));
    });
  });

  group('13. TransferCoinDialog characterization', () {
    testWidgets('texts, initial 0s, zero-amount close, confirm transferMemberToReserve',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TransferCoinDialog.show(
                  context,
                  roomCode: 'ROOM-XFR1',
                  characterName: 'Kael',
                  performedBy: 'Kael',
                  toReserve: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm Transfer'), findsOneWidget);

      // Zero amount closes without calling service
      await tester.tap(find.text('Confirm Transfer'));
      await tester.pumpAndSettle();
      expect(spyPartyService.calls, isEmpty);

      // Confirm 15 GP transfer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Gold (GP)'), '15');
      await tester.tap(find.text('Confirm Transfer'));
      await tester.pumpAndSettle();

      expect(spyPartyService.calls, equals(['transferMemberToReserve']));
      expect(
        spyPartyService.lastArgs['transferMemberToReserve'],
        equals({
          'roomCode': 'ROOM-XFR1',
          'characterName': 'Kael',
          'performedBy': 'Kael',
          'cp': 0,
          'sp': 0,
          'ep': 0,
          'gp': 15,
          'pp': 0,
        }),
      );
    });
  });

  group('14. LinkCampaignCharacterDialog characterization', () {
    testWidgets('0 saved characters vs 3 saved characters, confirm link, cancel',
        (tester) async {
      // List of none
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LinkCampaignCharacterDialog.show(
                  context,
                  roomCode: 'ROOM-LNK1',
                ),
                child: const Text('OpenEmpty'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenEmpty'));
      await tester.pumpAndSettle();
      expect(find.text('Link Character to Campaign'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(spyPartyService.calls, isEmpty);

      // List of three saved characters
      final persistence = CharacterPersistenceService();
      await persistence.saveCharacter(_makeTestCharacter('c1', 'Aldric'));
      await persistence.saveCharacter(_makeTestCharacter('c2', 'Lyra'));
      await persistence.saveCharacter(_makeTestCharacter('c3', 'Kael'));

      var linkedCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LinkCampaignCharacterDialog.show(
                  context,
                  roomCode: 'ROOM-LNK1',
                  onLinked: () => linkedCalled = true,
                ),
                child: const Text('OpenThree'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OpenThree'));
      await tester.pumpAndSettle();
      expect(find.text('Select Character'), findsOneWidget);
      expect(find.text('Campaign Roster Mode:'), findsOneWidget);
      expect(find.text('Import as new character'), findsOneWidget);
      expect(find.text('Link to existing character slot'), findsOneWidget);
      expect(find.text('Link Character'), findsOneWidget);

      await tester.tap(find.text('Link Character'));
      await tester.pumpAndSettle();
      expect(linkedCalled, isTrue);
      expect(spyPartyService.calls, equals(['linkCharacterToCampaign']));
      final args = spyPartyService.lastArgs['linkCharacterToCampaign']
          as Map<String, Object?>;
      expect(args['roomCode'], equals('ROOM-LNK1'));
      expect((args['character'] as Character).name, equals('Aldric'));
      expect(args['isNewImport'], isTrue);
    });
  });
}
