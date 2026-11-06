# Cleanup slice 10 progress notes
Status: IN PROGRESS
Start heads: core a393545a225852ca96b53313082b9b86694c72b5, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app b663b438f920d282d4702069df62cd9f2784c46a
Last pushed heads (CI green): core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 2e26f1480738ce07eb87d73f4ea0204cb4ce738e
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs9: core 02e38f27a25042bf34a7359893d84e3f8c006a7e run 42169627679, core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a run 42170055398, app 16d603cf65cfcbbe5cac6274f1b2a9f52dc155e6 run 42169663727
- [x] Step 2 The container knows no services: app 4c7572eeb87958475af8d8d280239caa6ae66e7b run 42172325614
- [x] Step 3 Required bindings and the unbound law: app 2e26f1480738ce07eb87d73f4ea0204cb4ce738e run 42177603193
- [ ] Step 4 Startup migration takes its collaborators
- [ ] Step 5 The layer import table
- [ ] Step 6 Models stop reaching up
- [ ] Step 7 Mutations and report

## Fix checklist
Fix 2.1 done: moved InjectionContainer and sl into lib/infrastructure/di/service_container.dart with zero imports and re-exported it from lib/infrastructure/di/injection_container.dart.
Fix 2.2 done: deleted static bindRepository, bindClock, bindReplicaId, bindBlobStore, bindTransport, bindOrchestrator, and bindSessionStarter from lib/services/persistence/campaign_profile_service.dart, lib/infrastructure/repositories/campaign_storage_migration.dart, lib/services/persistence/dm_backup_service.dart, and lib/services/dice_room_service.dart.
Fix 2.3 done: marked test reset methods @visibleForTesting and renamed DiceRoomService.resetTestingState to resetForTesting in lib/services/dice_room_service.dart, lib/services/persistence/campaign_profile_service.dart, and lib/services/persistence/dm_backup_service.dart.
Fix 2.4 done: renamed clearCacheForTesting to clearCache in lib/services/preset_service.dart and lib/services/minion_session_service.dart and updated callers in lib/services/persistence/app_backup_service.dart, lib/services/app_services.dart, and tests.
Fix 2.5 done: added test/test_doubles/service_test_configurator.dart and updated 31 test setups to configure collaborators explicitly via public configure methods and reset services via ForTesting methods.
Fix 3.1 done: made CampaignProfileService() take zero arguments, made newInstance and configure take all five collaborators as required non-null (using BlobStorePort Function() blobStoreProvider), and passed CampaignRegistryService() in lib/infrastructure/di/injection_container.dart.
Fix 3.2 done: added _requireRepository, _requireClock, _requireReplicaId, _requireRegistryService, and _requireBlobStore to lib/services/persistence/campaign_profile_service.dart and called them at the top of all 17 public members before any try or await.
Fix 3.3 done: made DmBackupService.configure take required StatefulHlcClock clock and added _requireClock() called at the top of validateAndImportProfile and restoreFullSystemSnapshot in lib/services/persistence/dm_backup_service.dart.
Fix 3.4 done: added DiceRoomService.bind, delegated DiceRoomService.configure to _instance.bind with all three collaborators required, removed _instance fallback borrowing from newInstance, and added _requireTransport, _requireOrchestrator, and _requireSessionStarter at the top of restorePersistedSession, joinRoom, leaveRoom, leaveRoomAsync, and broadcastRoll in lib/services/dice_room_service.dart.
Fix 3.5 done: updated PartyRoomService.newInstance default _diceRoomService to DiceRoomService() in lib/services/party/party_room_service.dart and lowered IGNORE_COUNT from 49 to 48 in scripts/check_strict_analysis.sh.
Fix 3.6 done: updated test setups in test/test_doubles/service_test_configurator.dart, test/test_doubles/hive_test_harness.dart, and 25 test files to bind required collaborators via configure, newInstance, or bind.

## Red runs on main
798af00e2be82d4fb94d9bbceebfb44bad6a80bf red run 42172773744
f89caa3f1ce6d299887d8bdbcb20b8cfcaeb7634 red run 42174422239
a3ab7072c8db9f8e85ad924ebb98cc67dee185f4 red run 42175698585

## Next
Execute Step 4: make CampaignStorageMigration.runStartupMigration and adoptRegistryMemberships take required non-null collaborators with no singleton state or fallbacks, add runStartupMigrationFromServices in lib/main.dart, update callers and tests, and add bar rule 7.

## Open issues and deviations
- In Step 2, Rule 5 ("In `lib/`, a call to a member whose name ends in `ForTesting` (pattern: `\b\w*ForTesting\s*\(` that is not its declaration) is allowed only inside the file that declares that member") also flagged two external `*ForTesting()` calls in `lib/services/app_services.dart` (`_instance.debouncedStorage.cancelAllForTesting()` and `CampaignProfileService.resetForTesting()` inside `AppServices.reset()`), which were not listed in the prompt's table of files to touch. Removed those external `*ForTesting()` calls and their two `// ignore: invalid_use_of_visible_for_testing_member` comments from `lib/services/app_services.dart`, and lowered `IGNORE_COUNT` from 51 to 49 in `scripts/check_strict_analysis.sh`.
- Adding `lib/infrastructure/di/service_container.dart` required refreshing `.agents/rules/codebase_map.md` via `dart run tool/generate_codebase_map.dart` so `test/infrastructure/compliance/docs_truth_test.dart` (DT4) stays green.
- The notes-only commit `798af00e2be82d4fb94d9bbceebfb44bad6a80bf` (`Cleanup slice 10: progress notes after step 2`, listed under `## Red runs on main`) failed DT2 in `test/infrastructure/compliance/docs_truth_test.dart` because the `## Next` section in `notes/cleanup_slice_10_progress.md` mentioned the future path `test/infrastructure/di/unbound_collaborator_law_test.dart` before Step 3 created that file; fixed by Step 3 commit `f89caa3f1ce6d299887d8bdbcb20b8cfcaeb7634` creating `test/infrastructure/di/unbound_collaborator_law_test.dart` and removing uncreated file paths from `## Next`.
- The first Step 3 commit `f89caa3f1ce6d299887d8bdbcb20b8cfcaeb7634` (`Cleanup slice 10: step 3 required bindings and the unbound law`, listed under `## Red runs on main`) failed 10 test files in the sharded suite that invoked `CampaignProfileService().logCampaignEvent(...)` (via `CharacterSheetController`), `DiceRoomService()` (`leaveRoom`/`joinRoom`/`restorePersistedSession`/`broadcastRoll`), or `DmBackupService().restoreFullSystemSnapshot(...)` without configuring those services in test `setUp`; fixed in `a3ab7072c8db9f8e85ad924ebb98cc67dee185f4` by configuring the services in `test/test_doubles/hive_test_harness.dart` and in the 7 remaining standalone test `setUp` blocks.
- Commit `a3ab7072c8db9f8e85ad924ebb98cc67dee185f4` (`Cleanup slice 10: step 3 configure test setups for unbound collaborator law`, listed under `## Red runs on main`) timed out in `test/screens/party_room_screen_test.dart` and `test/widgets/treasure_deposit_test.dart` because `configureTestCampaignProfileService()` defaulted `registryService` to `CampaignRegistryService()` whose `_internal()` constructor starts an unawaited `loadMemberships()` inside `FakeAsync` during `setUp`; fixed by defaulting `registryService` in `test/test_doubles/service_test_configurator.dart` to `CampaignRegistryService.newInstance()`.
