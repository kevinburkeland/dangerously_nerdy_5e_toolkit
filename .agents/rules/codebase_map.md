# Codebase Fast Lookup Map

Use this map to navigate directly to relevant components without recursive searches:

| Feature / Domain Concept | Primary File Locations | Key Classes & Models |
|---|---|---|
| **Domain Models & Primitives** | `lib/domain/models/`, `lib/domain/models/value_objects/` *(Consumes `vtt_engine_core`)* | `AnimatedObject`, `CampaignProfile`, `HitPoints`, `ExhaustionState`, `WeaponMastery` |
| **Domain Ports (Interfaces)** | `lib/domain/ports/`, `lib/domain/storage/ports/` | `ICampaignRepository`, `ICharacterRepository`, `IP2pTransportPort`, `INetworkTimePort`, `IStorageDurabilityPort` |
| **Distributed State Primitives** | `lib/domain/crdt/`, `lib/infrastructure/dtos/crdt/` *(Consumes `vtt_engine_core`)* | `HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`, `PnCounter` |
| **State Reconciliation** | `lib/application/services/` | `RoomStateReconciliationService`, `PartyRoomService`, `RoomSyncOrchestrator` |
| **Encounter & Combat Service**| `lib/application/services/`, `lib/services/rules/` | `CombatEncounterService`, `ArenaCombatEngine`, `CharacterActionsResolver` |
| **Infrastructure Repositories** | `lib/infrastructure/repositories/` | `LocalCampaignRepository`, `LocalCharacterRepository` |
| **DTOs & Serializers** | `lib/infrastructure/dtos/` | `CharacterDto`, `CampaignProfileDto`, `AnimatedObjectDto`, `HomebrewEntityDto` |
| **Dependency Injection** | `lib/infrastructure/di/` | `injection_container.dart` (`sl` Service Locator) |
| **Character Sheet & Builder** | `lib/screens/character_sheet_view.dart`, `lib/screens/character_builder_screen.dart`, `lib/widgets/character_sheet/` | `CharacterSheetController`, `CharacterValidationEngine`, `CharacterReparseEngine` |
| **Rules & Mechanics Modules** | `lib/domain/rules/`, `lib/infrastructure/modules/dnd5e/`, `lib/services/rules/` | `Dnd5e2014Module`, `Dnd5e2024Module`, `Dnd5eCombatResolver`, `AcEngineAndInventory` |
| **Dice Roller & 3D Physics** | `lib/screens/dice_roller_screen.dart`, `lib/widgets/dice_roller/` | `DiceRollerScreen`, `Polyhedral3dVisualizer`, `DiceRoomService` |
| **Multiplayer Rooms & Vault** | `lib/screens/party_room_screen.dart`, `lib/services/party/`, `lib/widgets/party/` | `PartyRoomScreen`, `PartyRoomService`, `PartyPurse` |
| **Arena & Monte Carlo DPR** | `lib/screens/arena_simulator_screen.dart`, `lib/screens/dpr_calculator_screen.dart` | `ArenaSimulatorScreen`, `DprSimulator`, `PrecomputedAttack`, `CombatEffectRider` |
| **Compendiums & Codices** | `lib/presentation/codex/`, `lib/screens/*_codex_screen.dart`, `lib/screens/*_compendium_screen.dart` | `CodexPageShell`, compendium screens, `FormattedMarkdownText` |
| **Homebrew ACL & Ingestion** | `lib/infrastructure/adapters/ingestion/`, `lib/infrastructure/mappers/` | `GithubIngestorAdapter`, `CompendiumPipeParser`, `StatBlockAclParser`, `HomebrewImportOrchestrator` |
| **Minion Tools & Summons** | `lib/screens/minion_tool_screen.dart`, `lib/widgets/minions/` | `MinionToolScreen`, `BatchAttackDialog`, `AnimatedObjectInstance` |
| **UI Theme & A11y** | `lib/theme/app_theme.dart`, `lib/presentation/core/` | `AppTheme`, `AccessibleActionTile`, `FormattedMarkdownText` |
| **Persistence & Storage** | `lib/services/persistence/`, `lib/infrastructure/adapters/storage/` | `AppDatabaseService`, `HomebrewPersistenceService`, `StorageDurabilityCoordinator` |
| **Compliance Invariant Tests** | `test/infrastructure/compliance/`, `test/domain/` | `srd_legal_compliance_test.dart`, `domain_purity_test.dart`, `dto_purity_test.dart` |
