@TestOn('browser')
library;

import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  test('all 5 AppDatabaseService boxes open and persist in Chrome IndexedDB', () async {
    await Hive.close();
    final db = AppDatabaseService.custom(
      hiveInit: Hive.initFlutter,
      hiveBoxOpener: Hive.openBox<dynamic>,
    );
    await db.init();

    await db.put(AppDatabaseService.boxCharacters, 'c_web', {'name': 'Lyra'});
    await db.put(AppDatabaseService.boxCampaignProfiles, 'WEB1', {'roomCode': 'WEB1'});
    await db.put(AppDatabaseService.boxHomebrew, 'hb_web', {'name': 'Flare'});
    await db.put(AppDatabaseService.boxHomebrewRaw, 'raw_web', '{"name":"Flare"}');
    await db.put(AppDatabaseService.boxMetadata, 'web_ok', true);

    await Hive.close();

    final db2 = AppDatabaseService.custom(
      hiveInit: Hive.initFlutter,
      hiveBoxOpener: Hive.openBox<dynamic>,
    );
    await db2.init();

    expect(
      db2.get(AppDatabaseService.boxCharacters, 'c_web'),
      equals({'name': 'Lyra'}),
    );
    expect(
      db2.get(AppDatabaseService.boxCampaignProfiles, 'WEB1'),
      equals({'roomCode': 'WEB1'}),
    );
    expect(
      db2.get(AppDatabaseService.boxHomebrew, 'hb_web'),
      equals({'name': 'Flare'}),
    );
    expect(
      db2.get(AppDatabaseService.boxHomebrewRaw, 'raw_web'),
      equals('{"name":"Flare"}'),
    );
    expect(
      db2.get(AppDatabaseService.boxMetadata, 'web_ok'),
      isTrue,
    );

    await Hive.close();
  });
}
