import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/tables/treasure_hoard_view.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_currency_system.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import '../test_doubles/fake_room_document_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        body: TreasureHoardView(),
      ),
    );
  }

  group('TreasureHoardView Campaign Vault Deposit Integration', () {
    late CampaignRegistryService registry;
    late PartyRoomService partyService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      registry = CampaignRegistryService();
      final replica = ReplicaId('treasure_deposit_replica');
      final clock = StatefulHlcClock(replicaId: replica);
      final campRepo = LocalCampaignRepository(
        replicaId: replica,
        clock: clock,
        characterRepo: LocalCharacterRepository(),
      );
      sl.registerSingleton<ICampaignRepository>(campRepo);
      sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
      partyService = PartyRoomService.newInstance(
        replicaId: replica,
        clock: clock,
        registry: registry,
      );
      PartyRoomService.setCustomInstanceForTesting(partyService);
      addTearDown(() {
        campRepo.dispose();
        PartyRoomService.resetCustomInstanceForTesting();
        sl.reset();
      });
    });

    testWidgets('Depositing generated hoard into connected campaign vault',
        (tester) async {
      const roomCode = 'ROOM-HOARD1';
      final membership = CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Hoard Test Campaign',
        role: CampaignRole.host,
        hostKey: 'secret-key',
        characterId: 'DM Kevin',
        lastPlayed: DateTime.now(),
      );
      await registry.saveMembership(membership);
      await partyService.createCampaign(
        campaignName: 'Hoard Test Campaign',
        customRoomCode: roomCode,
        playerName: 'DM Kevin',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find the Deposit icon button in the title bar
      final depositButton = find.byTooltip('Deposit into Campaign Vault');
      expect(depositButton, findsOneWidget);

      await tester.tap(depositButton);
      await tester.pumpAndSettle();

      // Verify success snackbar
      expect(
          find.textContaining('Deposited treasure into "Hoard Test Campaign"'),
          findsOneWidget);

      // Verify coins were added to the campaign
      final session = await partyService.streamSession(roomCode).first;
      expect(session, isNotNull);
      expect(session!.partyPurse.totalGpEquivalent > 0, isTrue);
    });
  });
}
