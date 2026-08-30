import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/party/campaign_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CryptoUtils extractHostKey', () {
    test('extracts raw UUID cleanly', () {
      const uuid = 'c4974958-3d12-4217-bf45-ee77e9b0ab83';
      expect(CryptoUtils.extractHostKey(uuid), equals(uuid));
      expect(CryptoUtils.extractHostKey('  $uuid  '), equals(uuid));
    });

    test('extracts UUID from labeled text and copied passkey snippet', () {
      const snippet = '''
Room: ROOM-123456
Passkey Mnemonic: dragon wizard shield potion goblin scroll
HostKey: c4974958-3d12-4217-bf45-ee77e9b0ab83
''';
      expect(CryptoUtils.extractHostKey(snippet), equals('c4974958-3d12-4217-bf45-ee77e9b0ab83'));
    });
  });

  group('ClaimDmPasskeyDialog Widget Tests', () {
    late CampaignRegistryService registry;
    late DiceRoomService diceService;
    late PartyRoomService partyService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      registry = CampaignRegistryService.newInstance();
      diceService = DiceRoomService.newInstance();
      partyService = PartyRoomService.newInstance(
        registry: registry,
        diceRoomService: diceService,
      );
    });

    testWidgets('Renders ClaimDmPasskeyDialog with inputs and ChoiceChips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ClaimDmPasskeyDialog.show(
                  context,
                  initialRoomCode: 'ROOM-ABC123',
                  initialPlayerName: 'Gimli',
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Claim DM / Co-DM Status'), findsOneWidget);
      expect(find.text('ROOM-ABC123'), findsOneWidget);
      expect(find.text('Gimli'), findsOneWidget);
      expect(find.text('DM / Host'), findsOneWidget);
      expect(find.text('Co-DM'), findsOneWidget);
      expect(find.text('Claim DM Role'), findsOneWidget);
    });

    testWidgets('Submitting valid passkey promotes membership to DM and closes dialog', (tester) async {
      // 1. Create a campaign to get valid roomCode and hostKey
      final session = await partyService.createCampaign(
        campaignName: 'Underdark Exploration',
        playerName: 'Original DM',
      );

      final dmMembership = registry.getMembership(session.roomCode);
      final rawKey = dmMembership!.hostKey!;

      // Separate player registry
      final playerRegistry = CampaignRegistryService.newInstance();
      PartyRoomService.newInstance(
        registry: playerRegistry,
        diceRoomService: diceService,
      );

      CampaignMembership? claimedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ClaimDmPasskeyDialog.show(
                  context,
                  initialRoomCode: session.roomCode,
                  initialPlayerName: 'Player Karl',
                  onClaimed: (m) => claimedResult = m,
                ),
                child: const Text('Claim DM'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Claim DM'));
      await tester.pumpAndSettle();

      // Enter passkey
      final passkeyField = find.widgetWithText(TextField, 'DM Passkey / Host Key');
      expect(passkeyField, findsOneWidget);
      await tester.enterText(passkeyField, rawKey);
      await tester.pump();

      // Tap Claim DM Role button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Claim DM Role'));
      await tester.pumpAndSettle();

      expect(find.text('Claim DM / Co-DM Status'), findsNothing);
      expect(claimedResult, isNotNull);
      expect(claimedResult!.role, equals(CampaignRole.host));
      expect(claimedResult!.hasHostKey, isTrue);
    });

    testWidgets('JoinCampaignDialog renders DM passkey toggle and inputs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => JoinCampaignDialog.show(
                  context,
                  initialRoomCode: 'ROOM-XYZ999',
                ),
                child: const Text('Join Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Join Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Join Existing Campaign'), findsOneWidget);
      expect(find.text('I have a DM Passkey / Host Code'), findsOneWidget);

      // Tap toggle
      await tester.tap(find.text('I have a DM Passkey / Host Code'));
      await tester.pumpAndSettle();

      expect(find.text('DM Passkey / Host Key'), findsOneWidget);
      expect(find.text('Join as DM'), findsOneWidget);
    });
  });
}
