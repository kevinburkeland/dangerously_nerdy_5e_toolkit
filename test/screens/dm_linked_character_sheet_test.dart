import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_sheet_view.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';

Widget _buildTestApp({required Widget home}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: home,
  );
}

Character _createSampleHero({required String id, required String name, int currentHp = 25}) {
  return Character(
    id: EntityId(slug: id, ruleset: RulesetVersion.v2024),
    name: name,
    speciesRef: const EntityReference(
      slug: 'human',
      refType: EntityType.species,
      displayName: 'Human',
    ),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference(
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
    resources: CharacterResourcePool(
      currentHp: currentHp,
      spellSlots: const SpellSlotPool(
        maxSlots: {1: 3},
        currentSlots: {1: 3},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.reset();
  });

  group('DM Linked Character Sheet & Modification Tests', () {
    testWidgets('DM Dashboard renders linked character vitality tile with open sheet button', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hero = _createSampleHero(id: 'hero_gandalf', name: 'Gandalf the Gray', currentHp: 32);
      await CharacterPersistenceService().saveCharacter(hero);

      final profile = CampaignProfile.defaultProfile(
        id: 'camp_dm_sheet_1',
        name: 'Fellowship Campaign',
      ).copyWith(partyCharacterIds: [hero.id.slug]);

      await CampaignProfileService().saveProfileImmediate(profile);
      await CampaignProfileService().switchProfile(profile.id);

      await tester.pumpWidget(_buildTestApp(home: const DmDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Gandalf the Gray'), findsOneWidget);
      expect(find.text('32 HP'), findsOneWidget);
      expect(find.byTooltip('Open Full Sheet (DM Mode)'), findsOneWidget);
    });

    testWidgets('Tapping sheet icon opens CharacterSheetView in DM Mode and reflects back on return', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hero = _createSampleHero(id: 'hero_aragorn', name: 'Aragorn', currentHp: 40);
      await CharacterPersistenceService().saveCharacter(hero);

      final profile = CampaignProfile.defaultProfile(
        id: 'camp_dm_sheet_2',
        name: 'Rangers Campaign',
      ).copyWith(partyCharacterIds: [hero.id.slug]);

      await CampaignProfileService().saveProfileImmediate(profile);
      await CampaignProfileService().switchProfile(profile.id);

      await tester.pumpWidget(_buildTestApp(home: const DmDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aragorn'), findsOneWidget);
      expect(find.text('40 HP'), findsOneWidget);

      // Tap to open sheet
      await tester.tap(find.byTooltip('Open Full Sheet (DM Mode)'));
      await tester.pumpAndSettle();

      // Verify we are in CharacterSheetView with DM Mode chip
      expect(find.byType(CharacterSheetView), findsOneWidget);
      expect(find.text('DM Mode'), findsOneWidget);
      expect(find.text('Aragorn'), findsAtLeast(1));

      // Pop back using the back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Back on DM Dashboard
      expect(find.byType(CharacterSheetView), findsNothing);
      expect(find.text('Aragorn'), findsOneWidget);
    });

    testWidgets('DM Dashboard allows linking existing saved character from library', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Save a hero in persistence that is NOT yet in the campaign
      final hero = _createSampleHero(id: 'hero_legolas', name: 'Legolas Greenleaf', currentHp: 28);
      await CharacterPersistenceService().saveCharacter(hero);

      final profile = CampaignProfile.defaultProfile(
        id: 'camp_dm_sheet_3',
        name: 'Elven Campaign',
      ).copyWith(partyCharacterIds: []);

      await CampaignProfileService().saveProfileImmediate(profile);
      await CampaignProfileService().switchProfile(profile.id);

      await tester.pumpWidget(_buildTestApp(home: const DmDashboardScreen()));
      await tester.pumpAndSettle();

      // Open Add character dialog
      await tester.tap(find.byTooltip('Add Party Member'));
      await tester.pumpAndSettle();

      expect(find.text('Add Character to Party Roster'), findsOneWidget);
      expect(find.text('Existing'), findsOneWidget);
      expect(find.text('Link Selected Character'), findsOneWidget);

      // Click link selected character
      await tester.tap(find.text('Link Selected Character'));
      await tester.pumpAndSettle();

      // Verify character is now in the DM dashboard party roster
      expect(find.text('Legolas Greenleaf'), findsOneWidget);
      expect(find.text('28 HP'), findsOneWidget);

      final updatedProfile = await CampaignProfileService().getActiveProfile();
      expect(updatedProfile.partyCharacterIds, contains('hero_legolas'));
    });

    testWidgets('PartyRoomScreen shows Sheet button and opens CharacterSheetView for active character', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hero = _createSampleHero(id: 'hero_gimli', name: 'Gimli', currentHp: 50);
      await CharacterPersistenceService().saveCharacter(hero);

      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Moria Expedition',
        playerName: 'Gimli',
        customRoomCode: 'DWARF1',
      );
      await partyService.linkCharacterToCampaign(
        roomCode: 'DWARF1',
        character: hero,
        existingRosterName: 'Gimli',
      );

      await tester.pumpWidget(_buildTestApp(
        home: PartyRoomScreen(
          roomCode: 'DWARF1',
          initialPlayerName: 'Gimli',
          partyService: partyService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Gimli'), findsAtLeast(1));
      expect(find.text('Sheet'), findsOneWidget);

      // Tap Sheet
      await tester.tap(find.text('Sheet'));
      await tester.pumpAndSettle();

      // CharacterSheetView is open
      expect(find.byType(CharacterSheetView), findsOneWidget);

      // Navigate back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterSheetView), findsNothing);
      expect(find.text('Gimli'), findsAtLeast(1));
    });
  });
}
