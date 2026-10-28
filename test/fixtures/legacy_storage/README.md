# Legacy Campaign Storage Safety Net

This directory contains golden fixtures, stored facts, and generator sources for older campaign storage schemas.
These fixtures form the safety net for Cleanup slice 3 and all future cleanup slices: CI verifies via `test/infrastructure/legacy/legacy_load_law_test.dart` that data saved by earlier versions of the app still loads cleanly without data loss.

## Invariant: Data Fixtures Never Change

No file named `storage.json`, `facts.json`, `app_backup.json`, or `dm_profile.json` under `test/fixtures/legacy_storage/` is ever edited, regenerated, or deleted. New or historical edge-case shapes not emitted by the 9 era generators (`E1`–`E9`) are covered by derived fixtures built in code (`test/infrastructure/legacy/legacy_fixture_derivations.dart`). Every row of the legacy inventory below is a checked claim in `test/infrastructure/legacy/legacy_inventory.dart`.

## Historical Notes & Characterization

- **Edition Fact in `facts.json` (`E1`):** The edition fact in `facts.json` is the stored string (`"generic_tabletop"` in `E1/storage.json`). `E1`'s own code reads `generic_tabletop` as `v2014` because `RulesetEdition.fromString` falls through to `RulesetEdition.v2014` (`test/fixtures/legacy_storage/E1/writer_test.dart.txt`), and today's codec maps `generic_tabletop` to `v2024` on purpose (Pass 12 decision, `lib/infrastructure/dtos/campaign_edition_codec.dart`).
- **Characterization Derivations (`DT`, `DPR`, `DMC`, `DB1`/`DB2`, `DPP`):** For rows `B11`/`B12` (`DT`), `B17` (`DPR`), `B23` (`DMC`), `B25` (`DB1`/`DB2`), and `B27` (`DPP`), git history shows that no writer in the repository ever emitted those legacy fallback shapes (`CampaignProfile.toMap` at `fd74268` always wrote ISO-8601 `createdAt`/`lastPlayedAt` and never wrote a `pinnedRules` map; `MinionInstance.toMap` at `fd74268` never wrote `customAccentColor`; `AppBackupPayload.currentSchemaVersion` was already `3` at `fd74268`; `PartyPurse.toMap` at `e5ecce3` in `vtt-engine-core` always wrote counter maps). Those derived fixtures are constructed directly from the production read branches and their expected outputs follow those branches (characterization rather than independent historical writer evidence).
- **Full App Backup Settings Restore (`LB1`):** Prior to Cleanup slice 4.1, `AppBackupService.importFullBackupJson` parsed `backup.settings` from `app_backup.json` and ignored it. In Part 0 of Cleanup slice 4.1, `LB1` seeded `SharedPreferences` with non-default settings before importing `app_backup.json` and recorded the resulting 44 losses in `knownLosses`; the loss was fixed in Part B of Cleanup slice 4.1 (`lib/services/persistence/app_backup_settings_codec.dart`) and the `knownLosses` entries were removed.

## Inventory of Legacy Shape Readers

The table below catalogs every location in the app and engine core that accepts an older stored shape.

| Id | File and Symbol | Old Shape Accepted | Fixture or Reason |
|---|---|---|---|
| B1 | `lib/main.dart: completeNormalStartup` | Unmigrated startup sequence: opens storage, extracts legacy characters, adopts unlinked registry memberships, executes schema migrations | E1, E2, E3, E4, E5, E6, E7, E8, E9, DP, DE, DM, DS, DR, DB7, DT, DPR, DMC, DPP |
| B2 | `lib/infrastructure/repositories/local_campaign_repository.dart: _loadSavedRecords` | SharedPreferences fallback for campaign profile index list (`dn5e_campaign_profile_index`) | DP |
| B3 | `lib/infrastructure/repositories/local_campaign_repository.dart: _loadSavedRecords` | SharedPreferences fallback for individual campaign profile JSON records (`dn5e_campaign_profile_<id>`) copied to Hive on read | DP |
| B4 | `lib/infrastructure/repositories/local_campaign_repository.dart: _loadSavedRecords` | SharedPreferences fallback for active campaign profile ID (`dn5e_campaign_active_id`) | DP |
| B5 | `lib/infrastructure/repositories/local_campaign_repository.dart: _loadSavedRecords` | Corrupted JSON or unsupported `recordVersion` records preserved in `_rejectedProfileIds` without halting valid profile loading | DR |
| B6 | `lib/infrastructure/repositories/local_character_repository.dart: loadCharacters` | SharedPreferences fallback for character roster (`saved_characters_roster_v1`) | DP |
| B7 | `lib/infrastructure/repositories/local_character_repository.dart: _loadRawPersistedRoster` | Character roster stored as raw JSON string instead of Hive List in `boxCharacters` | DB7 |
| B8 | `lib/infrastructure/repositories/campaign_storage_migration.dart: migrateLegacyCharacters` | Embedded character map objects in campaign `partyRoster` / `partyCharacterIds` extracted into `CharacterPersistenceService` and stripped from campaign record | DE |
| B9 | `lib/infrastructure/repositories/campaign_storage_migration.dart: adoptRegistryMemberships` | Unmapped `CampaignRegistryService` memberships adopted into repository as synthesized `campaign_<roomCode>` profiles | E1, E2, E3, E4, E5, E6, E7, E8, E9, DP, DE, DM, DS, DR, DB7, DT, DPR, DMC, DPP |
| B10 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing top-level `recordVersion` defaults to legacy 0 | E1, E2, E3, E4, E5 |
| B11 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `createdAt` defaults to deterministic Unix epoch UTC (characterization of `campaign_profile_dto.dart:399`) | DT |
| B12 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `lastPlayedAt` defaults to `createdAt` (characterization of `campaign_profile_dto.dart:414`) | DT |
| B13 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `roomState` synthesizes default `RoomNodeState` with deterministic `CR-` room code | unit test: test/application/services/crdt_pass_4_closure_test.dart |
| B14 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `partyCharacterIds` / `partyRoster` list of string IDs fallback when `partyRoster_crdt` absent | E1, E2 |
| B15 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `partyCharacterIds` / `partyRoster` list of character map objects deserialized to character slugs | DE |
| B16 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy root `activeMinions` list migrated into `roomState.activeMinions` | DM |
| B17 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `pinnedRules` map fallback for `pinnedRules_crdt` (characterization of `campaign_profile_dto.dart:545`) | DPR |
| B18 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `pinnedRuleIds` list fallback when neither `pinnedRules_crdt` nor `pinnedRules` present | E1, E2 |
| B19 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `nameRegister` falls back to top-level `name` and null domain register | E1, E2, E3 |
| B20 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `memberPurses` map defaults to empty map | E1, E2, E3, E4 |
| B21 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing map and token CRDT fields (`activeMapRegister`, `mapGridRegister`, `mapTokens_crdt`, `mapTokenCells_crdt`, `minionOwners_crdt`) default to empty registers/sets | E1, E2, E3, E4, E5, E6, E7 |
| B22 | `lib/infrastructure/dtos/campaign_edition_codec.dart: parseStoredCampaignEdition` | Legacy edition strings (`generic_tabletop`, `unknown`, empty/whitespace) mapped to `RulesetEdition.v2024` | E1 |
| B23 | `lib/infrastructure/dtos/minion_instance_dto.dart: MinionInstanceDto.fromMap` | Legacy integer `customAccentColor` mapped to `alpha` marker (characterization of `minion_instance_dto.dart:160`) | DMC |
| B24 | `lib/services/persistence/storage_migration_service.dart: _migrateV1ToV2` | Legacy v1 integer enum settings keys (`setting_theme_mode`, `setting_fantasy_accent`, `setting_haptic_level`, `setting_rules_edition`) migrated to v2 string keys | DS |
| B25 | `lib/services/persistence/app_backup_service.dart: importFullBackupJson` | Schema version 1 and 2 backup envelopes restored | DB1, DB2 |
| B26 | `lib/services/persistence/dm_backup_service.dart: validateAndImportProfile` | Schema version 1 campaign profile JSON snapshot files restored | DM_E1, DM_E2, DM_E3, DM_E4, DM_E5, DM_E6, DM_E7, DM_E8, DM_E9 |
| B27 | `lib/infrastructure/dtos/campaign_profile_dto.dart: PartyPurse.fromMap` | Legacy scalar coin values without counters migrated to initial PN-counter with `'init'` slot | DPP |
| B28 | `lib/infrastructure/dtos/campaign_profile_dto.dart: RoomNodeState.fromMap` | Legacy list-form `entityLinks` migrated into `EntityLinkCrdtSet` with genesis timestamps | E1, E2 |
| B29 | `lib/services/persistence/homebrew_persistence_service.dart: HomebrewPersistenceService` | Legacy homebrew store formats | not covered: later slice |
| B30 | `lib/infrastructure/migration/party_ledger_legacy_import.dart: PartyLedgerLegacyImport` | Old Firestore room documents (not local storage) | not covered: later slice |
