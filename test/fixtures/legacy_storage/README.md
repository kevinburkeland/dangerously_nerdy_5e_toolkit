# Legacy Campaign Storage Safety Net

This directory contains golden fixtures, stored facts, and generator sources for older campaign storage schemas.
These fixtures form the safety net for Cleanup slice 3 and all future cleanup slices: CI verifies via `test/infrastructure/legacy/legacy_load_law_test.dart` that data saved by earlier versions of the app still loads cleanly without data loss.

## Inventory of Legacy Shape Readers

The table below catalogs every location in the app and engine core that accepts an older stored shape.

| Id | File and Symbol | Old Shape Accepted | Fixture or Reason |
|---|---|---|---|
| B1 | `lib/main.dart: openStorage, completeNormalStartup` | Unmigrated startup sequence: opens storage, extracts legacy characters, adopts unlinked registry memberships, executes schema migrations | All storage fixtures (E1–E9, DP, DE, DM, DS, DR) |
| B2 | `lib/infrastructure/repositories/local_campaign_repository.dart: LocalCampaignRepository._loadSavedRecords` | SharedPreferences fallback for campaign profile index list (`dn5e_campaign_profile_index`) | DP |
| B3 | `lib/infrastructure/repositories/local_campaign_repository.dart: LocalCampaignRepository._loadSavedRecords` | SharedPreferences fallback for individual campaign profile JSON records (`dn5e_campaign_profile_<id>`) copied to Hive on read | DP |
| B4 | `lib/infrastructure/repositories/local_campaign_repository.dart: LocalCampaignRepository._loadSavedRecords` | SharedPreferences fallback for active campaign profile ID (`dn5e_campaign_active_id`) | DP |
| B5 | `lib/infrastructure/repositories/local_campaign_repository.dart: LocalCampaignRepository._loadSavedRecords` | Corrupted JSON or unsupported `recordVersion` records preserved in `_rejectedProfileIds` without halting valid profile loading | DR |
| B6 | `lib/infrastructure/repositories/local_character_repository.dart: LocalCharacterRepository.loadCharacters` | SharedPreferences fallback for character roster (`dn5e_saved_characters_roster`) | DP |
| B7 | `lib/infrastructure/repositories/local_character_repository.dart: LocalCharacterRepository._loadRawPersistedRoster` | Character roster stored as raw JSON string instead of Hive List in `boxCharacters` | E1 |
| B8 | `lib/infrastructure/repositories/campaign_storage_migration.dart: CampaignStorageMigration.migrateLegacyCharacters` | Embedded character map objects in campaign `partyRoster` / `partyCharacterIds` extracted into `CharacterPersistenceService` and stripped from campaign record | DE |
| B9 | `lib/infrastructure/repositories/campaign_storage_migration.dart: CampaignStorageMigration.adoptRegistryMemberships` | Unmapped `CampaignRegistryService` memberships adopted into repository as synthesized `campaign_<roomCode>` profiles | All storage fixtures (LEGC03 adoption) |
| B10 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing top-level `recordVersion` defaults to legacy 0 | E1, E2, E3, E4, E5 |
| B11 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `createdAt` defaults to deterministic Unix epoch UTC | E1 |
| B12 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `lastPlayedAt` defaults to `createdAt` | E1 |
| B13 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `roomState` synthesizes default `RoomNodeState` with deterministic `CR-` room code | No era omitted roomState; covered by unit tests |
| B14 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `partyCharacterIds` / `partyRoster` list of string IDs fallback when `partyRoster_crdt` absent | E1, E2 |
| B15 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `partyCharacterIds` / `partyRoster` list of character map objects deserialized to character slugs | DE |
| B16 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy root `activeMinions` list migrated into `roomState.activeMinions` | DM |
| B17 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `pinnedRules` map fallback for `pinnedRules_crdt` | E3 |
| B18 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Legacy `pinnedRuleIds` list fallback when neither `pinnedRules_crdt` nor `pinnedRules` present | E1, E2 |
| B19 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `nameRegister` falls back to top-level `name` and null domain register | E1, E2, E3 |
| B20 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing `memberPurses` map defaults to empty map | E1, E2, E3, E4 |
| B21 | `lib/infrastructure/dtos/campaign_profile_dto.dart: CampaignProfileDto.fromMap` | Missing map and token CRDT fields (`activeMapRegister`, `mapGridRegister`, `mapTokens_crdt`, `mapTokenCells_crdt`, `minionOwners_crdt`) default to empty registers/sets | E1, E2, E3, E4, E5, E6, E7 |
| B22 | `lib/infrastructure/dtos/campaign_edition_codec.dart: parseStoredCampaignEdition` | Legacy edition strings (`generic_tabletop`, `unknown`, empty/whitespace) mapped to `RulesetEdition.v2024` | E1 |
| B23 | `lib/infrastructure/dtos/minion_instance_dto.dart: MinionInstanceDto.fromMap` | Legacy integer `customAccentColor` mapped to `alpha` marker | E1 |
| B24 | `lib/services/persistence/storage_migration_service.dart: StorageMigrationService._migrateV1ToV2` | Legacy v1 integer enum settings keys (`setting_theme_mode`, `setting_fantasy_accent`, `setting_haptic_level`, `setting_rules_edition`) migrated to v2 string keys | DS |
| B25 | `lib/services/persistence/app_backup_service.dart: AppBackupService.importFullBackupJson` | Schema version 1 and 2 backup envelopes restored | LB1 (era `app_backup.json` files) |
| B26 | `lib/services/persistence/dm_backup_service.dart: DmBackupService.validateAndImportProfile` | Schema version 1 campaign profile JSON snapshot files restored | LB1 (era `dm_profile.json` files) |
| B27 | `vtt-engine-core: PartyPurse.fromMap` | Legacy scalar coin values without counters migrated to initial PN-counter with `'init'` slot | E1 |
| B28 | `vtt-engine-core: RoomNodeState.fromMap` | Legacy list-form `entityLinks` migrated into `EntityLinkCrdtSet` with genesis timestamps | E1 |
| B29 | `lib/services/persistence/homebrew_persistence_service.dart: HomebrewPersistenceService` | Legacy homebrew store formats | not covered, later slice |
| B30 | `lib/models/party/party_ledger_legacy_import.dart: PartyLedgerLegacyImport` | Old Firestore room documents (not local storage) | not covered, later slice |
