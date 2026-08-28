import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/tables/treasure_hoard_view.dart';

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
      partyService = PartyRoomService();
    });

    testWidgets('Depositing generated hoard into connected campaign vault', (tester) async {
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

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Find the Deposit icon button in the title bar
      final depositButton = find.byTooltip('Deposit into Campaign Vault');
      expect(depositButton, findsOneWidget);

      await tester.tap(depositButton);
      await tester.pumpAndSettle();

      // Verify success snackbar
      expect(find.textContaining('Deposited treasure into "Hoard Test Campaign"'), findsOneWidget);

      // Verify coins were added to the campaign
      final session = await partyService.streamSession(roomCode).first;
      expect(session, isNotNull);
      expect(session!.partyPurse.totalGpEquivalent > 0, isTrue);
    });
  });
}
