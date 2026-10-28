import 'dart:convert';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

/// A single predicate over a fixture's raw stored data (before any boot).
class FixturePredicate {
  final String fixtureId;
  final bool Function(Map<String, dynamic> rawData) predicate;

  const FixturePredicate(this.fixtureId, this.predicate);
}

/// A single row in the Legacy Shape Readers inventory.
class LegacyInventoryRow {
  final String id;
  final String filePath;
  final String symbol;
  final String oldShape;
  final List<FixturePredicate> fixtures;
  final String? reason;

  const LegacyInventoryRow({
    required this.id,
    required this.filePath,
    required this.symbol,
    required this.oldShape,
    this.fixtures = const [],
    this.reason,
  });

  String get fileAndSymbol => '$filePath: $symbol';

  String get fixtureOrReason =>
      reason ?? fixtures.map((f) => f.fixtureId).join(', ');
}

Map<String, dynamic> _decodeCampaignA(Map<String, dynamic> rawData) {
  final boxes = rawData['boxes'] as Map<String, dynamic>? ?? {};
  final campBox =
      boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>? ??
          {};
  final raw = campBox['dn5e_campaign_profile_campaign_LEGACYA'];
  if (raw is String) {
    return json.decode(raw) as Map<String, dynamic>;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return const {};
}

bool _hasStorageBoxesAndPrefs(Map<String, dynamic> rawData) =>
    rawData['boxes'] is Map && rawData['prefs'] is Map;

bool _hasUnmappedLegc03Registry(Map<String, dynamic> rawData) {
  final prefs = rawData['prefs'] as Map<String, dynamic>? ?? {};
  final reg = prefs['user_campaign_registry'];
  if (reg is! Map) return false;
  final list = reg['v'];
  if (list is! List) return false;
  final hasLegc03 = list.any((e) => e.toString().contains('"roomCode":"LEGC03"'));
  final boxes = rawData['boxes'] as Map<String, dynamic>? ?? {};
  final campBox =
      boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>? ??
          {};
  return hasLegc03 && !campBox.containsKey('dn5e_campaign_profile_campaign_LEGC03');
}

bool _lacksRecordVersion(Map<String, dynamic> rawData) =>
    !_decodeCampaignA(rawData).containsKey('recordVersion');

bool _lacksPartyRosterCrdtWithStringIds(Map<String, dynamic> rawData) {
  final campA = _decodeCampaignA(rawData);
  final ids = campA['partyCharacterIds'];
  return !campA.containsKey('partyRoster_crdt') &&
      ids is List &&
      ids.isNotEmpty &&
      ids.every((e) => e is String);
}

bool _lacksPinnedRulesCrdtAndMap(Map<String, dynamic> rawData) {
  final campA = _decodeCampaignA(rawData);
  return !campA.containsKey('pinnedRules_crdt') &&
      !campA.containsKey('pinnedRules') &&
      campA['pinnedRuleIds'] is List;
}

bool _lacksNameRegister(Map<String, dynamic> rawData) {
  final campA = _decodeCampaignA(rawData);
  return !campA.containsKey('nameRegister') && campA['name'] is String;
}

bool _lacksMemberPurses(Map<String, dynamic> rawData) =>
    !_decodeCampaignA(rawData).containsKey('memberPurses');

bool _lacksMapAndTokenCrdtFields(Map<String, dynamic> rawData) {
  final campA = _decodeCampaignA(rawData);
  return !campA.containsKey('activeMapRegister') &&
      !campA.containsKey('mapGridRegister') &&
      !campA.containsKey('mapTokens_crdt') &&
      !campA.containsKey('mapTokenCells_crdt') &&
      !campA.containsKey('minionOwners_crdt');
}

const List<String> _allStorageFixtureIds = [
  'E1',
  'E2',
  'E3',
  'E4',
  'E5',
  'E6',
  'E7',
  'E8',
  'E9',
  'DP',
  'DE',
  'DM',
  'DS',
  'DR',
  'DB7',
  'DT',
  'DPR',
  'DMC',
  'DPP',
];

const List<String> _allBackupEraIds = [
  'E1',
  'E2',
  'E3',
  'E4',
  'E5',
  'E6',
  'E7',
  'E8',
  'E9',
];

final List<LegacyInventoryRow> legacyInventory = [
  LegacyInventoryRow(
    id: 'B1',
    filePath: 'lib/main.dart',
    symbol: 'completeNormalStartup',
    oldShape:
        'Unmigrated startup sequence: opens storage, extracts legacy characters, adopts unlinked registry memberships, executes schema migrations',
    fixtures: [
      for (final id in _allStorageFixtureIds)
        FixturePredicate(id, _hasStorageBoxesAndPrefs),
    ],
  ),
  LegacyInventoryRow(
    id: 'B2',
    filePath: 'lib/infrastructure/repositories/local_campaign_repository.dart',
    symbol: '_loadSavedRecords',
    oldShape:
        'SharedPreferences fallback for campaign profile index list (`dn5e_campaign_profile_index`)',
    fixtures: [
      FixturePredicate('DP', (raw) {
        final boxes = raw['boxes'] as Map<String, dynamic>? ?? {};
        final campBox = boxes[AppDatabaseService.boxCampaignProfiles]
                as Map<String, dynamic>? ??
            {};
        final prefs = raw['prefs'] as Map<String, dynamic>? ?? {};
        final idx = prefs['dn5e_campaign_profile_index'];
        return !campBox.containsKey('dn5e_campaign_profile_index') &&
            idx is Map &&
            idx['v'] is List;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B3',
    filePath: 'lib/infrastructure/repositories/local_campaign_repository.dart',
    symbol: '_loadSavedRecords',
    oldShape:
        'SharedPreferences fallback for individual campaign profile JSON records (`dn5e_campaign_profile_<id>`) copied to Hive on read',
    fixtures: [
      FixturePredicate('DP', (raw) {
        final boxes = raw['boxes'] as Map<String, dynamic>? ?? {};
        final campBox = boxes[AppDatabaseService.boxCampaignProfiles]
                as Map<String, dynamic>? ??
            {};
        final prefs = raw['prefs'] as Map<String, dynamic>? ?? {};
        final rec = prefs['dn5e_campaign_profile_campaign_LEGACYA'];
        return !campBox
                .containsKey('dn5e_campaign_profile_campaign_LEGACYA') &&
            rec is Map &&
            rec['v'] is String;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B4',
    filePath: 'lib/infrastructure/repositories/local_campaign_repository.dart',
    symbol: '_loadSavedRecords',
    oldShape:
        'SharedPreferences fallback for active campaign profile ID (`dn5e_campaign_active_id`)',
    fixtures: [
      FixturePredicate('DP', (raw) {
        final boxes = raw['boxes'] as Map<String, dynamic>? ?? {};
        final campBox = boxes[AppDatabaseService.boxCampaignProfiles]
                as Map<String, dynamic>? ??
            {};
        final prefs = raw['prefs'] as Map<String, dynamic>? ?? {};
        final active = prefs['dn5e_campaign_active_id'];
        return !campBox.containsKey('dn5e_campaign_active_id') &&
            active is Map &&
            active['v'] is String;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B5',
    filePath: 'lib/infrastructure/repositories/local_campaign_repository.dart',
    symbol: '_loadSavedRecords',
    oldShape:
        'Corrupted JSON or unsupported `recordVersion` records preserved in `_rejectedProfileIds` without halting valid profile loading',
    fixtures: [
      FixturePredicate('DR', (raw) {
        final boxes = raw['boxes'] as Map<String, dynamic>? ?? {};
        final campBox = boxes[AppDatabaseService.boxCampaignProfiles]
                as Map<String, dynamic>? ??
            {};
        final corrupt = campBox['dn5e_campaign_profile_corrupt_record_raw'];
        final campA = _decodeCampaignA(raw);
        return corrupt is String &&
            !corrupt.trim().endsWith('}') &&
            campA['recordVersion'] == 2;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B6',
    filePath: 'lib/infrastructure/repositories/local_character_repository.dart',
    symbol: 'loadCharacters',
    oldShape:
        'SharedPreferences fallback for character roster (`saved_characters_roster_v1`)',
    fixtures: [
      FixturePredicate('DP', (raw) {
        final boxes = raw['boxes'] as Map<String, dynamic>? ?? {};
        final charBox =
            boxes[AppDatabaseService.boxCharacters] as Map<String, dynamic>? ??
                {};
        final prefs = raw['prefs'] as Map<String, dynamic>? ?? {};
        final roster = prefs['saved_characters_roster_v1'];
        return !charBox.containsKey('saved_characters_roster_v1') &&
            roster is Map &&
            roster['v'] is String;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B7',
    filePath: 'lib/infrastructure/repositories/local_character_repository.dart',
    symbol: '_loadRawPersistedRoster',
    oldShape:
        'Character roster stored as raw JSON string instead of Hive List in `boxCharacters`',
    fixtures: [
      FixturePredicate('DB7', (raw) {
        final boxes = raw['boxes'] as Map<String, dynamic>? ?? {};
        final charBox =
            boxes[AppDatabaseService.boxCharacters] as Map<String, dynamic>? ??
                {};
        return charBox['saved_characters_roster_v1'] is String;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B8',
    filePath:
        'lib/infrastructure/repositories/campaign_storage_migration.dart',
    symbol: 'migrateLegacyCharacters',
    oldShape:
        'Embedded character map objects in campaign `partyRoster` / `partyCharacterIds` extracted into `CharacterPersistenceService` and stripped from campaign record',
    fixtures: [
      FixturePredicate('DE', (raw) {
        final campA = _decodeCampaignA(raw);
        final roster = campA['partyRoster'];
        return roster is List &&
            roster.isNotEmpty &&
            roster.every((e) => e is Map);
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B9',
    filePath:
        'lib/infrastructure/repositories/campaign_storage_migration.dart',
    symbol: 'adoptRegistryMemberships',
    oldShape:
        'Unmapped `CampaignRegistryService` memberships adopted into repository as synthesized `campaign_<roomCode>` profiles',
    fixtures: [
      for (final id in _allStorageFixtureIds)
        FixturePredicate(id, _hasUnmappedLegc03Registry),
    ],
  ),
  LegacyInventoryRow(
    id: 'B10',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape: 'Missing top-level `recordVersion` defaults to legacy 0',
    fixtures: [
      for (final id in ['E1', 'E2', 'E3', 'E4', 'E5'])
        FixturePredicate(id, _lacksRecordVersion),
    ],
  ),
  LegacyInventoryRow(
    id: 'B11',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Missing `createdAt` defaults to deterministic Unix epoch UTC (characterization of `campaign_profile_dto.dart:399`)',
    fixtures: [
      FixturePredicate(
        'DT',
        (raw) => !_decodeCampaignA(raw).containsKey('createdAt'),
      ),
    ],
  ),
  LegacyInventoryRow(
    id: 'B12',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Missing `lastPlayedAt` defaults to `createdAt` (characterization of `campaign_profile_dto.dart:414`)',
    fixtures: [
      FixturePredicate(
        'DT',
        (raw) => !_decodeCampaignA(raw).containsKey('lastPlayedAt'),
      ),
    ],
  ),
  const LegacyInventoryRow(
    id: 'B13',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Missing `roomState` synthesizes default `RoomNodeState` with deterministic `CR-` room code',
    reason: 'unit test: test/application/services/crdt_pass_4_closure_test.dart',
  ),
  LegacyInventoryRow(
    id: 'B14',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Legacy `partyCharacterIds` / `partyRoster` list of string IDs fallback when `partyRoster_crdt` absent',
    fixtures: [
      for (final id in ['E1', 'E2'])
        FixturePredicate(id, _lacksPartyRosterCrdtWithStringIds),
    ],
  ),
  LegacyInventoryRow(
    id: 'B15',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Legacy `partyCharacterIds` / `partyRoster` list of character map objects deserialized to character slugs',
    fixtures: [
      FixturePredicate('DE', (raw) {
        final campA = _decodeCampaignA(raw);
        final roster = campA['partyRoster'];
        return !campA.containsKey('partyRoster_crdt') &&
            roster is List &&
            roster.isNotEmpty &&
            roster.every((e) => e is Map);
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B16',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Legacy root `activeMinions` list migrated into `roomState.activeMinions`',
    fixtures: [
      FixturePredicate('DM', (raw) {
        final campA = _decodeCampaignA(raw);
        final rootMinions = campA['activeMinions'];
        final room = campA['roomState'] as Map<String, dynamic>? ?? {};
        return rootMinions is List &&
            rootMinions.isNotEmpty &&
            !room.containsKey('activeMinions') &&
            !room.containsKey('activeMinions_crdt');
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B17',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Legacy `pinnedRules` map fallback for `pinnedRules_crdt` (characterization of `campaign_profile_dto.dart:545`)',
    fixtures: [
      FixturePredicate('DPR', (raw) {
        final campA = _decodeCampaignA(raw);
        return !campA.containsKey('pinnedRules_crdt') &&
            campA['pinnedRules'] is Map;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B18',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Legacy `pinnedRuleIds` list fallback when neither `pinnedRules_crdt` nor `pinnedRules` present',
    fixtures: [
      for (final id in ['E1', 'E2'])
        FixturePredicate(id, _lacksPinnedRulesCrdtAndMap),
    ],
  ),
  LegacyInventoryRow(
    id: 'B19',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Missing `nameRegister` falls back to top-level `name` and null domain register',
    fixtures: [
      for (final id in ['E1', 'E2', 'E3'])
        FixturePredicate(id, _lacksNameRegister),
    ],
  ),
  LegacyInventoryRow(
    id: 'B20',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape: 'Missing `memberPurses` map defaults to empty map',
    fixtures: [
      for (final id in ['E1', 'E2', 'E3', 'E4'])
        FixturePredicate(id, _lacksMemberPurses),
    ],
  ),
  LegacyInventoryRow(
    id: 'B21',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'CampaignProfileDto.fromMap',
    oldShape:
        'Missing map and token CRDT fields (`activeMapRegister`, `mapGridRegister`, `mapTokens_crdt`, `mapTokenCells_crdt`, `minionOwners_crdt`) default to empty registers/sets',
    fixtures: [
      for (final id in ['E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7'])
        FixturePredicate(id, _lacksMapAndTokenCrdtFields),
    ],
  ),
  LegacyInventoryRow(
    id: 'B22',
    filePath: 'lib/infrastructure/dtos/campaign_edition_codec.dart',
    symbol: 'parseStoredCampaignEdition',
    oldShape:
        'Legacy edition strings (`generic_tabletop`, `unknown`, empty/whitespace) mapped to `RulesetEdition.v2024`',
    fixtures: [
      FixturePredicate(
        'E1',
        (raw) => _decodeCampaignA(raw)['edition'] == 'generic_tabletop',
      ),
    ],
  ),
  LegacyInventoryRow(
    id: 'B23',
    filePath: 'lib/infrastructure/dtos/minion_instance_dto.dart',
    symbol: 'MinionInstanceDto.fromMap',
    oldShape:
        'Legacy integer `customAccentColor` mapped to `alpha` marker (characterization of `minion_instance_dto.dart:160`)',
    fixtures: [
      FixturePredicate('DMC', (raw) {
        final campA = _decodeCampaignA(raw);
        final room = campA['roomState'] as Map<String, dynamic>? ?? {};
        final minions = room['activeMinions'];
        if (minions is! List || minions.isEmpty) return false;
        final first = minions.first;
        return first is Map &&
            !first.containsKey('marker') &&
            first['customAccentColor'] is int;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B24',
    filePath: 'lib/services/persistence/storage_migration_service.dart',
    symbol: '_migrateV1ToV2',
    oldShape:
        'Legacy v1 integer enum settings keys (`setting_theme_mode`, `setting_fantasy_accent`, `setting_haptic_level`, `setting_rules_edition`) migrated to v2 string keys',
    fixtures: [
      FixturePredicate('DS', (raw) {
        final prefs = raw['prefs'] as Map<String, dynamic>? ?? {};
        return prefs['setting_theme_mode'] is Map &&
            (prefs['setting_theme_mode'] as Map)['t'] == 'i' &&
            prefs['setting_fantasy_accent'] is Map &&
            (prefs['setting_fantasy_accent'] as Map)['t'] == 'i' &&
            prefs['setting_haptic_level'] is Map &&
            (prefs['setting_haptic_level'] as Map)['t'] == 'i' &&
            prefs['setting_rules_edition'] is Map &&
            (prefs['setting_rules_edition'] as Map)['t'] == 'i';
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B25',
    filePath: 'lib/services/persistence/app_backup_service.dart',
    symbol: 'importFullBackupJson',
    oldShape: 'Schema version 1 and 2 backup envelopes restored',
    fixtures: [
      FixturePredicate('DB1', (raw) => raw['schemaVersion'] == 1),
      FixturePredicate('DB2', (raw) => raw['schemaVersion'] == 2),
    ],
  ),
  LegacyInventoryRow(
    id: 'B26',
    filePath: 'lib/services/persistence/dm_backup_service.dart',
    symbol: 'validateAndImportProfile',
    oldShape: 'Schema version 1 campaign profile JSON snapshot files restored',
    fixtures: [
      for (final id in _allBackupEraIds)
        FixturePredicate('DM_$id', (raw) {
          return raw['schemaVersion'] == 1 &&
              raw['type'] == 'campaign_profile' &&
              raw['campaign'] is Map;
        }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B27',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'PartyPurse.fromMap',
    oldShape:
        "Legacy scalar coin values without counters migrated to initial PN-counter with `'init'` slot",
    fixtures: [
      FixturePredicate('DPP', (raw) {
        final campA = _decodeCampaignA(raw);
        final purse = campA['partyPurse'];
        if (purse is! Map) return false;
        final hasScalar = purse['gp'] is num || purse['sp'] is num;
        final hasCounters = purse.containsKey('denominationCounters') ||
            purse.containsKey('customCounters') ||
            purse.keys.any((k) => k.toString().toLowerCase().endsWith('counter'));
        return hasScalar && !hasCounters;
      }),
    ],
  ),
  LegacyInventoryRow(
    id: 'B28',
    filePath: 'lib/infrastructure/dtos/campaign_profile_dto.dart',
    symbol: 'RoomNodeState.fromMap',
    oldShape:
        'Legacy list-form `entityLinks` migrated into `EntityLinkCrdtSet` with genesis timestamps',
    fixtures: [
      for (final id in ['E1', 'E2'])
        FixturePredicate(id, (raw) {
          final campA = _decodeCampaignA(raw);
          final room = campA['roomState'] as Map<String, dynamic>? ?? {};
          return !room.containsKey('entityLinks_crdt') &&
              room['entityLinks'] is List &&
              (room['entityLinks'] as List).isNotEmpty;
        }),
    ],
  ),
  const LegacyInventoryRow(
    id: 'B29',
    filePath: 'lib/services/persistence/homebrew_persistence_service.dart',
    symbol: 'HomebrewPersistenceService',
    oldShape: 'Legacy homebrew store formats',
    reason: 'not covered: later slice',
  ),
  const LegacyInventoryRow(
    id: 'B30',
    filePath: 'lib/infrastructure/migration/party_ledger_legacy_import.dart',
    symbol: 'PartyLedgerLegacyImport',
    oldShape: 'Old Firestore room documents (not local storage)',
    reason: 'not covered: later slice',
  ),
];
