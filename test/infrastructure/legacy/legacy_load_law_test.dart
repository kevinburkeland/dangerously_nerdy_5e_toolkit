// Legacy Campaign Storage Law Test
//
// Protects backward compatibility for older campaign storage schemas across all historical eras (E1–E9)
// and derived edge cases (DP, DE, DM, DS, DR, DB7, DT, DPR, DMC, DPP, DB1, DB2).
//
// Invariant (Decision 3): Every later cleanup slice MUST keep this test green. Data fixtures
// (storage.json, facts.json, app_backup.json, dm_profile.json) under test/fixtures/legacy_storage/
// never change (never edit, regenerate, or delete them; new shapes are covered by derived fixtures
// built in code). Generator files (writer_test.dart.txt), MANIFEST.json generator rows, and README.md
// may change only when a slice updates a generator comment or inventory row. Every row of the legacy
// inventory is a checked claim in legacy_inventory.dart.
//
// Note on LB1 settings restore: In Part 0 of Cleanup slice 4.1, AppBackupService.importFullBackupJson
// (lib/services/persistence/app_backup_service.dart:322) parses backup.settings and ignores it, so LB1
// records the 44 resulting settings losses across E1–E9, DB1, and DB2 in knownLosses (fixed in Part B
// of Cleanup slice 4.1).

import 'dart:convert';
import 'dart:io';
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
import 'legacy_inventory.dart';

/// Top-level keys in E9's Campaign A record that `CampaignProfileDto.toMap`
/// (`lib/infrastructure/dtos/campaign_profile_dto.dart:891-923`) legitimately omits when empty.
const Map<String, String> kOptionalCampaignRecordKeys = {
  'nameRegister':
      'lib/infrastructure/dtos/campaign_profile_dto.dart:895 (omitted when nameRegister is empty / null on legacy profiles)',
  'activeMapRegister':
      'lib/infrastructure/dtos/campaign_profile_dto.dart:908 (omitted when activeMapRegister is CampaignProfile.noActiveMap)',
  'mapGridRegister':
      'lib/infrastructure/dtos/campaign_profile_dto.dart:909 (omitted when mapGridRegister is CampaignProfile.noMapGrid)',
  'mapTokens_crdt':
      'lib/infrastructure/dtos/campaign_profile_dto.dart:910 (omitted when _hasCrdtContent(mapTokensCrdt) is false)',
  'mapTokenCells_crdt':
      'lib/infrastructure/dtos/campaign_profile_dto.dart:911 (omitted when _hasCrdtContent(mapTokenCellsCrdt) is false)',
};

/// Known losses registry. Must only shrink over time; stale entries fail the law.
final List<KnownLoss> knownLosses = [
  for (final backupId in [
    'E1',
    'E2',
    'E3',
    'E4',
    'E5',
    'E6',
    'E7',
    'E8',
    'E9',
    'DB1',
    'DB2',
  ])
    for (final field in ['accent', 'haptic', 'rulesEdition', 'theme'])
      KnownLoss(
        id: 'KL-LB1-$backupId-settings.$field',
        fixture: backupId,
        check: 'LB1',
        path: 'settings.$field',
        reason:
            'lib/services/persistence/app_backup_service.dart:322 (importFullBackupJson parses backup.settings and ignores it)',
      ),
];

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
    final file = File('test/fixtures/legacy_storage/$era/$filename');
    if (!file.existsSync()) {
      throw StateError('Fixture file not found: ${file.path}');
    }
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  // Helper to get all storage fixtures including written and derived
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
    final e3 = map['E3']!;
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
    map['DB7'] = LegacyFixtureDerivations.deriveDB7(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DT'] = LegacyFixtureDerivations.deriveDT(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DPR'] = LegacyFixtureDerivations.deriveDPR(
      e3Storage: e3.storage,
      e3Facts: e3.facts,
    );
    map['DMC'] = LegacyFixtureDerivations.deriveDMC(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );
    map['DPP'] = LegacyFixtureDerivations.deriveDPP(
      e1Storage: e1.storage,
      e1Facts: e1.facts,
    );

    return map;
  }

  // Helper to get all app_backup fixtures (E1–E9 + DB1 + DB2)
  Map<String, ({Map<String, dynamic> backup, Map<String, dynamic> facts})>
      getAllAppBackups() {
    final map =
        <String, ({Map<String, dynamic> backup, Map<String, dynamic> facts})>{};
    for (final era in ['E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9']) {
      map[era] = (
        backup: loadFixtureJson(era, 'app_backup.json'),
        facts: loadFixtureJson(era, 'facts.json'),
      );
    }
    final e1Backup = map['E1']!.backup;
    final e1Facts = map['E1']!.facts;
    map['DB1'] = (
      backup: LegacyFixtureDerivations.deriveBackupSchemaVersion(
        e1AppBackup: e1Backup,
        schemaVersion: 1,
      ),
      facts: e1Facts,
    );
    map['DB2'] = (
      backup: LegacyFixtureDerivations.deriveBackupSchemaVersion(
        e1AppBackup: e1Backup,
        schemaVersion: 2,
      ),
      facts: e1Facts,
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

          final ll1Problems = LegacyFixtureSupport.applyKnownLosses(
            LegacyFixtureSupport.compareFacts(
              fixtureId,
              expectedFacts1,
              actualFacts1,
            ),
            knownLosses,
            fixture: fixtureId,
            check: 'LL1',
          );
          expect(
            ll1Problems,
            isEmpty,
            reason:
                'LL1 failed for fixture $fixtureId:\n${ll1Problems.join('\n')}',
          );

          // --- LL2: Saved back in today's format ---
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
          // and has the exact top-level key set of E9's campaign A record modulo kOptionalCampaignRecordKeys
          final e9Storage = fixtures['E9']!.storage;
          final e9CampA = (e9Storage['boxes']
                  [AppDatabaseService.boxCampaignProfiles]
              as Map)['dn5e_campaign_profile_campaign_LEGACYA'];
          final e9Keys = (e9CampA is String
                  ? (json.decode(e9CampA) as Map).keys
                  : (e9CampA as Map).keys)
              .map((k) => k.toString())
              .toSet();
          final requiredKeys =
              e9Keys.difference(kOptionalCampaignRecordKeys.keys.toSet());

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

            final actualKeySet = recordMap.keys.toSet();
            final missingRequired = requiredKeys.difference(actualKeySet);
            expect(
              missingRequired,
              isEmpty,
              reason:
                  'LL2 failed for $fixtureId: stored record $key missing required E9 keys: $missingRequired',
            );
            final unexpectedKeys = actualKeySet.difference(e9Keys);
            expect(
              unexpectedKeys,
              isEmpty,
              reason:
                  'LL2 failed for $fixtureId: stored record $key contains unexpected keys not in E9 keyset: $unexpectedKeys',
            );

            if (fixtureId == 'E9' &&
                key == 'dn5e_campaign_profile_campaign_LEGACYA') {
              expect(
                actualKeySet,
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

            final droppedProblems = LegacyFixtureSupport.applyKnownLosses(
              LegacyFixtureSupport.checkDroppedKeys(
                fixtureId,
                oldKey,
                oldRecord,
                currentRecord,
                migratedKeys,
              ),
              knownLosses,
              fixture: fixtureId,
              check: 'LL4',
            );
            expect(
              droppedProblems,
              isEmpty,
              reason: droppedProblems.join('\n'),
            );
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
            final seededDrBox = fixtureData.storage['boxes']
                [AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;
            final expectedCorrupt =
                seededDrBox['dn5e_campaign_profile_corrupt_record_raw'];
            final expectedVersion2 =
                seededDrBox['dn5e_campaign_profile_campaign_LEGACYA'];

            final rawCorrupt = db2.get(
              AppDatabaseService.boxCampaignProfiles,
              'dn5e_campaign_profile_corrupt_record_raw',
            );
            final rawVersion2 = db2.get(
              AppDatabaseService.boxCampaignProfiles,
              'dn5e_campaign_profile_campaign_LEGACYA',
            );

            expect(
              rawCorrupt,
              equals(expectedCorrupt),
              reason: 'LL5 failed: corrupt record modified in storage.',
            );
            expect(
              rawVersion2,
              equals(expectedVersion2),
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

  group('Legacy Backup Law: LB1 (All Era & Derived Backup Files)', () {
    final appBackups = getAllAppBackups();

    for (final entry in appBackups.entries) {
      final backupId = entry.key;
      final backupData = entry.value;

      test('LB1 for app_backup.json: $backupId', () async {
        final tempDir = await Directory.systemTemp
            .createTemp('legacy_backup_app_${backupId}_');
        try {
          // 1. Seed SharedPreferences with settings that differ in all 4 fields from facts.json
          SharedPreferences.setMockInitialValues({
            'setting_theme_mode_v2': 'light',
            'setting_fantasy_accent_v2': 'arcaneSapphire',
            'setting_haptic_level_v2': 'heavy',
            'setting_rules_edition_v2': 'v2014',
          });
          await LegacyFixtureSupport.boot(tempDir);

          final backupJson = json.encode(backupData.backup);

          // 2. Import backup
          final result =
              await AppBackupService().importFullBackupJson(backupJson);
          expect(
            result.success,
            isTrue,
            reason:
                'LB1 import failed for $backupId app_backup.json: ${result.errorMessage}',
          );

          // 3. Compute post-import facts and compare settings against facts.json
          final db1 = AppDatabaseService.instance;
          final prefs1 = await SharedPreferences.getInstance();
          final campRepo1 = sl<ICampaignRepository>();
          final charRepo1 = LocalCharacterRepository(db: db1);
          final regService1 = CampaignRegistryService();

          final actualFacts1 = await LegacyFixtureSupport.computeTodayFacts(
            campRepo1,
            charRepo1,
            regService1,
            prefs1,
          );

          final settingsProblems = LegacyFixtureSupport.applyKnownLosses(
            LegacyFixtureSupport.compareFacts(
              backupId,
              {'settings': backupData.facts['settings']},
              {'settings': actualFacts1['settings']},
            ),
            knownLosses,
            fixture: backupId,
            check: 'LB1',
          );
          expect(
            settingsProblems,
            isEmpty,
            reason:
                'LB1 settings check failed for $backupId:\n${settingsProblems.join('\n')}',
          );

          // 4. Take snapshot after boot 1
          final snapshotAfterBoot1 =
              await LegacyFixtureSupport.takeSnapshot(db1, prefs1);

          // 5. Close DB before Boot 2
          await db1.close();

          // 6. LL3: Second load changes nothing
          await LegacyFixtureSupport.boot(tempDir);
          final prefs2 = await SharedPreferences.getInstance();
          final snapshotBoot2 = await LegacyFixtureSupport.takeSnapshot(
            AppDatabaseService.instance,
            prefs2,
          );

          expect(
            snapshotBoot2,
            equals(snapshotAfterBoot1),
            reason:
                'LB1 LL3 failed for $backupId app_backup.json: Boot 2 snapshot changed.',
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

    for (final era in ['E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9']) {
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
          expect(
            imported,
            isNotNull,
            reason: 'LB1 import returned null for $era dm_profile.json',
          );

          final db1 = AppDatabaseService.instance;
          final prefs1 = await SharedPreferences.getInstance();
          final campRepo1 = sl<ICampaignRepository>();
          final charRepo1 = LocalCharacterRepository(db: db1);
          final regService1 = CampaignRegistryService();

          final loaded = await campRepo1.getProfile(imported!.id);
          expect(
            loaded,
            isNotNull,
            reason: 'LB1 loaded profile was null after import for $era',
          );

          // 3. Compute full campaign facts for the imported campaign and compare all fields
          // against Campaign A's entry in facts.json (adjusted by adjustFactsForLL1)
          final actualFacts1 = await LegacyFixtureSupport.computeTodayFacts(
            campRepo1,
            charRepo1,
            regService1,
            prefs1,
          );
          final actualCampaigns =
              (actualFacts1['campaigns'] as List<dynamic>).cast<Map>();
          final importedCampFact = Map<String, dynamic>.from(
            actualCampaigns.firstWhere((c) => c['id'] == imported.id),
          );
          // DmBackupService.validateAndImportProfile assigns a new generated id on import;
          // normalize id to campaign_LEGACYA to compare all campaign fact fields.
          importedCampFact['id'] = 'campaign_LEGACYA';

          final adjustedExpected = adjustFactsForLL1(
            loadFixtureJson(era, 'facts.json'),
            isAdoptedRegistryExpected: false,
          );
          final expectedCampA = Map<String, dynamic>.from(
            (adjustedExpected['campaigns'] as List<dynamic>)
                .cast<Map>()
                .firstWhere((c) => c['id'] == 'campaign_LEGACYA'),
          );

          final dmProblems = LegacyFixtureSupport.applyKnownLosses(
            LegacyFixtureSupport.compareFacts(
              'DM_$era',
              {'campaigns': [expectedCampA]},
              {'campaigns': [importedCampFact]},
            ),
            knownLosses,
            fixture: 'DM_$era',
            check: 'LB1',
          );
          expect(
            dmProblems,
            isEmpty,
            reason:
                'LB1 dm_profile.json check failed for $era:\n${dmProblems.join('\n')}',
          );

          final snapshotAfterBoot1 =
              await LegacyFixtureSupport.takeSnapshot(db1, prefs1);

          // 4. Close DB before Boot 2
          await db1.close();

          // 5. LL3: Second load changes nothing
          await LegacyFixtureSupport.boot(tempDir);
          final prefs2 = await SharedPreferences.getInstance();
          final snapshotBoot2 = await LegacyFixtureSupport.takeSnapshot(
            AppDatabaseService.instance,
            prefs2,
          );

          expect(
            snapshotBoot2,
            equals(snapshotAfterBoot1),
            reason:
                'LB1 LL3 failed for $era dm_profile.json: Boot 2 snapshot changed.',
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

  group('Inventory & Control Tests: LI1–LI4, LC1–LC3, LC5', () {
    Map<String, Map<String, dynamic>> buildRawFixturesMap() {
      final rawMap = <String, Map<String, dynamic>>{};
      final storageFixtures = getAllFixtures();
      for (final entry in storageFixtures.entries) {
        rawMap[entry.key] = entry.value.storage;
      }
      final backupFixtures = getAllAppBackups();
      rawMap['DB1'] = backupFixtures['DB1']!.backup;
      rawMap['DB2'] = backupFixtures['DB2']!.backup;
      for (final era in [
        'E1',
        'E2',
        'E3',
        'E4',
        'E5',
        'E6',
        'E7',
        'E8',
        'E9',
      ]) {
        rawMap['DM_$era'] = loadFixtureJson(era, 'dm_profile.json');
      }
      return rawMap;
    }

    test('LI1: README.md inventory table matches legacyInventory in order', () {
      final readme =
          File('test/fixtures/legacy_storage/README.md').readAsStringSync();
      final problems = LegacyFixtureSupport.checkInventoryReadmeAgreement(
        readme,
        legacyInventory,
      );
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('LI2: Every named fixture in legacyInventory has the claimed raw shape', () {
      final rawFixtures = buildRawFixturesMap();
      final problems = LegacyFixtureSupport.checkInventoryPredicates(
        legacyInventory,
        rawFixtures,
      );
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('LI3: Every file, symbol, and unit-test path in legacyInventory exists', () {
      final problems =
          LegacyFixtureSupport.checkInventoryFilesAndSymbols(legacyInventory);
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('LI4: Control: inventory checker fails on false predicate and disallowed reason', () {
      final rawFixtures = buildRawFixturesMap();

      // 1. Copy of legacyInventory where B7's predicate returns false
      final badPredicateInventory = [
        for (final row in legacyInventory)
          if (row.id == 'B7')
            LegacyInventoryRow(
              id: row.id,
              filePath: row.filePath,
              symbol: row.symbol,
              oldShape: row.oldShape,
              fixtures: [FixturePredicate('DB7', (_) => false)],
            )
          else
            row,
      ];
      final predProblems = LegacyFixtureSupport.checkInventoryPredicates(
        badPredicateInventory,
        rawFixtures,
      );
      expect(predProblems, isNotEmpty);
      expect(predProblems.join('\n'), contains('B7'));

      // 2. Copy of legacyInventory where B13 has a disallowed reason string
      final badReasonInventory = [
        for (final row in legacyInventory)
          if (row.id == 'B13')
            LegacyInventoryRow(
              id: row.id,
              filePath: row.filePath,
              symbol: row.symbol,
              oldShape: row.oldShape,
              reason: 'prose excuse with no test check',
            )
          else
            row,
      ];
      final reasonProblems = LegacyFixtureSupport.checkInventoryFilesAndSymbols(
        badReasonInventory,
      );
      expect(reasonProblems, isNotEmpty);
      expect(reasonProblems.join('\n'), contains('B13'));
    });

    test('LC1: Tampered campaign name fails compareFacts and names fixture, campaign, and field', () {
      final expectedFacts = adjustFactsForLL1(loadFixtureJson('E9', 'facts.json'));
      final tamperedFacts =
          json.decode(json.encode(expectedFacts)) as Map<String, dynamic>;
      final tamperedCamp = (tamperedFacts['campaigns'] as List)
          .firstWhere((c) => c['id'] == 'campaign_LEGACYA') as Map<String, dynamic>;
      tamperedCamp['name'] = 'Tampered Name For Control Test';

      final problems = LegacyFixtureSupport.compareFacts(
        'E9',
        expectedFacts,
        tamperedFacts,
      );
      expect(problems, isNotEmpty);
      expect(
        problems.join('\n'),
        allOf(
          contains('E9'),
          contains('campaign_LEGACYA'),
          contains('name'),
        ),
      );
    });

    test('LC2: Dropping a key from record fails checkDroppedKeys and names the key', () {
      const droppedKey = 'partyCharacterIds';
      final oldRecord = <String, dynamic>{
        'id': 'campaign_LEGACYA',
        'name': 'Campaign A',
        droppedKey: ['char_fighter'],
      };
      final currentRecord = <String, dynamic>{
        'id': 'campaign_LEGACYA',
        'name': 'Campaign A',
      };

      final problems = LegacyFixtureSupport.checkDroppedKeys(
        'E1',
        'dn5e_campaign_profile_campaign_LEGACYA',
        oldRecord,
        currentRecord,
        migratedKeys,
      );
      expect(problems, isNotEmpty);
      expect(problems.join('\n'), contains(droppedKey));
    });

    test('LC3: MANIFEST.json matches files via checkManifest and fails on tampered sha256', () {
      final liveProblems = LegacyFixtureSupport.checkManifest();
      expect(liveProblems, isEmpty, reason: liveProblems.join('\n'));

      final manifestFile = File('test/fixtures/legacy_storage/MANIFEST.json');
      final manifestList =
          json.decode(manifestFile.readAsStringSync()) as List<dynamic>;
      final tampered = List<Map<String, dynamic>>.from(
        manifestList.map((m) => Map<String, dynamic>.from(m as Map)),
      );
      final targetPath = tampered[0]['path'] as String;
      tampered[0]['sha256'] =
          '0000000000000000000000000000000000000000000000000000000000000000';

      final tamperedProblems =
          LegacyFixtureSupport.checkManifest(manifestOverride: tampered);
      expect(tamperedProblems, isNotEmpty);
      expect(tamperedProblems.join('\n'), contains(targetPath));
    });

    test('LC5: applyKnownLosses reports stale KnownLoss when expected problem does not occur', () {
      const dummyLoss = KnownLoss(
        id: 'KL-CONTROL-STALE',
        fixture: 'E1',
        check: 'LL1',
        path: 'settings.theme',
        reason: 'control test dummy loss',
      );
      final problems = LegacyFixtureSupport.applyKnownLosses(
        const [],
        const [dummyLoss],
        fixture: 'E1',
        check: 'LL1',
      );
      expect(problems, isNotEmpty);
      expect(problems.join('\n'), contains('KL-CONTROL-STALE'));
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
        print(
            '- [${loss.id}] ${loss.fixture} ${loss.check} (${loss.path}): ${loss.reason}');
      }
    }
    // ignore: avoid_print
    print('========================================\n');
  });
}
