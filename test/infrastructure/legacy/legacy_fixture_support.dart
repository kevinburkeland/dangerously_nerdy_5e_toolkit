import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'legacy_inventory.dart';

/// Representation of a known loss where legacy data fails to load or loses a fact.
/// If any known loss is fixed, the test fails to mandate its removal.
class KnownLoss {
  final String id;
  final String fixture;
  final String check;
  final String path;
  final String reason;

  const KnownLoss({
    required this.id,
    required this.fixture,
    required this.check,
    required this.path,
    required this.reason,
  });
}

/// Shared test harness and canonical state serialization for the legacy campaign safety net.
class LegacyFixtureSupport {
  /// Recursively sorts map keys for deterministic canonical JSON comparisons.
  static dynamic sortJson(dynamic object) {
    if (object is Map) {
      final sortedMap = SplayTreeMap<String, dynamic>();
      for (final entry in object.entries) {
        sortedMap[entry.key.toString()] = sortJson(entry.value);
      }
      return sortedMap;
    }
    if (object is List) {
      return object.map(sortJson).toList();
    }
    return object;
  }

  /// Encodes any object into a canonical JSON string with sorted keys and indentation.
  static String canonicalJson(dynamic object) {
    final sorted = sortJson(object);
    return const JsonEncoder.withIndent('  ').convert(sorted);
  }

  /// Seeds real Hive boxes in [tempDir] and sets mock SharedPreferences from a [storageJson] map.
  static Future<void> seedStorage(
    Directory tempDir,
    Map<String, dynamic> storageJson,
  ) async {
    // 1. SharedPreferences mock seeding
    final prefsMap = storageJson['prefs'] as Map<String, dynamic>? ?? {};
    final initialPrefs = <String, Object>{};

    for (final entry in prefsMap.entries) {
      final key = entry.key;
      final valMap = entry.value as Map<String, dynamic>;
      final type = valMap['t'] as String;
      final dynamic rawVal = valMap['v'];

      switch (type) {
        case 's':
          initialPrefs[key] = rawVal.toString();
        case 'i':
          initialPrefs[key] = (rawVal as num).toInt();
        case 'b':
          initialPrefs[key] = rawVal as bool;
        case 'd':
          initialPrefs[key] = (rawVal as num).toDouble();
        case 'sl':
          initialPrefs[key] =
              (rawVal as List).map((e) => e.toString()).toList();
        default:
          initialPrefs[key] = rawVal.toString();
      }
    }
    SharedPreferences.setMockInitialValues(initialPrefs);

    // 2. Real Hive box seeding
    Hive.init(tempDir.path);
    final boxesMap = storageJson['boxes'] as Map<String, dynamic>? ?? {};

    for (final boxEntry in boxesMap.entries) {
      final boxName = boxEntry.key;
      final boxContents = boxEntry.value as Map<String, dynamic>;
      final box = await Hive.openBox<dynamic>(boxName);
      await box.clear();
      for (final kv in boxContents.entries) {
        await box.put(kv.key, kv.value);
      }
      await box.close();
    }
  }

  /// Executes production startup sequence over [tempDir] with only Firebase replaced by a no-op.
  static Future<void> boot(Directory tempDir) async {
    sl.reset();

    final db = AppDatabaseService.custom(
      hiveInit: () async => Hive.init(tempDir.path),
      hiveBoxOpener: Hive.openBox<dynamic>,
    );
    AppDatabaseService.instance = db;

    final storageResult = await openStorage(db);
    if (!storageResult.isSuccess) {
      throw StateError('openStorage failed: ${storageResult.error}');
    }

    final services = AppServices.instance;
    await completeNormalStartup(
      services,
      LoggingService(),
      setupFirebase: () async {},
    );
  }

  /// Takes a snapshot of all opened Hive boxes and SharedPreferences keys as canonical JSON.
  static Future<String> takeSnapshot(
    AppDatabaseService db,
    SharedPreferences prefs,
  ) async {
    final boxesSnapshot = SplayTreeMap<String, dynamic>();

    for (final boxName in [
      AppDatabaseService.boxCharacters,
      AppDatabaseService.boxCampaignProfiles,
      AppDatabaseService.boxHomebrew,
      AppDatabaseService.boxHomebrewRaw,
      AppDatabaseService.boxMetadata,
    ]) {
      if (db.isBoxOpen(boxName)) {
        final boxMap = SplayTreeMap<String, dynamic>();
        for (final k in db.getKeys(boxName)) {
          boxMap[k] = db.get(boxName, k);
        }
        boxesSnapshot[boxName] = boxMap;
      }
    }

    final prefsSnapshot = SplayTreeMap<String, dynamic>();
    for (final key in prefs.getKeys()) {
      final dynamic val = prefs.get(key);
      String type = 's';
      if (val is int) {
        type = 'i';
      } else if (val is bool) {
        type = 'b';
      } else if (val is double) {
        type = 'd';
      } else if (val is List<String>) {
        type = 'sl';
      } else if (val is List) {
        type = 'sl';
      }
      prefsSnapshot[key] = {
        't': type,
        'v': val,
      };
    }

    final snapshotMap = {
      'boxes': boxesSnapshot,
      'prefs': prefsSnapshot,
    };

    return canonicalJson(snapshotMap);
  }

  /// Extracts today's stored facts from production repositories and readers.
  static Future<Map<String, dynamic>> computeTodayFacts(
    ICampaignRepository campaignRepo,
    LocalCharacterRepository charRepo,
    CampaignRegistryService registryService,
    SharedPreferences prefs,
  ) async {
    final profiles = await campaignRepo.loadAllProfiles();
    final sortedProfiles = List.of(profiles)
      ..sort((a, b) => a.id.compareTo(b.id));

    final campaignsList = <Map<String, dynamic>>[];
    for (final profile in sortedProfiles) {
      final activeMinions = profile.roomState.activeMinions.activeValues
          .map((m) => m.id.toString())
          .toList()
        ..sort();

      final liveEntityLinks = profile.roomState.entityLinksCrdt.items.values
          .map((l) => l.value.entityId)
          .toList()
        ..sort();

      final memberPursesMap = SplayTreeMap<String, Map<String, int>>();
      for (final entry in profile.memberPurses.entries) {
        memberPursesMap[entry.key] = {
          'cp': entry.value.getBalance('cp'),
          'ep': entry.value.getBalance('ep'),
          'gp': entry.value.getBalance('gp'),
          'pp': entry.value.getBalance('pp'),
          'sp': entry.value.getBalance('sp'),
        };
      }

      final partyPurse = {
        'cp': profile.partyPurse.getBalance('cp'),
        'ep': profile.partyPurse.getBalance('ep'),
        'gp': profile.partyPurse.getBalance('gp'),
        'pp': profile.partyPurse.getBalance('pp'),
        'sp': profile.partyPurse.getBalance('sp'),
      };

      final partyRosterIds = profile.partyRoster.activeValues.toList()..sort();
      final pinnedRuleIds = profile.pinnedRules.activeValues.toList()..sort();
      final tokenIds = profile.mapTokens.activeValues.map((t) => t.id).toList()
        ..sort();

      campaignsList.add({
        'activeMapSha256': profile.activeMapRegister.value?.sha256Hex,
        'activeMinionIds': activeMinions,
        'changeLogCount': profile.changeLog.length,
        'edition': profile.edition.rulesetId,
        'grid': profile.mapGridRegister.value?.toMap(),
        'id': profile.id,
        'liveEntityLinkIds': liveEntityLinks,
        'memberPurses': memberPursesMap,
        'name': profile.name,
        'notes': profile.notesMarkdown,
        'partyPurse': partyPurse,
        'partyRosterIds': partyRosterIds,
        'pinnedRuleIds': pinnedRuleIds,
        'roomCode': profile.roomState.roomCode,
        'tokenIds': tokenIds,
      });
    }

    final characters = await charRepo.loadCharacters();
    final sortedCharacters = List.of(characters)
      ..sort((a, b) => a.id.slug.compareTo(b.id.slug));

    final charactersList = <Map<String, dynamic>>[];
    for (final char in sortedCharacters) {
      final classes = char.progression.classes
          .map((c) => {'id': c.classRef.slug, 'level': c.level})
          .toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

      final equipped = char.inventory
          .where((i) => i.isEquipped)
          .map((i) => i.itemRef.slug)
          .toList()
        ..sort();

      final inventory = char.inventory
          .map((i) => {'id': i.itemRef.slug, 'quantity': i.quantity})
          .toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

      final spellsKnown = char.spellsKnown.map((s) => s.slug).toList()..sort();
      final spellsPrepared =
          char.spellsPrepared.map((s) => s.slug).toList()..sort();

      charactersList.add({
        'classes': classes,
        'currentHp': char.resources.currentHp,
        'equippedItemIds': equipped,
        'id': char.id.slug,
        'inventory': inventory,
        'knownSpellIds': spellsKnown,
        'maxHp': char.evaluatedMaxHp,
        'name': char.name,
        'preparedSpellIds': spellsPrepared,
      });
    }

    final memberships = await registryService.loadMemberships();
    final sortedMemberships = List.of(memberships)
      ..sort((a, b) => a.roomCode.compareTo(b.roomCode));

    final registryList = sortedMemberships
        .map((m) => {
              'characterId': m.characterId,
              'role': m.role.name,
              'roomCode': m.roomCode,
            })
        .toList();

    final settings = SettingsProvider.hydrateFromPrefs(prefs);
    final settingsMap = {
      'accent': settings.fantasyAccent.name,
      'haptic': settings.hapticLevel.name,
      'rulesEdition': settings.rulesEdition.name,
      'theme': settings.themeMode.name,
    };

    final facts = {
      'activeCampaignId': campaignRepo.activeProfileId,
      'activeCharacterId': await charRepo.loadActiveCharacterId(),
      'campaigns': campaignsList,
      'characters': charactersList,
      'registryMemberships': registryList,
      'settings': settingsMap,
    };

    return sortJson(facts) as Map<String, dynamic>;
  }

  /// Compares actual facts against expected facts and returns one problem per difference,
  /// naming the fixture, campaign/character/settings, and field.
  /// Used by LL1, LB1, and LC1.
  static List<String> compareFacts(
    String fixtureId,
    Map<String, dynamic> expected,
    Map<String, dynamic> actual,
  ) {
    final problems = <String>[];

    for (final scalarKey in ['activeCampaignId', 'activeCharacterId']) {
      if (expected.containsKey(scalarKey) || actual.containsKey(scalarKey)) {
        if (expected[scalarKey] != actual[scalarKey]) {
          problems.add(
            'Fixture $fixtureId: field $scalarKey mismatch '
            '(expected ${expected[scalarKey]}, got ${actual[scalarKey]})',
          );
        }
      }
    }

    if (expected.containsKey('campaigns') || actual.containsKey('campaigns')) {
      final expList = (expected['campaigns'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final actList = (actual['campaigns'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final expById = {for (final c in expList) c['id'].toString(): c};
      final actById = {for (final c in actList) c['id'].toString(): c};
      final allIds = SplayTreeSet<String>()
        ..addAll(expById.keys)
        ..addAll(actById.keys);

      for (final campId in allIds) {
        final expCamp = expById[campId];
        final actCamp = actById[campId];
        if (expCamp == null) {
          problems.add(
            'Fixture $fixtureId: campaign $campId unexpected in actual facts',
          );
          continue;
        }
        if (actCamp == null) {
          problems.add(
            'Fixture $fixtureId: campaign $campId missing from actual facts',
          );
          continue;
        }
        final fields = SplayTreeSet<String>()
          ..addAll(expCamp.keys)
          ..addAll(actCamp.keys);
        for (final field in fields) {
          if (canonicalJson(expCamp[field]) != canonicalJson(actCamp[field])) {
            problems.add(
              'Fixture $fixtureId: campaign $campId field $field mismatch '
              '(expected ${json.encode(expCamp[field])}, got ${json.encode(actCamp[field])})',
            );
          }
        }
      }
    }

    if (expected.containsKey('characters') ||
        actual.containsKey('characters')) {
      final expList = (expected['characters'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final actList = (actual['characters'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final expById = {for (final c in expList) c['id'].toString(): c};
      final actById = {for (final c in actList) c['id'].toString(): c};
      final allIds = SplayTreeSet<String>()
        ..addAll(expById.keys)
        ..addAll(actById.keys);

      for (final charId in allIds) {
        final expChar = expById[charId];
        final actChar = actById[charId];
        if (expChar == null) {
          problems.add(
            'Fixture $fixtureId: character $charId unexpected in actual facts',
          );
          continue;
        }
        if (actChar == null) {
          problems.add(
            'Fixture $fixtureId: character $charId missing from actual facts',
          );
          continue;
        }
        final fields = SplayTreeSet<String>()
          ..addAll(expChar.keys)
          ..addAll(actChar.keys);
        for (final field in fields) {
          if (canonicalJson(expChar[field]) != canonicalJson(actChar[field])) {
            problems.add(
              'Fixture $fixtureId: character $charId field $field mismatch '
              '(expected ${json.encode(expChar[field])}, got ${json.encode(actChar[field])})',
            );
          }
        }
      }
    }

    if (expected.containsKey('registryMemberships') ||
        actual.containsKey('registryMemberships')) {
      if (canonicalJson(expected['registryMemberships']) !=
          canonicalJson(actual['registryMemberships'])) {
        problems.add(
          'Fixture $fixtureId: field registryMemberships mismatch '
          '(expected ${json.encode(expected['registryMemberships'])}, '
          'got ${json.encode(actual['registryMemberships'])})',
        );
      }
    }

    if (expected.containsKey('settings') || actual.containsKey('settings')) {
      final expSettings =
          Map<String, dynamic>.from(expected['settings'] as Map? ?? {});
      final actSettings =
          Map<String, dynamic>.from(actual['settings'] as Map? ?? {});
      final fields = SplayTreeSet<String>()
        ..addAll(expSettings.keys)
        ..addAll(actSettings.keys);
      for (final field in fields) {
        if (canonicalJson(expSettings[field]) !=
            canonicalJson(actSettings[field])) {
          problems.add(
            'Fixture $fixtureId: settings.$field mismatch '
            '(expected ${expSettings[field]}, got ${actSettings[field]})',
          );
        }
      }
    }

    return problems;
  }

  /// Compares an old record's keys against the resaved record and [migratedKeys],
  /// returning one problem per dropped key, naming the key.
  /// Used by LL4 and LC2.
  static List<String> checkDroppedKeys(
    String fixtureId,
    String recordKey,
    Map<String, dynamic> oldRecord,
    Map<String, dynamic> currentRecord,
    Map<String, String> migratedKeys,
  ) {
    final problems = <String>[];
    for (final k in oldRecord.keys) {
      if (!currentRecord.containsKey(k)) {
        if (!migratedKeys.containsKey(k)) {
          problems.add(
            'LL4 failed for $fixtureId ($recordKey): dropped key "$k" without migration mapping',
          );
          continue;
        }
        final newKey = migratedKeys[k]!;
        if (!currentRecord.containsKey(newKey)) {
          problems.add(
            'LL4 failed for $fixtureId ($recordKey): dropped key "$k" (migrated target "$newKey" missing)',
          );
        }
      }
    }
    return problems;
  }

  /// Reads MANIFEST.json and the files on disk (or a passed-in [manifestOverride] for LC3)
  /// and returns one problem per missing, extra, or sha256-mismatched file, naming the path.
  static List<String> checkManifest({
    List<dynamic>? manifestOverride,
    Directory? baseDir,
  }) {
    final dir = baseDir ?? Directory('test/fixtures/legacy_storage');
    final problems = <String>[];

    final List<dynamic> manifestList;
    if (manifestOverride != null) {
      manifestList = manifestOverride;
    } else {
      final manifestFile = File('${dir.path}/MANIFEST.json');
      if (!manifestFile.existsSync()) {
        return ['Manifest file ${manifestFile.path} does not exist'];
      }
      manifestList =
          json.decode(manifestFile.readAsStringSync()) as List<dynamic>;
    }

    final seenPaths = <String>{};
    for (final item in manifestList) {
      final map = item as Map;
      final path = map['path'] as String;
      final expectedSha = map['sha256'] as String;
      seenPaths.add(path);

      final file = File('${dir.path}/$path');
      if (!file.existsSync()) {
        problems.add('Manifest file $path does not exist on disk');
        continue;
      }

      final actualSha = sha256.convert(file.readAsBytesSync()).toString();
      if (actualSha != expectedSha) {
        problems.add(
          'Sha256 mismatch for manifest file $path (expected $expectedSha, got $actualSha)',
        );
      }
    }

    if (dir.existsSync()) {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final normalizedDir = dir.path.replaceAll('\\', '/');
          final rel = entity.path
              .replaceAll('\\', '/')
              .replaceFirst('$normalizedDir/', '');
          if (rel == 'README.md' || rel == 'MANIFEST.json') continue;
          if (!seenPaths.contains(rel)) {
            problems.add('Extra file $rel on disk is not listed in MANIFEST.json');
          }
        }
      }
    }

    return problems;
  }

  /// Removes each problem matched by a [KnownLoss] for `(fixture, check)` and returns a
  /// `"known loss <id> no longer fails; remove it"` problem for any [KnownLoss] on
  /// `(fixture, check)` whose expected problem did not occur.
  static List<String> applyKnownLosses(
    List<String> problems,
    List<KnownLoss> losses, {
    required String fixture,
    required String check,
  }) {
    final matchingLosses = losses
        .where((l) => l.fixture == fixture && l.check == check)
        .toList();
    final remaining = List<String>.from(problems);
    final stale = <String>[];

    for (final loss in matchingLosses) {
      final idx = remaining.indexWhere((p) => p.contains(loss.path));
      if (idx != -1) {
        remaining.removeAt(idx);
      } else {
        stale.add('known loss ${loss.id} no longer fails; remove it');
      }
    }

    return [...remaining, ...stale];
  }

  /// LI1: Parses the markdown table in README.md and checks that its rows match
  /// [inventory] in order (`id`, `filePath: symbol`, `oldShape`, and `fixtureOrReason`).
  static List<String> checkInventoryReadmeAgreement(
    String readmeContent,
    List<LegacyInventoryRow> inventory,
  ) {
    final problems = <String>[];
    final lines = readmeContent.split('\n');
    final tableLines = lines
        .where((l) => l.trim().startsWith('|') && !l.contains('---|---'))
        .toList();

    if (tableLines.length <= 1) {
      return ['README.md has no inventory table rows'];
    }

    final dataRows = tableLines.skip(1).toList();
    if (dataRows.length != inventory.length) {
      problems.add(
        'README.md row count (${dataRows.length}) does not match legacyInventory length (${inventory.length})',
      );
    }

    final count = dataRows.length < inventory.length
        ? dataRows.length
        : inventory.length;

    for (var i = 0; i < count; i++) {
      final rawRow = dataRows[i];
      final cells = rawRow
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      final inv = inventory[i];

      if (cells.length != 4) {
        problems.add('Row ${inv.id}: invalid markdown row format: $rawRow');
        continue;
      }

      final idCell = cells[0];
      final fileAndSymCell = cells[1].replaceAll('`', '');
      final oldShapeCell = cells[2];
      final fixtureOrReasonCell = cells[3];

      if (idCell != inv.id) {
        problems.add(
          'Row index $i: README id "$idCell" != inventory id "${inv.id}"',
        );
      }
      if (fileAndSymCell != inv.fileAndSymbol) {
        problems.add(
          'Row ${inv.id}: README fileAndSymbol "$fileAndSymCell" != inventory "${inv.fileAndSymbol}"',
        );
      }
      if (oldShapeCell != inv.oldShape) {
        problems.add(
          'Row ${inv.id}: README oldShape "$oldShapeCell" != inventory "${inv.oldShape}"',
        );
      }
      if (fixtureOrReasonCell != inv.fixtureOrReason) {
        problems.add(
          'Row ${inv.id}: README fixtureOrReason "$fixtureOrReasonCell" != inventory "${inv.fixtureOrReason}"',
        );
      }
    }

    return problems;
  }

  /// LI2: Checks that every `(fixtureId, predicate)` in [inventory] evaluates to `true`
  /// on the raw fixture map before any boot.
  static List<String> checkInventoryPredicates(
    List<LegacyInventoryRow> inventory,
    Map<String, Map<String, dynamic>> rawFixturesById,
  ) {
    final problems = <String>[];
    for (final row in inventory) {
      if (row.fixtures.isEmpty && row.reason == null) {
        problems.add('Row ${row.id}: has neither fixtures nor reason');
      }
      if (row.fixtures.isNotEmpty && row.reason != null) {
        problems.add('Row ${row.id}: cannot specify both fixtures and reason');
      }
      for (final fp in row.fixtures) {
        final raw = rawFixturesById[fp.fixtureId];
        if (raw == null) {
          problems.add(
            'Row ${row.id}: unknown fixtureId "${fp.fixtureId}"',
          );
          continue;
        }
        bool passed = false;
        try {
          passed = fp.predicate(raw);
        } catch (e) {
          problems.add(
            'Row ${row.id} fixture ${fp.fixtureId}: predicate threw $e',
          );
          continue;
        }
        if (!passed) {
          problems.add(
            'Row ${row.id} fixture ${fp.fixtureId}: predicate returned false on raw fixture data',
          );
        }
      }
    }
    return problems;
  }

  /// LI3: Checks that every file, symbol, and unit-test path in [inventory] exists,
  /// and that only the two allowed reason formats are used.
  static List<String> checkInventoryFilesAndSymbols(
    List<LegacyInventoryRow> inventory,
  ) {
    final problems = <String>[];
    for (final row in inventory) {
      final file = File(row.filePath);
      if (!file.existsSync()) {
        problems.add('Row ${row.id}: file "${row.filePath}" does not exist');
      } else {
        final content = file.readAsStringSync();
        if (!content.contains(row.symbol)) {
          problems.add(
            'Row ${row.id}: symbol "${row.symbol}" not found in "${row.filePath}"',
          );
        }
      }

      if (row.reason != null) {
        final reason = row.reason!;
        if (reason.startsWith('unit test: ')) {
          final testPath = reason.substring('unit test: '.length).trim();
          if (testPath.isEmpty || !File(testPath).existsSync()) {
            problems.add(
              'Row ${row.id}: unit test file "$testPath" does not exist',
            );
          }
        } else if (reason == 'not covered: later slice') {
          if (row.id != 'B29' && row.id != 'B30') {
            problems.add(
              'Row ${row.id}: reason "not covered: later slice" is only allowed for B29 and B30',
            );
          }
        } else {
          problems.add(
            'Row ${row.id}: disallowed reason "$reason"',
          );
        }
      }
    }
    return problems;
  }
}
