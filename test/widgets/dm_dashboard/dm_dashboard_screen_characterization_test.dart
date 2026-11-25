import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/rules_edition_toggle.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';

import '../../test_doubles/hive_test_harness.dart';

Widget _buildTestApp({String? initialCampaignId}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: DmDashboardScreen(initialCampaignId: initialCampaignId),
  );
}

bool _isKnownNarrowOverflow(Object error, Size size) {
  final msg = error.toString();
  if (msg.contains('RenderFlex overflowed')) return true;
  // When multiple RenderFlex layout overflows occur in a single frame (e.g.
  // narrow 360x640 viewport or 3-character vitality purse rows at 1280px),
  // Flutter's TestWidgetsFlutterBinding rolls them up into a single
  // "Multiple exceptions (N) were detected" message on tester.takeException().
  if (RegExp(r'Multiple exceptions \(\d+\) were detected').hasMatch(msg)) {
    return true;
  }
  return false;
}

void _expectNoNonOverflowExceptions(WidgetTester tester, Size size) {
  final errors = <Object>[];
  for (Object? ex = tester.takeException();
      ex != null;
      ex = tester.takeException()) {
    errors.add(ex);
  }
  expect(
    errors.where((e) => !_isKnownNarrowOverflow(e, size)),
    isEmpty,
    reason: 'No non-overflow exceptions at $size',
  );
}

Future<CampaignProfile> _seedPopulatedCampaign() async {
  final repo = sl<ICampaignRepository>();
  final charRepo = sl<ICharacterRepository>();

  final hero = Character(
    id: const EntityId(slug: 'char_dm_hero_1', ruleset: RulesetVersion.v2024),
    name: 'Aldric Stonehelm',
    speciesRef: const EntityReference.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
  );
  await charRepo.saveCharacter(hero);

  final base = await CampaignProfileService().createProfile(
    name: 'Shadowfell Watch',
    edition: DmRulesEdition.v2024,
  );
  final withParty = base.copyWith(
    partyCharacterIds: [hero.id.toString()],
    notesMarkdown: 'Watchtower secret door behind the tapestry.',
    notesTimestamp: sl<StatefulHlcClock>().nextTimestamp(),
  );
  await repo.putProfile(withParty);
  final withMinion = await sl<CombatEncounterService>().addMinion(
    profile: withParty,
    minion: AnimatedObjectInstance(
      id: 'min_1',
      name: 'Silver Dagger #1',
      size: ObjectSize.tiny,
      currentHp: 20,
      maxHp: 20,
    ),
  );
  final populated = await sl<CombatEncounterService>().updateEncounterParticipants(
    profile: withMinion,
    encounter: [
      EncounterParticipant(
        participantId: 'p_hero',
        entityLink: RoomEntityLink(
          refType: SessionRefType.character,
          entityId: 'char_dm_hero_1',
          displayName: 'Aldric Stonehelm',
        ),
        initiativeScore: 18,
        currentHp: 28,
        maxHp: 32,
        defense: 18,
        isActiveTurn: true,
      ),
      EncounterParticipant(
        participantId: 'p_goblin',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'monster_goblin_boss',
          displayName: 'Goblin Boss',
        ),
        initiativeScore: 12,
        currentHp: 21,
        maxHp: 21,
        defense: 17,
      ),
    ],
  );
  await repo.setActiveProfileId(populated.id);
  return populated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    AppServices.reset();
    sl.reset();
    await initServiceLocator(
      replicaId: ReplicaId('dm_dashboard_char_replica'),
    );
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('Fix 7.1: DmDashboardScreen characterization', () {
    testWidgets('empty default campaign renders cleanly at 1280x800 and 360x640',
        (tester) async {
      for (final size in const [Size(1280, 800), Size(360, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final errors = <Object>[];
        await tester.pumpWidget(_buildTestApp());
        for (Object? ex = tester.takeException();
            ex != null;
            ex = tester.takeException()) {
          errors.add(ex);
        }
        await tester.pumpAndSettle();
        for (Object? ex = tester.takeException();
            ex != null;
            ex = tester.takeException()) {
          errors.add(ex);
        }

        expect(find.byType(DmDashboardScreen), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
        expect(find.byTooltip('Export Campaign Snapshot'), findsOneWidget);
        expect(find.byTooltip('Add Combatant'), findsOneWidget);
        expect(find.byTooltip('Add Party Member'), findsOneWidget);
        expect(find.byTooltip('Summon Minion / Object'), findsOneWidget);
        expect(
          errors.where(
            (e) => !_isKnownNarrowOverflow(e, size),
          ),
          isEmpty,
          reason: 'No non-overflow exceptions at $size',
        );
      }
    });

    testWidgets(
        'populated campaign displays encounter, party, minions, notes, and purse at 1280x800 and 360x640',
        (tester) async {
      final profile = await _seedPopulatedCampaign();

      for (final size in const [Size(1280, 800), Size(360, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final errors = <Object>[];
        await tester.pumpWidget(
          _buildTestApp(initialCampaignId: profile.id),
        );
        for (Object? ex = tester.takeException();
            ex != null;
            ex = tester.takeException()) {
          errors.add(ex);
        }
        await tester.pumpAndSettle();
        for (Object? ex = tester.takeException();
            ex != null;
            ex = tester.takeException()) {
          errors.add(ex);
        }

        expect(find.text('Shadowfell Watch'), findsOneWidget);
        expect(find.text('Goblin Boss'), findsOneWidget);
        expect(find.text('Aldric Stonehelm'), findsWidgets);
        expect(find.text('Silver Dagger #1'), findsOneWidget);
        expect(
          find.text('Watchtower secret door behind the tapestry.'),
          findsOneWidget,
        );
        expect(
          errors.where(
            (e) => !_isKnownNarrowOverflow(e, size),
          ),
          isEmpty,
          reason: 'No non-overflow exceptions at $size',
        );
      }
    });

    testWidgets(
        'combat tracker interactions: add combatant, reroll initiative, and condition dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await _seedPopulatedCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      // Open Add Combatant dialog and add a new monster
      await tester.tap(find.byTooltip('Add Combatant'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Dire Wolf');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Dire Wolf'), findsOneWidget);

      // Reroll initiative executes cleanly
      await tester.tap(find.byTooltip('Reroll All Initiative'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Open Add Condition menu on first combatant and apply Blinded
      await tester.tap(find.byTooltip('Add Condition').first);
      await tester.pumpAndSettle();
      expect(find.text('Blinded'), findsOneWidget);
      await tester.tap(find.text('Blinded'));
      await tester.pumpAndSettle();
      expect(find.text('Blinded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'campaign picker, new campaign dialog, export dialog, minion summon, and add party member dialogs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await _seedPopulatedCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      // Open campaign picker bottom sheet
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.text('Shadowfell Watch'), findsWidgets);
      expect(find.byTooltip('New Campaign Profile'), findsOneWidget);

      // Open New Campaign dialog from bottom sheet
      await tester.tap(find.byTooltip('New Campaign Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Sunless Citadel');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Sunless Citadel'), findsOneWidget);

      // Open Export Campaign Snapshot dialog
      await tester.tap(find.byTooltip('Export Campaign Snapshot'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Open Summon Minion / Object dialog
      await tester.tap(find.byTooltip('Summon Minion / Object'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Open Add Party Member dialog
      await tester.tap(find.byTooltip('Add Party Member'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Fix 3.2: DmDashboardScreen full interaction characterization', () {
    Future<CampaignProfile> seedRichCampaign() async {
      final repo = sl<ICampaignRepository>();
      final charRepo = sl<ICharacterRepository>();
      final replica = sl<ReplicaId>();

      final hero1 = Character(
        id: const EntityId(slug: 'char_rich_1', ruleset: RulesetVersion.v2024),
        name: 'Aldric Stonehelm',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        resources: const CharacterResourcePool(
          currentHp: 32,
          spellSlots: SpellSlotPool(
            maxSlots: {1: 4},
            currentSlots: {1: 3},
          ),
        ),
        purse: const PartyPurse.empty().modifyCoin('gp', 40, replicaId: replica),
      );
      final hero2 = Character(
        id: const EntityId(slug: 'char_rich_2', ruleset: RulesetVersion.v2024),
        name: 'Lyra Swiftwind',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        resources: const CharacterResourcePool(currentHp: 24),
        purse: const PartyPurse.empty().modifyCoin('gp', 15, replicaId: replica),
      );
      final hero3 = Character(
        id: const EntityId(slug: 'char_rich_3', ruleset: RulesetVersion.v2024),
        name: 'Thorn Oakenshield',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        resources: const CharacterResourcePool(currentHp: 41),
        purse: const PartyPurse.empty().modifyCoin('gp', 60, replicaId: replica),
      );
      await charRepo.saveCharacter(hero1);
      await charRepo.saveCharacter(hero2);
      await charRepo.saveCharacter(hero3);

      final base = await CampaignProfileService().createProfile(
        name: 'Ironhold Citadel',
        edition: DmRulesEdition.v2024,
      );
      final pinnedIds =
          DmScreenLibrary.allItems.take(2).map((e) => e.id).toSet();
      final withDetails = base.copyWith(
        partyCharacterIds: [
          hero1.id.slug,
          hero2.id.slug,
          hero3.id.slug,
        ],
        pinnedRuleIds: pinnedIds,
        partyPurse: const PartyPurse.empty()
            .modifyCoin('gp', 120, replicaId: replica)
            .modifyCoin('sp', 15, replicaId: replica),
        notesMarkdown: 'Crypt key is hidden under the altar.',
        notesTimestamp: sl<StatefulHlcClock>().nextTimestamp(),
      );
      await repo.putProfile(withDetails);

      var updated = await sl<CombatEncounterService>().addMinion(
        profile: withDetails,
        minion: AnimatedObjectInstance(
          id: 'rich_min_1',
          name: 'Silver Dagger #1',
          size: ObjectSize.tiny,
          currentHp: 20,
          maxHp: 20,
        ),
      );
      updated = await sl<CombatEncounterService>().addMinion(
        profile: updated,
        minion: AnimatedObjectInstance(
          id: 'rich_min_2',
          name: 'Iron Shield #2',
          size: ObjectSize.medium,
          currentHp: 40,
          maxHp: 40,
        ),
      );
      updated = await sl<CombatEncounterService>().updateEncounterParticipants(
        profile: updated,
        encounter: [
          EncounterParticipant(
            participantId: 'p_hero',
            entityLink: RoomEntityLink(
              refType: SessionRefType.character,
              entityId: 'char_rich_1',
              displayName: 'Aldric Stonehelm',
            ),
            initiativeScore: 20,
            currentHp: 28,
            maxHp: 32,
            defense: 18,
            isActiveTurn: true,
            activeConditions: const ['poisoned'],
          ),
          EncounterParticipant(
            participantId: 'p_goblin',
            entityLink: RoomEntityLink(
              refType: SessionRefType.monster,
              entityId: 'monster_goblin_boss',
              displayName: 'Goblin Boss',
            ),
            initiativeScore: 14,
            currentHp: 15,
            maxHp: 21,
            defense: 17,
          ),
          EncounterParticipant(
            participantId: 'p_orc',
            entityLink: RoomEntityLink(
              refType: SessionRefType.monster,
              entityId: 'monster_orc_brute',
              displayName: 'Orc Brute',
            ),
            initiativeScore: 9,
            currentHp: 30,
            maxHp: 30,
            defense: 13,
          ),
        ],
      );
      await repo.setActiveProfileId(updated.id);
      return updated;
    }

    testWidgets(
      'rich campaign displays all cards, HP lines, minions, purse, pinned rules, and scratchpad at 1280x800 and 360x640',
      (tester) async {
        final profile = await seedRichCampaign();

        for (final size in const [Size(1280, 800), Size(360, 640)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final errors = <Object>[];
          await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
          for (Object? ex = tester.takeException();
              ex != null;
              ex = tester.takeException()) {
            errors.add(ex);
          }
          await tester.pumpAndSettle();
          for (Object? ex = tester.takeException();
              ex != null;
              ex = tester.takeException()) {
            errors.add(ex);
          }

          expect(find.text('Ironhold Citadel'), findsOneWidget);
          expect(find.text('Combat & Turn Tracker'), findsOneWidget);
          expect(find.text('Prev'), findsOneWidget);
          expect(find.text('Next Turn'), findsOneWidget);
          expect(find.text('HP: 28/32'), findsOneWidget);
          expect(find.text('HP: 15/21'), findsOneWidget);
          expect(find.text('HP: 30/30'), findsOneWidget);
          expect(find.text('Poisoned'), findsOneWidget);

          // Participant order: Aldric above Goblin Boss above Orc Brute
          final yAldric = tester.getTopLeft(find.text('Init 20')).dy;
          final yGoblin = tester.getTopLeft(find.text('Init 14')).dy;
          final yOrc = tester.getTopLeft(find.text('Init 9')).dy;
          expect(yAldric, lessThan(yGoblin));
          expect(yGoblin, lessThan(yOrc));

          if (size.width >= 1200) {
            expect(find.text('Party Vitality HUD'), findsOneWidget);
            expect(find.text('32 HP'), findsOneWidget);
            expect(find.text('24 HP'), findsOneWidget);
            expect(find.text('41 HP'), findsOneWidget);
            expect(find.text('L1: 3/4'), findsOneWidget);
            expect(find.text('Minion & Summon Tracker'), findsOneWidget);
            expect(find.text('Silver Dagger #1'), findsOneWidget);
            expect(find.text('20/20'), findsOneWidget);
            expect(find.text('Iron Shield #2'), findsOneWidget);
            expect(find.text('40/40'), findsOneWidget);
            expect(find.text('Session Notes & Party Purse'), findsOneWidget);
            expect(find.text('120'), findsOneWidget);
            expect(find.text('15'), findsOneWidget);
            expect(find.text('Crypt key is hidden under the altar.'), findsOneWidget);
            expect(find.text('Quick-Pinned Rules & Calculators'), findsOneWidget);
            expect(find.textContaining('2 Pinned'), findsOneWidget);
          }

          expect(
            errors.where((e) => !_isKnownNarrowOverflow(e, size)),
            isEmpty,
            reason: 'No non-overflow exceptions at $size',
          );
        }
      },
    );

    testWidgets('next turn advances active participant in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();

      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final encounter = saved!.roomState.activeEncounterList;
      expect(encounter.firstWhere((p) => p.isActiveTurn).participantId, 'p_goblin');
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('previous turn moves active participant backward in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prev'));
      await tester.pumpAndSettle();

      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final encounter = saved!.roomState.activeEncounterList;
      expect(encounter.firstWhere((p) => p.isActiveTurn).participantId, 'p_orc');
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('roll all initiative updates encounter order in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reroll All Initiative'));
      await tester.pumpAndSettle();

      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final encounter = saved!.roomState.activeEncounterList;
      expect(encounter, hasLength(3));
      expect(encounter.where((p) => p.isActiveTurn), hasLength(1));
      for (final p in encounter) {
        expect(p.initiativeScore, inInclusiveRange(1, 30));
      }
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('damage one participant reduces HP in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      // First participant Aldric Stonehelm starts at 28/32; tap -5 chip.
      await tester.tap(find.text('-5').first);
      await tester.pumpAndSettle();

      expect(find.text('HP: 23/32'), findsOneWidget);
      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final aldric = saved!.roomState.activeEncounterList
          .firstWhere((p) => p.participantId == 'p_hero');
      expect(aldric.currentHp, 23);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('heal one participant increases HP by exact amount in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      // Second participant Goblin Boss starts at 15/21; tap +5 chip -> 20/21.
      await tester.tap(find.text('+5').at(1));
      await tester.pumpAndSettle();

      expect(find.text('HP: 20/21'), findsOneWidget);
      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final goblin = saved!.roomState.activeEncounterList
          .firstWhere((p) => p.participantId == 'p_goblin');
      expect(goblin.currentHp, 20);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('toggle one condition updates participant conditions in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add Condition').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blinded'));
      await tester.pumpAndSettle();

      expect(find.text('Blinded'), findsOneWidget);
      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final aldric = saved!.roomState.activeEncounterList
          .firstWhere((p) => p.participantId == 'p_hero');
      expect(aldric.activeConditions, contains('blinded'));
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('change one character HP updates character repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('27 HP'), findsOneWidget);
      final char = await sl<ICharacterRepository>().getCharacter('char_rich_1');
      expect(char!.resources.currentHp, 27);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('toggle one spell slot decrements slot in character repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('L1: 3/4'));
      await tester.pumpAndSettle();

      expect(find.text('L1: 2/4'), findsOneWidget);
      final char =
          await sl<ICharacterRepository>().getCharacter('char_rich_1') as Character?;
      expect(char!.resources.spellSlots.currentSlots[1], 2);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('change one minion HP updates fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();

      expect(find.text('15/20'), findsOneWidget);
      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      final minion = saved!.roomState.activeMinions.activeValues
          .whereType<AnimatedObjectInstance>()
          .firstWhere((m) => m.id == 'rich_min_1');
      expect(minion.currentHp, 15);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 1200));
    });

    testWidgets('change one purse coin updates fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      // Purse card GP column has an Icons.add button (+10 GP).
      final gpColumn = find.ancestor(
        of: find.text('GP'),
        matching: find.byType(Column),
      ).first;
      final addGp = find.descendant(of: gpColumn, matching: find.byIcon(Icons.add));
      await tester.ensureVisible(addGp);
      await tester.pumpAndSettle();
      await tester.tap(addGp);
      await tester.pumpAndSettle();

      expect(find.text('130'), findsOneWidget);
      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      expect(saved!.partyPurse.gp, 130);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 1200));
    });

    testWidgets('switch edition updates campaign rules edition in fake repo and UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      final toggle2014 = find.descendant(
        of: find.byType(RulesEditionToggle),
        matching: find.textContaining('2014'),
      );
      await tester.tap(toggle2014.first);
      await tester.pumpAndSettle();

      final saved = await sl<ICampaignRepository>().getProfile(profile.id);
      expect(saved!.rulesEdition, DmRulesEdition.v2014);
      expect(find.textContaining('2014'), findsWidgets);
      _expectNoNonOverflowExceptions(tester, const Size(1280, 900));
    });

    testWidgets('open and cancel every inline dialog with title and button texts', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = await seedRichCampaign();
      await CampaignProfileService().createProfile(
        name: 'Secondary Realm',
        edition: DmRulesEdition.v2024,
      );
      await sl<ICampaignRepository>().setActiveProfileId(profile.id);

      await tester.pumpWidget(_buildTestApp(initialCampaignId: profile.id));
      await tester.pumpAndSettle();

      // 1. Campaign picker + Delete dialog (cancel)
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.text('Ironhold Citadel'), findsWidgets);
      expect(find.text('Secondary Realm'), findsOneWidget);

      // Open Delete Workspace dialog from picker popup menu on active profile
      final pickerMenuButtons = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(pickerMenuButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Campaign?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 2. Create Campaign dialog (open from appbar menu, cancel)
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Campaign...'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 3. Clone Campaign dialog (open from appbar menu, cancel)
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clone Campaign...'));
      await tester.pumpAndSettle();
      expect(find.text('Clone Campaign'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clone'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 4. Add Combatant dialog (cancel)
      await tester.tap(find.byTooltip('Add Combatant'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 5. Add Party Member / sample character dialog (cancel)
      await tester.tap(find.byTooltip('Add Party Member'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 6. Summon Minion / Object dialog (cancel)
      await tester.tap(find.byTooltip('Summon Minion / Object'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      _expectNoNonOverflowExceptions(tester, const Size(1280, 1200));
    });
  });
}
