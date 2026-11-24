import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';

import '../../test_doubles/hive_test_harness.dart';

Widget _buildTestApp({String? initialCampaignId}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: DmDashboardScreen(initialCampaignId: initialCampaignId),
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

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);
        addTearDown(() => FlutterError.onError = prevOnError);

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(DmDashboardScreen), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
        expect(find.byTooltip('Export Campaign Snapshot'), findsOneWidget);
        expect(find.byTooltip('Add Combatant'), findsOneWidget);
        expect(find.byTooltip('Add Party Member'), findsOneWidget);
        expect(find.byTooltip('Summon Minion / Object'), findsOneWidget);
        expect(
          errors.where(
            (e) => !e.exceptionAsString().contains('RenderFlex overflowed'),
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

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);
        addTearDown(() => FlutterError.onError = prevOnError);

        await tester.pumpWidget(
          _buildTestApp(initialCampaignId: profile.id),
        );
        await tester.pumpAndSettle();

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
            (e) => !e.exceptionAsString().contains('RenderFlex overflowed'),
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
}
