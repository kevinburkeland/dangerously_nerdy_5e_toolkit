import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/party/campaign_dialogs.dart';

import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Pass 11 - DM Passkey Tests (K1-K4)', () {
    late PartyRoomService partyService;
    late CampaignRegistryService registry;
    late DiceRoomService diceService;
    late LocalCampaignRepository campRepo;
    final harness = HiveTestHarness();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await harness.setUpInMemory();
      sl.reset();

      final replica = ReplicaId('passkey_test_replica');
      final clock = StatefulHlcClock(replicaId: replica);
      campRepo = LocalCampaignRepository(
        replicaId: replica,
        clock: clock,
        characterRepo: LocalCharacterRepository(),
      );
      sl.registerSingleton<ICampaignRepository>(campRepo);
      sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());

      registry = CampaignRegistryService.newInstance();
      diceService = DiceRoomService.newInstance();
      partyService = PartyRoomService.newInstance(
        replicaId: replica,
        clock: clock,
        registry: registry,
        diceRoomService: diceService,
      );
      PartyRoomService.setCustomInstanceForTesting(partyService);
      addTearDown(() async {
        campRepo.dispose();
        PartyRoomService.resetCustomInstanceForTesting();
        sl.reset();
        await harness.tearDown();
      });
    });

    test('K1: a 6-word phrase on an existing room throws the new error; registry, local rooms, and campaign repository are unchanged', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Dragon Heist',
        playerName: 'DM Kevin',
      );
      final roomCode = session.roomCode;
      final initialMemberships = List<CampaignMembership>.from(registry.memberships);
      final initialLocalRooms = Map<String, PartySessionState>.from(partyService.localRooms);
      final initialProfilesCount = (await campRepo.loadAllProfiles()).length;

      const legacyPhrase = 'dragon wizard shield potion goblin scroll';

      expect(
        () => partyService.claimDmRole(
          roomCode: roomCode,
          hostKeyOrPasskey: legacyPhrase,
        ),
        throwsA(
          isA<UnauthorizedHostActionException>().having(
            (e) => e.message,
            'message',
            'The 6-word phrase is not a passkey. Paste the DM passkey (Host Key) instead.',
          ),
        ),
      );

      // Verify no state changed
      expect(registry.memberships.length, equals(initialMemberships.length));
      expect(partyService.localRooms.length, equals(initialLocalRooms.length));
      expect(partyService.localRooms[roomCode]?.hostKeyHash, equals(initialLocalRooms[roomCode]?.hostKeyHash));
      expect((await campRepo.loadAllProfiles()).length, equals(initialProfilesCount));
    });

    test('K2: a 6-word phrase on a room the device cannot find throws the same error, and rehydrateCampaign is never reached', () async {
      const nonExistentRoom = 'ROOM-NOTFOUND';
      const legacyPhrase = 'phoenix dungeon temple rogue knight arcane';

      expect(
        () => partyService.claimDmRole(
          roomCode: nonExistentRoom,
          hostKeyOrPasskey: legacyPhrase,
        ),
        throwsA(
          isA<UnauthorizedHostActionException>().having(
            (e) => e.message,
            'message',
            'The 6-word phrase is not a passkey. Paste the DM passkey (Host Key) instead.',
          ),
        ),
      );

      // Verify no room, membership, or profile was created
      expect(registry.getMembership(nonExistentRoom), isNull);
      expect(partyService.localRooms.containsKey(nonExistentRoom), isFalse);
      expect((await campRepo.loadAllProfiles()).isEmpty, isTrue);
    });

    test('K3 (controls): raw host key accepted, wrong raw key rejected, full old copied block accepted', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Curse of Strahd',
        playerName: 'DM Alice',
      );
      final roomCode = session.roomCode;
      final membership = registry.getMembership(roomCode);
      final validHostKey = membership!.hostKey!;

      // 1. Wrong raw key is rejected with "Invalid DM passkey"
      expect(
        () => partyService.claimDmRole(
          roomCode: roomCode,
          hostKeyOrPasskey: '11111111-2222-3333-4444-555555555555',
        ),
        throwsA(
          isA<UnauthorizedHostActionException>().having(
            (e) => e.message,
            'message',
            contains('Invalid DM passkey'),
          ),
        ),
      );

      // 2. Raw host key is accepted
      final claimed1 = await partyService.claimDmRole(
        roomCode: roomCode,
        hostKeyOrPasskey: validHostKey,
        targetRole: CampaignRole.coDm,
        playerName: 'Co-DM Bob',
      );
      expect(claimed1.role, equals(CampaignRole.coDm));
      expect(claimed1.hostKey, equals(validHostKey));

      // 3. Full old copied block is accepted (extracts host key)
      final oldCopiedBlock = '''
Room: $roomCode
Passkey Mnemonic: dragon wizard shield potion goblin scroll
HostKey: $validHostKey
''';
      final claimed2 = await partyService.claimDmRole(
        roomCode: roomCode,
        hostKeyOrPasskey: oldCopiedBlock,
        targetRole: CampaignRole.host,
        playerName: 'DM Bob',
      );
      expect(claimed2.role, equals(CampaignRole.host));
      expect(claimed2.hostKey, equals(validHostKey));
    });

    testWidgets('K4 (widget): share dialog does not contain "Mnemonic" and copied text contains host key', (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          }
          return null;
        },
      );

      const testHostKey = 'c4974958-3d12-4217-bf45-ee77e9b0ab83';
      final membership = CampaignMembership(
        roomCode: 'ROOM-XYZ999',
        campaignName: 'Test Adventure',
        role: CampaignRole.host,
        hostKey: testHostKey,
        lastPlayed: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareDmPasskeyDialog(membership: membership),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Mnemonic" does not appear in dialog
      expect(find.textContaining('Mnemonic', findRichText: true), findsNothing);
      expect(find.textContaining('mnemonic', findRichText: true), findsNothing);

      // Verify room code and host key are displayed
      expect(find.text('ROOM-XYZ999'), findsOneWidget);
      expect(find.text(testHostKey), findsOneWidget);

      // Tap Copy Passkey button
      await tester.tap(find.text('Copy Passkey'));
      await tester.pumpAndSettle();

      // Verify copied text contains host key and does not contain Mnemonic
      expect(copiedText, isNotNull);
      expect(copiedText, contains(testHostKey));
      expect(copiedText, contains('ROOM-XYZ999'));
      expect(copiedText, isNot(contains('Mnemonic')));
      expect(copiedText, isNot(contains('mnemonic')));
    });
  });
}
