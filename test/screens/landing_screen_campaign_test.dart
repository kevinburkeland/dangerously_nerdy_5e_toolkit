import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: const LandingScreen(),
    );
  }

  group('LandingScreen Campaign Carousel & Hub Section', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Displays empty campaign placeholder when no campaigns exist', (tester) async {
      final registry = CampaignRegistryService();
      registry.membershipsNotifier.value = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE CAMPAIGNS & PARTY ROOMS'), findsOneWidget);
      expect(find.text('No Active Campaigns Connected'), findsOneWidget);
      expect(find.text('Create New Campaign'), findsOneWidget);
      expect(find.text('Join Campaign'), findsOneWidget);
    });

    testWidgets('Renders campaign cards with role badges and room codes when present', (tester) async {
      final registry = CampaignRegistryService();
      final c1 = CampaignMembership(
        roomCode: 'ROOM-STRHD1',
        campaignName: 'Curse of Strahd',
        role: CampaignRole.host,
        hostKey: 'secret-key-1',
        characterId: 'DM Kevin',
        lastPlayed: DateTime.now(),
      );

      final c2 = CampaignMembership(
        roomCode: 'ROOM-WTRDP2',
        campaignName: 'Waterdeep Heist',
        role: CampaignRole.player,
        characterId: 'Gimli',
        lastPlayed: DateTime.now().subtract(const Duration(hours: 3)),
      );

      registry.membershipsNotifier.value = [c1, c2];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Curse of Strahd'), findsOneWidget);
      expect(find.text('ROOM-STRHD1'), findsOneWidget);
      expect(find.text('DM'), findsOneWidget);

      expect(find.text('Waterdeep Heist'), findsOneWidget);
      expect(find.text('ROOM-WTRDP2'), findsOneWidget);
      expect(find.text('Player'), findsOneWidget);
    });

    testWidgets('Tapping Create New Campaign opens CreateCampaignDialog', (tester) async {
      final registry = CampaignRegistryService();
      registry.membershipsNotifier.value = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Campaign'), findsWidgets);
      expect(find.text('Campaign / Party Name'), findsOneWidget);
    });

    testWidgets('Tapping Join Campaign opens JoinCampaignDialog', (tester) async {
      final registry = CampaignRegistryService();
      registry.membershipsNotifier.value = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('Join Existing Campaign'), findsOneWidget);
      expect(find.text('Room Code'), findsOneWidget);
    });
  });
}
