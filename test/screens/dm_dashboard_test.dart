import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';

Widget _buildTestApp({Widget? home}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: home ?? const DmDashboardScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.reset();
  });

  group('DmDashboardScreen Widget Tests', () {
    testWidgets('Renders all 5 tactical HUD sections and default campaign header', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(
        id: 'camp_test_render',
        name: 'Vampire Lord of the Mist',
        edition: DmRulesEdition.v2024,
      );
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // App Bar
      expect(find.text('Vampire Lord of the Mist'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);

      // 5 HUD Cards
      expect(find.text('Combat & Turn Tracker'), findsOneWidget);
      expect(find.text('Party Vitality HUD'), findsOneWidget);
      expect(find.text('Minion & Summon Tracker'), findsOneWidget);
      expect(find.text('Quick-Pinned Rules & Calculators'), findsOneWidget);
      expect(find.text('Session Notes & Party Purse'), findsOneWidget);

      // Embedded calculators
      expect(find.text('Concentration DC Calculator'), findsOneWidget);
      expect(find.text('Falling Damage Calculator'), findsOneWidget);
      expect(find.text('Grapple / Shove DC Engine'), findsOneWidget);
    });

    testWidgets('Initiative turn cycling advances active turn and round counter', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(
        id: 'camp_init_test',
        name: 'Initiative Arena',
      ).copyWith(
        roomState: const RoomNodeState(
          roomId: 'r1',
          roomCode: 'CR-1',
          title: 'Arena Room',
          activeEncounter: [
            EncounterParticipant(
              participantId: 'p1',
              entityLink: RoomEntityLink(
                refType: SessionRefType.character,
                entityId: 'c1',
                displayName: 'Fighter Jack',
              ),
              initiativeScore: 18,
              currentHp: 30,
              maxHp: 30,
              armorClass: 16,
              isActiveTurn: true,
            ),
            EncounterParticipant(
              participantId: 'p2',
              entityLink: RoomEntityLink(
                refType: SessionRefType.monster,
                entityId: 'm1',
                displayName: 'Goblin Boss',
              ),
              initiativeScore: 12,
              currentHp: 21,
              maxHp: 21,
              armorClass: 14,
              isActiveTurn: false,
            ),
          ],
        ),
      );
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Fighter Jack'), findsOneWidget);
      expect(find.text('Goblin Boss'), findsOneWidget);
      expect(find.text('Round 1'), findsOneWidget);

      // Tap Next Turn
      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();

      // Next Turn wraps to round 2
      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();

      expect(find.text('Round 2'), findsOneWidget);
    });

    testWidgets('Applying damage and heal chips updates participant HP with Temp HP absorption', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(
        id: 'camp_hp_test',
        name: 'HP Test Table',
      ).copyWith(
        roomState: const RoomNodeState(
          roomId: 'r1',
          roomCode: 'CR-1',
          title: 'Room',
          activeEncounter: [
            EncounterParticipant(
              participantId: 'p1',
              entityLink: RoomEntityLink(
                refType: SessionRefType.monster,
                entityId: 'm1',
                displayName: 'Ogre Brute',
              ),
              initiativeScore: 10,
              currentHp: 50,
              maxHp: 50,
              tempHp: 5,
              armorClass: 12,
            ),
          ],
        ),
      );
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('HP: 50/50 (+5 Temp)'), findsOneWidget);

      // Tap -10 damage: absorbs 5 temp HP, leaves 45 current HP
      await tester.tap(find.text('-10'));
      await tester.pumpAndSettle();

      expect(find.text('HP: 45/50'), findsOneWidget);

      // Tap +5 healing
      await tester.tap(find.text('+5').first);
      await tester.pumpAndSettle();

      expect(find.text('HP: 50/50'), findsOneWidget);
    });

    testWidgets('Adds new combatant via Add Combatant dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(id: 'camp_add_c', name: 'Add Combatant Table');
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add Combatant'), findsOneWidget);
      await tester.tap(find.byTooltip('Add Combatant'));
      await tester.pumpAndSettle();

      expect(find.text('Add Combatant to Encounter'), findsOneWidget);

      // Tap Add button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Goblin Scout'), findsOneWidget);
      expect(find.text('AC 13'), findsOneWidget);
    });

    testWidgets('Adds animated minion and updates minion HP', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(id: 'camp_minion_t', name: 'Minions Table');
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Summon Minion / Object'));
      await tester.pumpAndSettle();

      expect(find.text('Summon / Animate Object'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Summon'));
      await tester.pumpAndSettle();

      expect(find.text('Animated Table'), findsOneWidget);
      expect(find.text('40/40'), findsOneWidget);
    });

    testWidgets('Session notes scratchpad edits persist', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(id: 'camp_notes_t', name: 'Notes Table');
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final textFieldFinder = find.widgetWithText(TextField, 'DM Scratchpad & Session Notes');
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, 'Secret trap door behind the painting.');
      await tester.pumpAndSettle();

      final current = await CampaignProfileService().getActiveProfile();
      expect(current.notesMarkdown, equals('Secret trap door behind the painting.'));
    });

    testWidgets('Campaign picker bottom sheet opens and switches campaign', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = CampaignProfile.defaultProfile(id: 'c1', name: 'First Campaign');
      final p2 = CampaignProfile.defaultProfile(id: 'c2', name: 'Second Campaign');
      await CampaignProfileService().saveProfileImmediate(p1);
      await CampaignProfileService().saveProfileImmediate(p2);
      await CampaignProfileService().switchProfile('c1');

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('First Campaign'), findsOneWidget);

      // Tap app bar title to open bottom sheet
      await tester.tap(find.text('First Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('Campaign Workspaces'), findsOneWidget);
      expect(find.text('Second Campaign'), findsOneWidget);

      // Switch to Second Campaign
      await tester.tap(find.text('Second Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('Second Campaign'), findsOneWidget);
    });

    testWidgets('Opens Snapshot Export dialog and copies JSON', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(id: 'c_exp', name: 'Export Test Campaign');
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export Campaign Snapshot'));
      await tester.pumpAndSettle();

      expect(find.text('Campaign Snapshot Ready'), findsOneWidget);
      expect(find.text('Copy JSON'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Campaign Snapshot Ready'), findsNothing);
    });

    testWidgets('Handles invalid snapshot JSON import gracefully with error snackbar', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p = CampaignProfile.defaultProfile(id: 'c_imp', name: 'Import Test Table');
      await CampaignProfileService().saveProfileImmediate(p);
      await CampaignProfileService().switchProfile(p.id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Snapshot...'));
      await tester.pumpAndSettle();

      expect(find.text('Import Campaign Snapshot'), findsOneWidget);

      // Enter invalid text
      final inputFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputFinder, 'corrupted invalid json payload');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Validate & Import'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to import campaign: Invalid or corrupted snapshot JSON.'), findsOneWidget);
    });
  });
}
