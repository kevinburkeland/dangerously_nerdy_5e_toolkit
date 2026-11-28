import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

void main() {
  test('all 5 AppDatabaseService boxes recorded with hive_flutter open and round-trip cleanly', () async {
    final fixtureDir = Directory('test/fixtures/hive_v1_compat');
    expect(fixtureDir.existsSync(), isTrue);

    final tempDir = Directory.systemTemp.createTempSync('hive_v1_compat_');
    try {
      for (final boxName in const [
        AppDatabaseService.boxCharacters,
        AppDatabaseService.boxCampaignProfiles,
        AppDatabaseService.boxHomebrew,
        AppDatabaseService.boxHomebrewRaw,
        AppDatabaseService.boxMetadata,
      ]) {
        final src = File('${fixtureDir.path}/$boxName.hive');
        expect(src.existsSync(), isTrue, reason: 'Missing fixture ${src.path}');
        src.copySync('${tempDir.path}/$boxName.hive');
      }

      await Hive.close();
      final db = AppDatabaseService.custom(
        hiveInit: () async => Hive.init(tempDir.path),
        hiveBoxOpener: Hive.openBox<dynamic>,
      );
      await db.init();

      expect(
        db.get(AppDatabaseService.boxCharacters, 'char_1'),
        equals({
          'id': 'char_1',
          'name': 'Elara',
          'level': 5,
          'tags': ['srd', 'wizard'],
        }),
      );
      expect(
        db.get(AppDatabaseService.boxCampaignProfiles, 'ROOM1'),
        equals({
          'roomCode': 'ROOM1',
          'schemaVersion': 2,
          'purse': {'gp': 42},
        }),
      );
      expect(
        db.get(AppDatabaseService.boxHomebrew, 'spell_1'),
        equals({'id': 'spell_1', 'name': 'Spark', 'level': 1}),
      );
      expect(
        db.get(AppDatabaseService.boxHomebrewRaw, 'raw_1'),
        equals('{"name":"Spark"}'),
      );
      expect(
        db.get(AppDatabaseService.boxMetadata, 'schema_version'),
        equals(19),
      );
      expect(
        db.get(AppDatabaseService.boxMetadata, 'migrated'),
        isTrue,
      );

      // Write new records, close, and reopen to verify read/write compatibility.
      await db.put(AppDatabaseService.boxMetadata, 'after_open', 'ok');
      await Hive.close();

      final db2 = AppDatabaseService.custom(
        hiveInit: () async => Hive.init(tempDir.path),
        hiveBoxOpener: Hive.openBox<dynamic>,
      );
      await db2.init();
      expect(
        db2.get(AppDatabaseService.boxMetadata, 'schema_version'),
        equals(19),
      );
      expect(
        db2.get(AppDatabaseService.boxMetadata, 'after_open'),
        equals('ok'),
      );
      await Hive.close();
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
