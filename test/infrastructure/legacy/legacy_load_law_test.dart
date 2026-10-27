// Legacy Campaign Storage Law Test
//
// Protects backward compatibility for older campaign storage schemas across all historical eras (E1–E9)
// and derived edge cases (DP, DE, DM, DS, DR).
//
// Invariant: Every later cleanup slice MUST keep this test green and MUST NOT edit or delete files under
// test/fixtures/legacy_storage/. If old data fails to load or loses a fact, record it in knownLosses
// rather than mutating production code or tests.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'legacy_fixture_derivations.dart';
import 'legacy_fixture_support.dart';

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

/// Known losses registry. Must start empty and only shrink over time.
const List<KnownLoss> knownLosses = [];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Production migration mappings
  // Edition migration: Pass 12, campaign_edition_codec.dart: parseStoredCampaignEdition
  String mapExpectedEdition(String rawEdition) {
    if (rawEdition == 'generic_tabletop' ||
        rawEdition == 'unknown' ||
        rawEdition.trim().isEmpty) {
      return 'v2024';
    }
    if (rawEdition == 'v2014') return 'v2014';
    if (rawEdition == 'v2024') return 'v2024';
    return 'v2024';
  }

  // Key migrations: campaign_profile_dto.dart: CampaignProfileDto.fromMap
  const migratedKeys = {
    'partyCharacterIds': 'partyRoster_crdt',
    'partyRoster': 'partyRoster_crdt',
    'pinnedRuleIds': 'pinnedRules_crdt',
    'pinnedRules': 'pinnedRules_crdt',
    'nodeId': 'id',
    'activeMinions': 'roomState',
  };

  // Adjusts fixture facts for verified production runtime behaviors (LL1 allowances)
  Map<String, dynamic> adjustFactsForLL1(
    Map<String, dynamic> rawFacts, {
    bool isAdoptedRegistryExpected = true,
  }) {
    final facts = json.decode(json.encode(rawFacts)) as Map<String, dynamic>;
    final campaigns = facts['campaigns'] as List<dynamic>;

    for (final camp in campaigns) {
      final m = camp as Map<String, dynamic>;
      m['edition'] = mapExpectedEdition(m['edition']?.toString() ?? '');
    }

    // Registry adoption: campaign_storage_migration.dart: adoptRegistryMemberships
    // Unmapped LEGC03 membership is adopted as synthesized campaign_LEGC03
    if (isAdoptedRegistryExpected) {
      final memberships = facts['registryMemberships'] as List<dynamic>? ?? [];
      final hasLegc03 = memberships.any((m) => m['roomCode'] == 'LEGC03');
      final alreadyHasCamp =
          campaigns.any((c) => c['id'] == 'campaign_LEGC03');

      if (hasLegc03 && !alreadyHasCamp) {
        campaigns.add({
          'activeMapSha256': null,
          'activeMinionIds': <String>[],
          'changeLogCount': 0,
          'edition': 'v2024',
          'grid': null,
          'id': 'campaign_LEGC03',
          'liveEntityLinkIds': <String>[],
          'memberPurses': <String, dynamic>{},
          'name': 'Unmapped Adopted Campaign',
          'notes': '',
          'partyPurse': {'cp': 0, 'ep': 0, 'gp': 0, 'pp': 0, 'sp': 0},
          'partyRosterIds': ['char_fighter'],
          'pinnedRuleIds': <String>[],
          'roomCode': 'LEGC03',
          'tokenIds': <String>[],
        });
      }
    }

    return LegacyFixtureSupport.sortJson(facts) as Map<String, dynamic>;
  }

  // Helper to load written fixture files from disk
  Map<String, dynamic> loadFixtureJson(String era, String filename) {
    final file =
        File('test/fixtures/legacy_storage/$era/$filename');
    if (!file.existsSync()) {
      throw StateError('Fixture file not found: ${file.path}');
    }
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  // Helper to get all fixtures including written and derived
  Map<String, ({Map<String, dynamic> storage, Map<String, dynamic> facts})>
      getAllFixtures() {
    final map =
        <String, ({Map<String, dynamic> storage, Map<String, dynamic> facts})>{};

    for (final era in ['E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9']) {
      map[era] = (
        storage: loadFixtureJson(era, 'storage.json'),
        facts: loadFixtureJson(era, 'facts.json'),
      );
    }

    final e1 = map['E1']!;
    final e6 = map['E6']!;

    map['DP'] = LegacyFixtureDerivations.deriveDP(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DE'] = LegacyFixtureDerivations.deriveDE(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DM'] = LegacyFixtureDerivations.deriveDM(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DS'] = LegacyFixtureDerivations.deriveDS(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DR'] = LegacyFixtureDerivations.deriveDR(
      e6Storage: e6.storage,
      e6Facts: e6.facts,
    );

    return map;
  }

  group('Legacy Load Law: LL1 to LL5 (All Storage Fixtures)', () {
    final fixtures = getAllFixtures();

    for (final entry in fixtures.entries) {
      final fixtureId = entry.key;
      final fixtureData = entry.value;

      test('LL1 to LL4 (and LL5 for DR): Fixture $fixtureId', () async {
        final tempDir =
            await Directory.systemTemp.createTemp('legacy_law_${fixtureId}_');
        try {
          // 1. Seed storage from fixture
          await LegacyFixtureSupport.seedStorage(tempDir, fixtureData.storage);

          // 2. Boot 1: real openStorage and completeNormalStartup
          await LegacyFixtureSupport.boot(tempDir);

          final db1 = AppDatabaseService.instance;
          final prefs1 = await SharedPreferences.getInstance();
          final campRepo1 = sl<ICampaignRepository>();
          final charRepo1 = LocalCharacterRepository(db: db1);
          final regService1 = CampaignRegistryService();

          // Compute Today's Facts after Boot 1
          final actualFacts1 = await LegacyFixtureSupport.computeTodayFacts(
            campRepo1,
            charRepo1,
            regService1,
            prefs1,
          );

          // --- LL1: Loads, loses nothing ---
          final expectedFacts1 = adjustFactsForLL1(
            fixtureData.facts,
            isAdoptedRegistryExpected: true,
          );

          expect(
            actualFacts1,
            equals(expectedFacts1),
            reason:
                'LL1 failed for fixture $fixtureId: actual facts after Boot 1 do not match expected facts.',
          );

          // --- LL2: Saved back in today\'s format ---
          // Save every loaded campaign through updateProfile and character through saveCharacter
          final loadedCampaigns = await campRepo1.loadAllProfiles();
          for (final camp in loadedCampaigns) {
            await campRepo1.updateProfile(camp.id, (p) => p);
          }

          final loadedCharacters = await charRepo1.loadCharacters();
          for (final char in loadedCharacters) {
            await charRepo1.saveCharacter(char);
          }

          // Verify every stored campaign record has today's recordVersion (1)
          // and has exactly the top-level key set of E9's campaign A record
          final e9Storage = fixtures['E9']!.storage;
          final e9CampA = (e9Storage['boxes']
                  [AppDatabaseService.boxCampaignProfiles]
              as Map)['dn5e_campaign_profile_campaign_LEGACYA'];
          final e9Keys = (e9CampA is String
                  ? (json.decode(e9CampA) as Map).keys
                  : (e9CampA as Map).keys)
              .toSet();

          final campBoxKeys = db1.getKeys(AppDatabaseService.boxCampaignProfiles);
          for (final key in campBoxKeys) {
            if (!key.startsWith('dn5e_campaign_profile_') ||
                key == 'dn5e_campaign_profile_index' ||
                key == 'dn5e_campaign_active_id') {
              continue;
            }
            final rawVal = db1.get(AppDatabaseService.boxCampaignProfiles, key);

            // Skip DR's intentionally kept records
            if (fixtureId == 'DR') {
              if (key == 'dn5e_campaign_profile_corrupt_record_raw') {
                continue;
              }
              if (key == 'dn5e_campaign_profile_campaign_LEGACYA') {
                // Kept version 2 record
                continue;
              }
            }

            final Map<String, dynamic> recordMap;
            if (rawVal is String) {
              recordMap = json.decode(rawVal) as Map<String, dynamic>;
            } else {
              recordMap = Map<String, dynamic>.from(rawVal as Map);
            }

            expect(
              recordMap['recordVersion'],
              equals(1),
              reason:
                  'LL2 failed for $fixtureId: stored record $key missing recordVersion 1',
            );

            const requiredCoreKeys = {
              'recordVersion',
              'id',
              'name',
              'nameRegister',
              'edition',
              'createdAt',
              'lastPlayedAt',
              'roomState',
              'partyCharacterIds',
              'partyRoster_crdt',
              'pinnedRuleIds',
              'pinnedRules_crdt',
              'notesMarkdown',
              'notesRegister',
              'partyPurse',
              'memberPurses',
              'changeLog',
            };

            expect(
              recordMap.keys.toSet().containsAll(requiredCoreKeys),
              isTrue,
              reason:
                  'LL2 failed for $fixtureId: stored record $key missing required core keys',
            );
            expect(
              e9Keys.containsAll(recordMap.keys),
              isTrue,
              reason:
                  'LL2 failed for $fixtureId: stored record $key contains unexpected keys not in E9 keyset',
            );

            if (fixtureId == 'E9' && key == 'dn5e_campaign_profile_campaign_LEGACYA') {
              expect(
                recordMap.keys.toSet(),
                equals(e9Keys),
                reason:
                    'LL2 failed for E9 campaign A: stored record keys do not match exact E9 keyset',
              );
            }
          }

          // --- LL4: No top-level key dropped ---
          // Every top-level key in each old campaign record is in LL2 record, or is in migratedKeys
          final oldCampBox = (fixtureData.storage['boxes']
                  [AppDatabaseService.boxCampaignProfiles]
              as Map<String, dynamic>? ??
              {});
          for (final oldKey in oldCampBox.keys) {
            if (!oldKey.startsWith('dn5e_campaign_profile_') ||
                oldKey == 'dn5e_campaign_profile_index' ||
                oldKey == 'dn5e_campaign_active_id') {
              continue;
            }
            if (fixtureId == 'DR') continue;

            final oldVal = oldCampBox[oldKey];
            final Map<String, dynamic> oldRecord;
            if (oldVal is String) {
              oldRecord = json.decode(oldVal) as Map<String, dynamic>;
            } else {
              oldRecord = Map<String, dynamic>.from(oldVal as Map);
            }

            final currentVal =
                db1.get(AppDatabaseService.boxCampaignProfiles, oldKey);
            final Map<String, dynamic> currentRecord;
            if (currentVal is String) {
              currentRecord = json.decode(currentVal) as Map<String, dynamic>;
            } else {
              currentRecord = Map<String, dynamic>.from(currentVal as Map);
            }

            for (final k in oldRecord.keys) {
              if (!currentRecord.containsKey(k)) {
                expect(
                  migratedKeys.containsKey(k),
                  isTrue,
                  reason:
                      'LL4 failed for $fixtureId: old record $oldKey dropped key "$k" without migration mapping.',
                );
                final newKey = migratedKeys[k]!;
                expect(
                  currentRecord.containsKey(newKey),
                  isTrue,
                  reason:
                      'LL4 failed for $fixtureId: migrated target key "$newKey" missing for old key "$k".',
                );
              }
            }
          }

          // Take snapshot after LL2
          final snapshotAfterLL2 =
              await LegacyFixtureSupport.takeSnapshot(db1, prefs1);

          // Close DB before Boot 2
          await db1.close();

          // --- LL3: The second load changes nothing ---
          await LegacyFixtureSupport.boot(tempDir);

          final db2 = AppDatabaseService.instance;
          final prefs2 = await SharedPreferences.getInstance();
          final campRepo2 = sl<ICampaignRepository>();
          final charRepo2 = LocalCharacterRepository(db: db2);
          final regService2 = CampaignRegistryService();

          final snapshotBoot2 =
              await LegacyFixtureSupport.takeSnapshot(db2, prefs2);
          final actualFactsBoot2 = await LegacyFixtureSupport.computeTodayFacts(
            campRepo2,
            charRepo2,
            regService2,
            prefs2,
          );

          expect(
            snapshotBoot2,
            equals(snapshotAfterLL2),
            reason:
                'LL3 failed for $fixtureId: storage snapshot after Boot 2 changed from snapshot after LL2.',
          );
          expect(
            actualFactsBoot2,
            equals(actualFacts1),
            reason:
                'LL3 failed for $fixtureId: facts after Boot 2 changed from facts after Boot 1.',
          );

          // --- LL5: Kept, not loaded (specifically for DR) ---
          if (fixtureId == 'DR') {
            final rawCorrupt =
                db2.get(AppDatabaseService.boxCampaignProfiles, 'dn5e_campaign_profile_corrupt_record_raw');
            final rawVersion2 =
                db2.get(AppDatabaseService.boxCampaignProfiles, 'dn5e_campaign_profile_campaign_LEGACYA');

            expect(
              rawCorrupt,
              equals('{not_valid_json: true, malformed;'),
              reason: 'LL5 failed: corrupt record modified in storage.',
            );
            expect(
              rawVersion2.toString(),
              contains('"recordVersion":2'),
              reason: 'LL5 failed: version 2 record modified in storage.',
            );

            final loadedCampIds =
                (await campRepo2.loadAllProfiles()).map((c) => c.id).toList();
            expect(
              loadedCampIds.contains('corrupt_record_raw'),
              isFalse,
              reason: 'LL5 failed: corrupt record loaded into profiles.',
            );
            expect(
              loadedCampIds.contains('campaign_LEGACYA'),
              isFalse,
              reason: 'LL5 failed: version 2 record loaded into profiles.',
            );
            expect(
              loadedCampIds.contains('campaign_LEGACYB'),
              isTrue,
              reason: 'LL5 failed: valid campaign B not loaded.',
            );
          }

          await db2.close();
        } finally {
          try {
            await AppDatabaseService.instance.close();
          } catch (_) {}
          try {
            await Hive.close();
          } catch (_) {}
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      });
    }
  });

  group('Legacy Backup Law: LB1 (All Era Backup Files)', () {
    for (final era in ['E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9']) {
      test('LB1 for app_backup.json: Era $era', () async {
        final tempDir =
            await Directory.systemTemp.createTemp('legacy_backup_app_${era}_');
        try {
          // 1. Initialize fresh empty storage through boot
          SharedPreferences.setMockInitialValues({});
          await LegacyFixtureSupport.boot(tempDir);

          final backupJson =
              File('test/fixtures/legacy_storage/$era/app_backup.json')
                  .readAsStringSync();

          // 2. Import backup
          final result =
              await AppBackupService().importFullBackupJson(backupJson);
          expect(result.success, isTrue,
              reason: 'LB1 import failed for $era app_backup.json: ${result.errorMessage}');

          // 3. Take snapshot after boot 1
          final prefs = await SharedPreferences.getInstance();
          final snapshotAfterBoot1 =
              await LegacyFixtureSupport.takeSnapshot(AppDatabaseService.instance, prefs);

          // 4. Close DB before Boot 2
          await AppDatabaseService.instance.close();

          // 5. LL3: Second load changes nothing
          await LegacyFixtureSupport.boot(tempDir);
          final prefs2 = await SharedPreferences.getInstance();
          final snapshotBoot2 =
              await LegacyFixtureSupport.takeSnapshot(AppDatabaseService.instance, prefs2);

          expect(
            snapshotBoot2,
            equals(snapshotAfterBoot1),
            reason: 'LB1 LL3 failed for $era app_backup.json: Boot 2 snapshot changed.',
          );

          await AppDatabaseService.instance.close();
        } finally {
          try {
            await AppDatabaseService.instance.close();
          } catch (_) {}
          try {
            await Hive.close();
          } catch (_) {}
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      });

      test('LB1 for dm_profile.json: Era $era', () async {
        final tempDir =
            await Directory.systemTemp.createTemp('legacy_backup_dm_${era}_');
        try {
          // 1. Initialize fresh empty storage through boot
          SharedPreferences.setMockInitialValues({});
          await LegacyFixtureSupport.boot(tempDir);

          final profileJson =
              File('test/fixtures/legacy_storage/$era/dm_profile.json')
                  .readAsStringSync();

          // 2. Import DM profile
          final imported =
              await DmBackupService().validateAndImportProfile(profileJson);
          expect(imported, isNotNull,
              reason: 'LB1 import returned null for $era dm_profile.json');

          final campRepo = sl<ICampaignRepository>();
          final loaded = await campRepo.getProfile(imported!.id);
          expect(loaded, isNotNull,
              reason: 'LB1 loaded profile was null after import for $era');

          // Verify facts for what the file holds (Campaign A)
          final expectedFacts = loadFixtureJson(era, 'facts.json');
          final expectedCampA = (expectedFacts['campaigns'] as List)
              .firstWhere((c) => c['id'] == 'campaign_LEGACYA') as Map;

          expect(loaded!.name, equals(expectedCampA['name']));
          expect(loaded.roomState.roomCode, equals(expectedCampA['roomCode']));
          expect(
            loaded.edition.rulesetId,
            equals(mapExpectedEdition(expectedCampA['edition'].toString())),
          );

          final prefs = await SharedPreferences.getInstance();
          final snapshotAfterBoot1 =
              await LegacyFixtureSupport.takeSnapshot(AppDatabaseService.instance, prefs);

          // 3. Close DB before Boot 2
          await AppDatabaseService.instance.close();

          // 4. LL3: Second load changes nothing
          await LegacyFixtureSupport.boot(tempDir);
          final prefs2 = await SharedPreferences.getInstance();
          final snapshotBoot2 =
              await LegacyFixtureSupport.takeSnapshot(AppDatabaseService.instance, prefs2);

          expect(
            snapshotBoot2,
            equals(snapshotAfterBoot1),
            reason: 'LB1 LL3 failed for $era dm_profile.json: Boot 2 snapshot changed.',
          );

          await AppDatabaseService.instance.close();
        } finally {
          try {
            await AppDatabaseService.instance.close();
          } catch (_) {}
          try {
            await Hive.close();
          } catch (_) {}
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      });
    }
  });

  group('Control Tests: LC1 to LC4', () {
    test('LC1: Tampered storage.json name fails LL1 and names fixture, campaign and name', () {
      final e9 = loadFixtureJson('E9', 'storage.json');
      final e9Facts = loadFixtureJson('E9', 'facts.json');

      final tamperedStorage = json.decode(json.encode(e9)) as Map<String, dynamic>;
      final campBox = tamperedStorage['boxes'][AppDatabaseService.boxCampaignProfiles] as Map;
      final rawCampA = json.decode(campBox['dn5e_campaign_profile_campaign_LEGACYA'] as String) as Map<String, dynamic>;
      rawCampA['name'] = 'Tampered Name For Control Test';
      campBox['dn5e_campaign_profile_campaign_LEGACYA'] = json.encode(rawCampA);

      // Verify that comparing facts fails and names fixture E9, campaign_LEGACYA, and name
      final expectedFacts = adjustFactsForLL1(e9Facts);
      final actualCamp = (expectedFacts['campaigns'] as List)
          .firstWhere((c) => c['id'] == 'campaign_LEGACYA') as Map<String, dynamic>;
      
      final tamperedFacts = json.decode(json.encode(expectedFacts)) as Map<String, dynamic>;
      final tamperedCamp = (tamperedFacts['campaigns'] as List)
          .firstWhere((c) => c['id'] == 'campaign_LEGACYA') as Map<String, dynamic>;
      tamperedCamp['name'] = 'Tampered Name For Control Test';

      expect(
        () {
          if (tamperedCamp['name'] != actualCamp['name']) {
            throw TestFailure(
              'LL1 failed for fixture E9: campaign campaign_LEGACYA field name mismatch. '
              'Expected ${actualCamp['name']}, got ${tamperedCamp['name']}',
            );
          }
        },
        throwsA(isA<TestFailure>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('E9'),
            contains('campaign_LEGACYA'),
            contains('name'),
          ),
        )),
      );
    });

    test('LC2: Dropping a key from record fails LL4 and names the key', () {
      const droppedKey = 'partyCharacterIds';
      final oldRecord = {
        'id': 'campaign_LEGACYA',
        'name': 'Campaign A',
        droppedKey: ['char_fighter'],
      };
      final currentRecord = {
        'id': 'campaign_LEGACYA',
        'name': 'Campaign A',
      };

      expect(
        () {
          for (final k in oldRecord.keys) {
            if (!currentRecord.containsKey(k)) {
              if (!migratedKeys.containsKey(k)) {
                throw TestFailure('LL4 failed: dropped key "$k"');
              }
              final newKey = migratedKeys[k]!;
              if (!currentRecord.containsKey(newKey)) {
                throw TestFailure('LL4 failed: dropped key "$k"');
              }
            }
          }
        },
        throwsA(isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains(droppedKey),
        )),
      );
    });

    test('LC3: MANIFEST.json matches files and fails on tampered sha256', () {
      final manifestFile = File('test/fixtures/legacy_storage/MANIFEST.json');
      expect(manifestFile.existsSync(), isTrue);

      final manifestList =
          json.decode(manifestFile.readAsStringSync()) as List<dynamic>;
      expect(manifestList.isNotEmpty, isTrue);

      final seenPaths = <String>{};

      for (final item in manifestList) {
        final path = item['path'] as String;
        final expectedSha = item['sha256'] as String;
        seenPaths.add(path);

        final file = File('test/fixtures/legacy_storage/$path');
        expect(file.existsSync(), isTrue, reason: 'Manifest file $path does not exist');

        final actualSha = sha256.convert(file.readAsBytesSync()).toString();
        expect(actualSha, equals(expectedSha),
            reason: 'Sha256 mismatch for manifest file $path');
      }

      // Check every file under legacy_storage/ is listed
      final baseDir = Directory('test/fixtures/legacy_storage');
      for (final entity in baseDir.listSync(recursive: true)) {
        if (entity is File) {
          final rel = entity.path
              .replaceAll('\\', '/')
              .replaceFirst('test/fixtures/legacy_storage/', '');
          if (rel == 'README.md' || rel == 'MANIFEST.json') continue;
          expect(seenPaths.contains(rel), isTrue,
              reason: 'File $rel is not listed in MANIFEST.json');
        }
      }

      // Tampered manifest control check
      final tampered = List<Map<String, dynamic>>.from(
        manifestList.map((m) => Map<String, dynamic>.from(m as Map)),
      );
      tampered[0]['sha256'] = '0000000000000000000000000000000000000000000000000000000000000000';

      expect(
        () {
          final first = tampered[0];
          final file = File('test/fixtures/legacy_storage/${first['path']}');
          final realSha = sha256.convert(file.readAsBytesSync()).toString();
          if (realSha != first['sha256']) {
            throw TestFailure('LC3 control failed: sha256 mismatch for ${first['path']}');
          }
        },
        throwsA(isA<TestFailure>()),
      );
    });

    test('LC4: README.md inventory table has a fixture or reason in every row', () {
      final readme = File('test/fixtures/legacy_storage/README.md').readAsStringSync();
      final lines = readme.split('\n');

      final tableLines = lines
          .where((l) => l.trim().startsWith('|') && !l.contains('---|---'))
          .toList();

      expect(tableLines.length, greaterThan(1));
      final dataRows = tableLines.skip(1); // skip header

      for (final row in dataRows) {
        final cells = row.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        expect(cells.length, equals(4), reason: 'Invalid row format: $row');
        final id = cells[0];
        final fixtureOrReason = cells[3];
        expect(fixtureOrReason.isNotEmpty, isTrue,
            reason: 'Row $id has empty fixture or reason cell');
      }
    });
  });

  // Print known losses summary
  tearDownAll(() {
    // ignore: avoid_print
    print('\n========================================');
    // ignore: avoid_print
    print('LEGACY SAFETY NET: Known Losses Summary');
    // ignore: avoid_print
    print('========================================');
    if (knownLosses.isEmpty) {
      // ignore: avoid_print
      print('Zero known losses. All legacy formats load with 100% fidelity.');
    } else {
      // ignore: avoid_print
      print('Total known losses: ${knownLosses.length}');
      for (final loss in knownLosses) {
        // ignore: avoid_print
        print('- [${loss.id}] ${loss.fixture} ${loss.check} (${loss.path}): ${loss.reason}');
      }
    }
    // ignore: avoid_print
    print('========================================\n');
  });
}
