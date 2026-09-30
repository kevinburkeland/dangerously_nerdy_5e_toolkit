# Codebase Fast Lookup Map

Use this map to navigate directly to relevant components across the toolkit and upstream engine boundaries:

| Feature / Domain Concept | Primary File Locations | Key Classes & Models |
|---|---|---|
| **Agnostic Engine Core** | `vtt_engine_core` (`../vtt-engine-core`) | `HybridLogicalClock`, `CrdtOrSet`, `PnCounter`, `HitPoints`, `CoreTypes`, `CampaignProfile`, `PartyPurse`, `IP2pTransportPort`, `IRulesetModule`, `ICombatResolver` |
| **D&D 5e Domain Models** | `lib/models/` (`characters/`, `spells/`, `monster_codex/`, `magic_items/`, `tables/`, `arena/`, `dpr/`) | `Character`, `CharacterClass`, `Spell`, `Monster`, `MagicItem`, `WeaponMastery`, `AnimatedObject`, `ExhaustionState` |
| **Ingestion Engine Domain** | `lib/domain/ingestion/` | `DocumentStructureParser`, `CandidateDetector`, `FieldExtractor`, `SourceBlockParser`, `IngestionWorkbenchService` |
| **Pluggable 5e Ruleset Module** | `lib/infrastructure/modules/dnd5e/` *(Implements engine SPI)* | `Dnd5e2014Module`, `Dnd5e2024Module`, `Dnd5eCombatResolver`, `Dnd5eCurrencySystem` |
| **5e Rules & Mechanics Engines** | `lib/services/rules/` | `Dnd5eRulesEngine`, `AcEngineAndInventory`, `CharacterActionsResolver`, `CharacterProgressionEngine`, `CharacterReparseEngine`, `CharacterStatCalculator`, `CharacterValidationEngine` |
| **State Reconciliation** | `lib/application/services/` | `RoomStateReconciliationService`, `PartyRoomService`, `RoomSyncOrchestrator`, `ClockSyncService` |
| **Encounter & Combat Service** | `lib/application/services/`, `lib/services/rules/` | `CombatEncounterService`, `ArenaCombatEngine`, `CharacterActionsResolver` |
| **Infrastructure Repositories** | `lib/infrastructure/repositories/` *(Implements engine ports)* | `LocalCampaignRepository`, `LocalCharacterRepository` |
| **DTOs & Wire Serializers** | `lib/infrastructure/dtos/`, `lib/infrastructure/dtos/crdt/` | `CharacterDto`, `CampaignProfileDto`, `AnimatedObjectDto`, `HomebrewEntityDto`, `HybridLogicalClockDto` |
| **Dependency Injection** | `lib/infrastructure/di/` | `injection_container.dart` (`sl` Service Locator) |
| **Character Sheet & Builder** | `lib/screens/character_sheet_view.dart`, `lib/screens/character_builder_screen.dart`, `lib/widgets/character_sheet/` | `CharacterSheetController`, `CharacterValidationEngine`, `CharacterReparseEngine` |
| **Dice Roller & 3D Physics** | `lib/screens/dice_roller_screen.dart`, `lib/widgets/dice_roller/`, `lib/services/dice_room_service.dart` | `DiceRollerScreen`, `Polyhedral3dVisualizer`, `DiceRoomService` |
| **Multiplayer Rooms & Vault** | `lib/screens/party_room_screen.dart`, `lib/services/party/`, `lib/widgets/party/` | `PartyRoomScreen`, `PartyRoomService`, `PartyPurse` |
| **Arena & Monte Carlo DPR** | `lib/screens/arena_simulator_screen.dart`, `lib/screens/dpr_calculator_screen.dart`, `lib/services/rules/` | `ArenaSimulatorScreen`, `DprCalculatorEngine`, `DprSimulator` *(consumes engine simulation)* |
| **Compendiums & Codices** | `lib/presentation/codex/`, `lib/screens/*_codex_screen.dart`, `lib/screens/*_compendium_screen.dart` | `CodexPageShell`, compendium screens, `FormattedMarkdownText` |
| **Homebrew Ingestion & ACL** | `lib/infrastructure/adapters/remote/`, `lib/infrastructure/mappers/`, `lib/services/acl/` | `GithubIngestorAdapter`, `CompendiumPipeParser`, `StatBlockAclParser`, `HomebrewImportOrchestrator` |
| **Minion Tools & Summons** | `lib/screens/minion_tool_screen.dart`, `lib/widgets/minions/` | `MinionToolScreen`, `BatchAttackDialog`, `AnimatedObjectInstance` |
| **UI Theme & A11y** | `lib/theme/app_theme.dart`, `lib/presentation/core/` | `AppTheme`, `AccessibleActionTile`, `FormattedMarkdownText` |
| **Persistence & Storage** | `lib/services/persistence/`, `lib/infrastructure/storage/`, `lib/application/storage/` | `AppDatabaseService`, `HomebrewPersistenceService`, `StorageDurabilityCoordinator`, `CampaignSnapshotSerializerAdapter` |
| **Compliance Invariant Tests** | `test/infrastructure/compliance/`, `test/domain/`, `test/infrastructure/dtos/` | `srd_legal_compliance_test.dart`, `domain_purity_test.dart`, `dto_purity_test.dart` |
