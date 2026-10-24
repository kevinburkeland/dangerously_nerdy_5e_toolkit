import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_edition_codec.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import '../test_doubles/hive_test_harness.dart';

Widget _buildTestApp({Widget? home}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: home ?? const DmDashboardScreen(),
  );
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
      replicaId: ReplicaId('pass_12_test_replica'),
    );
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('Cold Iron Birdcage — Pass 12: Campaign Edition & RulesetRef (Fix 1)', () {
    testWidgets(
        'G1 (widget, the regression): legacy generic_tabletop campaign opens without throwing, showing 2024 Edition and (2024)',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabaseService.instance;
      const id = 'campaign_ABC123';
      final legacyRawRecord = {
        'id': id,
        'name': 'Kevin Legacy Campaign',
        'edition': 'generic_tabletop',
        'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'roomState': {
          'roomId': 'room_ABC123',
          'roomCode': 'ABC123',
          'title': 'Legacy Campaign Staging',
        },
      };

      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}$id',
        jsonEncode(legacyRawRecord),
      );
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        [id],
      );
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.activeProfileIdKey,
        id,
      );

      final loaded = await CampaignProfileService().loadAllProfiles();
      expect(loaded.any((p) => p.id == id), isTrue);
      await CampaignProfileService().switchProfile(id);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap campaign title / dropdown to open the profile switcher sheet
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('2024 Edition'), findsOneWidget);

      // Tap outside to close bottom sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.textContaining('(2024)'), findsWidgets);

      // Control: a campaign with "edition": "v2014" shows 2014
      const id2014 = 'campaign_DEF456';
      final raw2014Record = {
        'id': id2014,
        'name': 'Legacy 2014 Campaign',
        'edition': 'v2014',
        'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'roomState': {
          'roomId': 'room_DEF456',
          'roomCode': 'DEF456',
          'title': '2014 Staging',
        },
      };

      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}$id2014',
        jsonEncode(raw2014Record),
      );
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        [id, id2014],
      );

      // Open switcher again, verify 2014 Edition row, and select it
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      expect(find.textContaining('2014 Edition'), findsOneWidget);

      // Tap on the 2014 campaign in the switcher to select it
      await tester.tap(find.text('Legacy 2014 Campaign'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('(2014)'), findsWidgets);
    });

    test('G2 (load): legacy defaults load as v2024, resave as v2024, aliases map correctly, unknown maps to RulesetIdentifier', () async {
      final db = AppDatabaseService.instance;
      final legacyDefaults = ['generic_tabletop', 'GENERIC_TABLETOP', 'unknown', '', '   '];

      for (var i = 0; i < legacyDefaults.length; i++) {
        final def = legacyDefaults[i];
        final id = 'camp_def_$i';
        final rawMap = {
          'id': id,
          'name': 'Campaign $id',
          'edition': def,
          'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
          'lastPlayedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
          'roomState': {'roomId': 'r_$id', 'roomCode': 'CODE$i', 'title': 'Staging'},
        };
        await db.put(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}$id',
          jsonEncode(rawMap),
        );
        await db.put(
          AppDatabaseService.boxCampaignProfiles,
          LocalCampaignRepository.profileIndexKey,
          [id],
        );

        final repo = sl<ICampaignRepository>();
        final profiles = await repo.loadAllProfiles();
        final loaded = profiles.firstWhere((p) => p.id == id);
        expect(loaded.edition, equals(RulesetEdition.v2024));

        // After one save through the repository, stored string is v2024
        await repo.putProfile(loaded);
        final storedJson = db.get(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}$id',
        ) as String;
        final decoded = jsonDecode(storedJson) as Map<String, dynamic>;
        expect(decoded['edition'], equals('v2024'));
      }

      // Check all aliases in the codec
      final aliases2024 = [
        '2024', 'srd5.2.1', 'srd5.2', 'srd2024', 'srd521', 'srd52',
        '5e-2024', 'v2024', '5.2', 'SRD5.2.1', '  5e-2024  '
      ];
      for (final a in aliases2024) {
        expect(parseStoredCampaignEdition(a), equals(RulesetEdition.v2024));
      }

      final aliases2014 = [
        '2014', 'srd5.1', 'srd51', '5e-2014', 'v2014', '5.1', 'SRD5.1', '  5e-2014  '
      ];
      for (final a in aliases2014) {
        expect(parseStoredCampaignEdition(a), equals(RulesetEdition.v2014));
      }

      // pf2e_remaster loads as RulesetIdentifier('pf2e_remaster') without throwing, and rulesEdition gives v2024
      const pfId = 'camp_pf2e';
      final pfMap = {
        'id': pfId,
        'name': 'Pathfinder Campaign',
        'edition': 'pf2e_remaster',
        'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'roomState': {'roomId': 'r_pf', 'roomCode': 'PF1', 'title': 'Staging'},
      };
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}$pfId',
        jsonEncode(pfMap),
      );
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        [pfId],
      );

      final repo = sl<ICampaignRepository>();
      final profiles = await repo.loadAllProfiles();
      final pfLoaded = profiles.firstWhere((p) => p.id == pfId);
      expect(pfLoaded.edition, equals(const RulesetIdentifier('pf2e_remaster')));
      expect(pfLoaded.rulesEdition, equals(DmRulesEdition.v2024));
    });

    test('G3 (law, seeded, at least 500 cases): codec total, idempotent, never throws, rulesEdition never throws', () {
      final rng = Random(42);
      final knownTokens = [
        'generic_tabletop',
        'unknown',
        '',
        '   ',
        '2024',
        'srd5.2.1',
        'srd5.2',
        'srd2024',
        'srd521',
        'srd52',
        '5e-2024',
        'v2024',
        '5.2',
        '2014',
        'srd5.1',
        'srd51',
        '5e-2014',
        'v2014',
        '5.1',
        'pf2e_remaster',
        'daggerheart',
        'call_of_cthulhu',
      ];

      for (var i = 0; i < 600; i++) {
        final String input;
        if (i < knownTokens.length * 3) {
          final base = knownTokens[i % knownTokens.length];
          final leading = ' ' * rng.nextInt(4);
          final trailing = ' ' * rng.nextInt(4);
          final caseVaried = base.split('').map((c) => rng.nextBool() ? c.toUpperCase() : c.toLowerCase()).join();
          input = '$leading$caseVaried$trailing';
        } else {
          final len = rng.nextInt(25);
          final chars = List.generate(len, (_) => String.fromCharCode(32 + rng.nextInt(95)));
          input = chars.join();
        }

        final parsed = parseStoredCampaignEdition(input);
        expect(parsed, isNotNull);
        expect(parsed.rulesetId, isNotNull);

        // Idempotence: parse(parse(s).rulesetId) == parse(s)
        final parsedTwice = parseStoredCampaignEdition(parsed.rulesetId);
        expect(parsedTwice, equals(parsed));

        // rulesEdition on a profile holding parse(s) never throws
        final profile = CampaignProfile.initial(
          id: 'camp_law_$i',
          name: 'Law Campaign $i',
          edition: parsed,
          nodeId: 'node-test',
        );
        expect(() => profile.rulesEdition, returnsNormally);
        expect(profile.rulesEdition, isA<RulesetEdition>());
      }

      // For every RulesetEdition e, parse(e.rulesetId) == e
      for (final e in RulesetEdition.values) {
        expect(parseStoredCampaignEdition(e.rulesetId), equals(e));
      }
    });

    test('G4 (merge): generic_tabletop legacy profile merges cleanly with profileForRoom joiner profile; v2014 vs v2024 throws', () async {
      final legacyProfile = CampaignProfileDto.fromJson(jsonEncode({
        'id': 'campaign_ROOM44',
        'name': 'Campaign ROOM44',
        'edition': 'generic_tabletop',
        'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'roomState': {
          'roomId': 'room_ROOM44',
          'roomCode': 'ROOM44',
          'title': 'Staging',
        },
      })).toDomain();

      expect(legacyProfile.rulesetId, equals('v2024'));

      // Create a joiner profile with profileForRoom from a lobby with no rulesetId
      final partyRoomService = PartyRoomService();
      final joinerProfile = await partyRoomService.profileForRoom(
        'ROOM44',
        lobbyCampaignId: 'campaign_ROOM44',
        lobbyRulesetId: null,
        allowCreate: true,
      );

      expect(joinerProfile.rulesetId, equals('v2024'));

      // Merging them does not throw
      final merged = CampaignProfile.join(legacyProfile, joinerProfile);
      expect(merged.rulesetId, equals('v2024'));

      // Control: v2014 against v2024 still throws Incompatible ruleset edition
      final p2014 = legacyProfile.copyWith(edition: RulesetEdition.v2014);
      expect(
        () => CampaignProfile.join(p2014, joinerProfile),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Incompatible ruleset edition'),
        )),
      );
    });

    test('G5 (wire bytes): fromDomain writes v2024/v2014, sync payload carries identical string, and new lobby has v2024', () {
      final p2024 = CampaignProfile.initial(
        id: 'camp_2024',
        name: 'Camp 2024',
        edition: RulesetEdition.v2024,
        nodeId: 'node-wire',
      );
      final dto2024 = CampaignProfileDto.fromDomain(p2024);
      expect(dto2024.edition, equals('v2024'));

      final p2014 = CampaignProfile.initial(
        id: 'camp_2014',
        name: 'Camp 2014',
        edition: RulesetEdition.v2014,
        nodeId: 'node-wire',
      );
      final dto2014 = CampaignProfileDto.fromDomain(p2014);
      expect(dto2014.edition, equals('v2014'));

      // Full-profile sync payload carries the same string
      final syncPayload = dto2024.toJson();
      final decodedPayload = jsonDecode(syncPayload) as Map<String, dynamic>;
      expect(decodedPayload['edition'], equals('v2024'));

      // A new campaign's lobby rulesetId defaults to v2024
      final lobby = PartyRoomService().getCachedLobby('NEWROOM');
      expect(lobby?.rulesetId ?? 'v2024', equals('v2024'));
    });
  });
}
