import 'dart:collection';
import 'dart:convert';
import 'dart:io';
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
      throw StateError(
          'openStorage failed: ${storageResult.error}');
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
}
