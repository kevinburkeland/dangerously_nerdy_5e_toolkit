import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {}
    AppDatabaseService.instance = AppDatabaseService();
    sl.reset();
  });

  group('Cold Iron Pass 11: Storage Failure Suite', () {
    test('S1: init where Hive init function throws: init() throws StorageUnavailableException; isInitialized is false', () async {
      final db = AppDatabaseService.custom(
        hiveInit: () async => throw Exception('Disk quota exceeded / IndexedDB blocked'),
        hiveBoxOpener: (name) async => throw UnimplementedError(),
      );

      await expectLater(
        () => db.init(),
        throwsA(isA<StorageUnavailableException>()),
      );
      expect(db.isInitialized, isFalse);
    });

    test('S2: init where exactly one of the five boxes fails to open throws StorageUnavailableException', () async {
      const boxes = [
        AppDatabaseService.boxCharacters,
        AppDatabaseService.boxCampaignProfiles,
        AppDatabaseService.boxHomebrew,
        AppDatabaseService.boxHomebrewRaw,
        AppDatabaseService.boxMetadata,
      ];

      for (final failingBox in boxes) {
        final tempDir = await Directory.systemTemp.createTemp('s2_');
        final db = AppDatabaseService.custom(
          hiveInit: () async => Hive.init(tempDir.path),
          hiveBoxOpener: (name) async {
            if (name == failingBox) {
              throw Exception('Corrupt box $name');
            }
            return Hive.openBox<dynamic>(name);
          },
        );

        await expectLater(
          () => db.init(),
          throwsA(isA<StorageUnavailableException>()),
          reason: 'Expected init() to throw when $failingBox fails to open',
        );
        expect(db.isInitialized, isFalse);

        await Hive.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('S3: after a failed init, each read/write method throws StorageUnavailableException', () async {
      final db = AppDatabaseService.custom(
        hiveInit: () async => throw Exception('IndexedDB unavailable'),
        hiveBoxOpener: (name) async => throw UnimplementedError(),
      );

      try {
        await db.init();
      } catch (_) {}
      expect(db.isInitialized, isFalse);

      expect(() => db.get(AppDatabaseService.boxCharacters, 'key'),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.put(AppDatabaseService.boxCharacters, 'key', 'val'),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.putAll(AppDatabaseService.boxCharacters, {'key': 'val'}),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.delete(AppDatabaseService.boxCharacters, 'key'),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.deleteAll(AppDatabaseService.boxCharacters, ['key']),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.getKeys(AppDatabaseService.boxCharacters),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.getValues(AppDatabaseService.boxCharacters),
          throwsA(isA<StorageUnavailableException>()));
      expect(() => db.clearBox(AppDatabaseService.boxCharacters),
          throwsA(isA<StorageUnavailableException>()));
    });

    test('S4: after a failed init, LocalCampaignRepository.putProfile and LocalCharacterRepository save throw', () async {
      final db = AppDatabaseService.custom(
        hiveInit: () async => throw Exception('IndexedDB blocked'),
        hiveBoxOpener: (name) async => throw UnimplementedError(),
      );
      try {
        await db.init();
      } catch (_) {}
      AppDatabaseService.instance = db;

      final repId = ReplicaId('node_test');
      final clock = StatefulHlcClock(replicaId: repId);
      final charRepo = LocalCharacterRepository(db: db);
      final campRepo = LocalCampaignRepository(
        replicaId: repId,
        clock: clock,
        characterRepo: charRepo,
        db: db,
      );

      final profile = CampaignProfile(
        id: 'camp_1',
        name: 'Camp 1',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r1', roomCode: 'ROOM1', title: 't1'),
        nodeId: 'node_test',
      );

      await expectLater(
        () => campRepo.putProfile(profile),
        throwsA(anything),
      );

      const character = Character(
        id: EntityId(slug: 'hero', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
      );

      await expectLater(
        () => charRepo.saveCharacter(character),
        throwsA(anything),
      );
    });

    test('S5: failed init followed by successful init leaves service usable', () async {
      bool shouldFail = true;
      final tempDir = await Directory.systemTemp.createTemp('s5_');
      final db = AppDatabaseService.custom(
        hiveInit: () async {
          if (shouldFail) {
            throw Exception('Temporary lock');
          }
          Hive.init(tempDir.path);
        },
        hiveBoxOpener: (name) async {
          if (shouldFail) {
            throw Exception('Temporary lock');
          }
          return Hive.openBox<dynamic>(name);
        },
      );

      await expectLater(
        () => db.init(),
        throwsA(isA<StorageUnavailableException>()),
      );
      expect(db.isInitialized, isFalse);

      // Now fix seam
      shouldFail = false;
      await db.init();
      expect(db.isInitialized, isTrue);

      await db.put(AppDatabaseService.boxMetadata, 'test_key', 'test_value');
      expect(db.get(AppDatabaseService.boxMetadata, 'test_key'), equals('test_value'));

      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('S6 (widget): openStorage with failing db shows Storage unavailable page and does not run setup; Try again works', (tester) async {
      bool shouldFail = true;
      final db = AppDatabaseService.custom(
        hiveInit: () async {
          if (shouldFail) {
            throw const StorageUnavailableException('Blocked storage');
          }
        },
        hiveBoxOpener: (name) async {
          if (shouldFail) {
            throw const StorageUnavailableException('Blocked storage');
          }
          return _FakeBox();
        },
      );

      bool setupRan = false;
      final storageResult = await openStorage(db);
      expect(storageResult.isSuccess, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: StorageUnavailablePage(
            databaseService: db,
            onRetrySuccess: () async {
              setupRan = true;
            },
          ),
        ),
      );

      expect(find.text('Storage unavailable'), findsOneWidget);
      expect(
        find.textContaining('The browser would not let the app save data'),
        findsOneWidget,
      );
      expect(
        find.textContaining(RegExp(r'private browsing', caseSensitive: false)),
        findsOneWidget,
      );
      expect(
        find.textContaining(RegExp(r'disk full', caseSensitive: false)),
        findsOneWidget,
      );
      expect(setupRan, isFalse);

      // Now fix seam and press Try again
      shouldFail = false;
      final tryAgainFinder = find.byKey(const Key('storage_unavailable_try_again_button'));
      await tester.tap(tryAgainFinder);
      await tester.pump();
      await tester.pump();

      expect(setupRan, isTrue);
    });

    test('Control: with real Hive in temp dir, put survives Hive.close() and reopening box', () async {
      final harness = HiveTestHarness();
      await harness.setUp('control_');

      await AppDatabaseService.instance.put(
        AppDatabaseService.boxMetadata,
        'control_key',
        'surviving_value',
      );

      final path = harness.tempDir.path;
      await Hive.close();

      // Reopen
      Hive.init(path);
      final reopenedBox = await Hive.openBox<dynamic>(AppDatabaseService.boxMetadata);
      expect(reopenedBox.get('control_key'), equals('surviving_value'));

      await harness.tearDown();
    });
  });
}

class _FakeBox extends Fake implements Box<dynamic> {}
