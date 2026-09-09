# Codebase Fast Lookup Map

Use this cheat sheet to immediately navigate to the relevant files without expensive recursive searches:

| Feature / Domain Concept | Primary File Locations | Key Classes & Models |
|---|---|---|
| **Domain Models (Pure Dart)** | `lib/domain/models/`, `lib/domain/models/value_objects/` | `AnimatedObject`, `CampaignProfile`, `HitPoints`, `ExhaustionState`, `WeaponMastery` |
| **Domain Ports (Interfaces)** | `lib/domain/ports/` | `ICampaignRepository`, `ICharacterRepository`, `IPartySyncPort` |
| **CvRDT Distributed State** | `lib/domain/crdt/`, `lib/infrastructure/dtos/crdt/` | `HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet` |
| **State Reconciliation** | `lib/application/services/` | `RoomStateReconciliationService`, `PartyRoomService` |
| **Encounter & Combat Service**| `lib/application/services/` | `CombatEncounterService` |
| **Infrastructure Repositories** | `lib/infrastructure/repositories/` | `LocalCampaignRepository`, `LocalCharacterRepository` |
| **DTOs & Serializers** | `lib/infrastructure/dtos/` | `CharacterDto`, `CampaignProfileDto`, `AnimatedObjectDto`, `CharacterTelemetryDto` |
| **Dependency Injection** | `lib/infrastructure/di/` | `injection_container.dart` (`sl` Service Locator) |
| **Character Sheet & Builder** | `lib/screens/character_sheet_view.dart`, `lib/screens/character_builder_screen.dart`, `lib/widgets/character_sheet/`, `lib/widgets/character_builder/` | `CharacterSheetController`, `CharacterActionsResolver`, `LevelUpPipeline` |
| **Rules & Mechanics Engines** | `lib/services/rules/` | `CombatRulesEngine`, `Dnd5eRulesEngine`, `SpellcastingRulesEngine`, `AcEngineAndInventory`, `CharacterProgressionEngine`, `TreasureGeneratorEngine` |
| **Dice Roller & 3D Physics** | `lib/screens/dice_roller_screen.dart`, `lib/widgets/dice_roller/` | `DiceRollerScreen`, `Polyhedral3dVisualizer`, `DiceRoll`, `CustomPreset` |
| **Multiplayer Rooms & Vault** | `lib/screens/party_room_screen.dart`, `lib/services/party/`, `lib/widgets/party/` | `PartyRoomScreen`, `LootConflictResolutionDialog`, `CryptoUtils` |
| **Arena & Monte Carlo** | `lib/screens/arena_simulator_screen.dart`, `lib/widgets/arena/`, `lib/services/rules/arena_combat_engine.dart` | `ArenaSimulatorScreen`, `ArenaCombatEngine`, `MonsterCombatProfile` |
| **DPR Calculator & Graph** | `lib/screens/dpr_calculator_screen.dart`, `lib/widgets/dpr/`, `lib/services/rules/dpr_calculator_engine.dart` | `DprCalculatorScreen`, `DprCalculatorEngine`, `DprChartCanvas` |
| **Spellbook & Codices** | `lib/screens/spellbook_screen.dart`, `lib/screens/monster_codex_screen.dart`, `lib/screens/item_compendium_screen.dart`, `lib/screens/class_catalogue_screen.dart`, `lib/screens/feats_compendium_screen.dart`, `lib/screens/species_codex_screen.dart`, `lib/screens/rules_compendium_screen.dart`, `lib/screens/table_index_screen.dart` | Compendium screens, cards, and quick-roll dialogs |
| **Homebrew ACL & Ingestion** | `lib/screens/homebrew_studio_screen.dart`, `lib/services/acl/`, `lib/services/importers/`, `lib/widgets/homebrew/` | `CompendiumJsonIngestionPipeline`, `EntryNodeTransformer`, `LayeredPriorityStore` |
| **Minion Tools & Summons** | `lib/screens/minion_tool_screen.dart`, `lib/widgets/minions/`, `lib/widgets/batch_attack/` | `MinionToolScreen`, `BatchAttackDialog` |
| **UI Theme & Glyphs** | `lib/theme/app_theme.dart`, `lib/widgets/glyphs/`, `lib/widgets/app_logo.dart` | `AppTheme`, `DndGlyphPainter`, `AppLogo` |
| **A11y Core Components** | `lib/presentation/core/` | `AccessibleActionTile` |
| **Persistence & Database** | `lib/services/persistence/` | `AppDatabaseService`, `HomebrewPersistenceService`, `CharacterPersistenceService` |
| **Security & Firestore** | `firestore.rules`, `firestore.indexes.json` | Room security, passkey validation, rate limiting |
| **Web Build Scripts** | `scripts/build_web.sh` | PWA cache busting, service worker version injection |
| **Automated Tests** | `test/` (1,325 tests across unit, widget, accessibility, architecture) | `test/domain/domain_purity_test.dart`, `test/domain/crdt/`, `test/application/`, `test/infrastructure/` |
