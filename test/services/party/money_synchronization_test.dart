import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

Widget _buildTestApp({required Widget home}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: home,
  );
}

Character _createHeroWithPurse({required String id, required String name, required PartyPurse purse}) {
  return Character(
    id: EntityId(slug: id, ruleset: RulesetVersion.v2024),
    name: name,
    speciesRef: const EntityReference(slug: 'human', refType: EntityType.species, displayName: 'Human'),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference(slug: 'fighter', refType: EntityType.classDefinition, displayName: 'Fighter'),
          level: 3,
          hitDie: 'd10',
          isStartingClass: true,
        ),
      ],
    ),
    baseScores: const AbilityScores.standardArray(),
    resources: const CharacterResourcePool(currentHp: 25),
    purse: purse,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.reset();
  });

  group('Money Synchronization Tests', () {
    test('CharacterSheetController modifies purse and persists changes', () async {
      final hero = _createHeroWithPurse(
        id: 'hero_purse_1',
        name: 'Gimli Goldfinger',
        purse: const PartyPurse(gp: 50, sp: 20),
      );
      final persistence = CharacterPersistenceService();
      await persistence.saveCharacter(hero);

      final controller = CharacterSheetController(character: hero, persistenceService: persistence);
      expect(controller.character.purse.gp, equals(50));

      await controller.modifyPurseCoin('gp', 25);
      expect(controller.character.purse.gp, equals(75));

      await controller.flush();
      final loaded = await persistence.getCharacter('hero_purse_1');
      expect(loaded?.purse.gp, equals(75));
    });

    test('PartyRoomService.linkCharacterToCampaign initializes memberPurses from character.purse', () async {
      final hero = _createHeroWithPurse(
        id: 'hero_legolas',
        name: 'Legolas',
        purse: const PartyPurse(pp: 2, gp: 100, sp: 50),
      );
      final partyService = PartyRoomService();
      await partyService.createCampaign(
        campaignName: 'Lothlorien',
        playerName: 'DM',
        customRoomCode: 'LOTHO1',
      );

      final session = await partyService.linkCharacterToCampaign(
        roomCode: 'LOTHO1',
        character: hero,
        existingRosterName: 'Legolas',
      );

      // Verify session memberPurse has the character's exact money
      final memberPurse = session.getMemberPurse('Legolas');
      expect(memberPurse.gp, equals(100));
      expect(memberPurse.pp, equals(2));
      expect(memberPurse.sp, equals(50));
    });

    test('DmDashboardController separates shared party treasury from individual character purses', () async {
      final hero1 = _createHeroWithPurse(
        id: 'hero_aragorn',
        name: 'Aragorn',
        purse: const PartyPurse(gp: 40),
      );
      final hero2 = _createHeroWithPurse(
        id: 'hero_boromir',
        name: 'Boromir',
        purse: const PartyPurse(gp: 80),
      );
      final persistence = CharacterPersistenceService();
      await persistence.saveCharacter(hero1);
      await persistence.saveCharacter(hero2);

      final profileService = CampaignProfileService();
      final profile = CampaignProfile.defaultProfile(
        id: 'camp_gondor',
        name: 'Gondor Defense',
      ).copyWith(
        partyPurse: const PartyPurse(gp: 500),
        partyCharacterIds: [hero1.id.slug, hero2.id.slug],
      );
      await profileService.saveProfileImmediate(profile);
      await profileService.switchProfile(profile.id);

      final controller = DmDashboardController(
        campaignProfileService: profileService,
        characterPersistenceService: persistence,
      );
      await controller.loadData();

      // Shared treasury
      expect(controller.partyPurse.gp, equals(500));

      // Characters have their individual purses
      expect(controller.partyCharactersMap['hero_aragorn']?.purse.gp, equals(40));
      expect(controller.partyCharactersMap['hero_boromir']?.purse.gp, equals(80));

      // Total wealth is shared treasury + characters' wealth (500 + 40 + 80 = 620 GP)
      expect(controller.totalPartyWealth.gp, equals(620));

      // Modifying shared party purse does NOT alter character purses
      await controller.modifyPartyPurseCoin('gp', 50);
      expect(controller.partyPurse.gp, equals(550));
      expect(controller.partyCharactersMap['hero_aragorn']?.purse.gp, equals(40));

      // Modifying individual character purse
      await controller.modifyCharacterPurseCoin('hero_aragorn', 'gp', 10);
      expect(controller.partyCharactersMap['hero_aragorn']?.purse.gp, equals(50));
      expect(controller.partyPurse.gp, equals(550));

      final savedAragorn = await persistence.getCharacter('hero_aragorn');
      expect(savedAragorn?.purse.gp, equals(50));
    });

    testWidgets('DM Dashboard UI displays both character purse and shared treasury', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hero = _createHeroWithPurse(
        id: 'hero_frodo',
        name: 'Frodo Baggins',
        purse: const PartyPurse(gp: 25),
      );
      await CharacterPersistenceService().saveCharacter(hero);

      final profile = CampaignProfile.defaultProfile(
        id: 'camp_shire',
        name: 'Shire Journey',
      ).copyWith(
        partyPurse: const PartyPurse(gp: 150),
        partyCharacterIds: [hero.id.slug],
      );
      await CampaignProfileService().saveProfileImmediate(profile);
      await CampaignProfileService().switchProfile(profile.id);

      await tester.pumpWidget(_buildTestApp(home: const DmDashboardScreen()));
      await tester.pumpAndSettle();

      // Character card displays personal purse
      expect(find.text('Frodo Baggins'), findsOneWidget);
      expect(find.text('25 GP • ~25.0 GP eq'), findsOneWidget);

      // Shared Party Treasury displays treasury total
      expect(find.text('SHARED PARTY TREASURY (~150.0 GP)'), findsOneWidget);
      expect(find.text('~175.0 GP Total Wealth'), findsOneWidget);

      // Tap +10 GP on character card
      await tester.tap(find.text('+10 GP'));
      await tester.pumpAndSettle();

      expect(find.text('35 GP • ~35.0 GP eq'), findsOneWidget);
      final updatedHero = await CharacterPersistenceService().getCharacter('hero_frodo');
      expect(updatedHero?.purse.gp, equals(35));
    });
  });
}
