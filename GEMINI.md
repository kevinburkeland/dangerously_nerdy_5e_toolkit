# Gemini / Antigravity AI Directives

This project enforces strict **Domain-Driven Design (DDD)**, **Hexagonal Architecture (Ports and Adapters)**, **CvRDT Distributed State Synchronization**, and **SRD 5.1 / 5.2.1 Dual-Ruleset Compliance**.

For full codebase documentation, directory maps, and detailed engineering directives, see:
- [AGENTS.md](file:///AGENTS.md): Master AI Directives & Codebase Fast Navigation Index
- [.agents/rules/architecture.md](file:///.agents/rules/architecture.md): Hexagonal Architecture & Domain Purity
- [.agents/rules/crdt_and_sync.md](file:///.agents/rules/crdt_and_sync.md): CvRDT & Distributed State Directives
- [.agents/rules/dnd_rulesets.md](file:///.agents/rules/dnd_rulesets.md): 2014 RAW vs 2024 Revised Rules Matrix
- [.agents/rules/a11y_and_ui.md](file:///.agents/rules/a11y_and_ui.md): Accessibility (48x48dp, Semantics, 2.0x Dynamic Type)
- [.agents/rules/data_and_performance.md](file:///.agents/rules/data_and_performance.md): DTOs, Ingestion, and Performance
- [.agents/rules/testing_and_workflows.md](file:///.agents/rules/testing_and_workflows.md): Targeted Test & Build Commands

---

## 🛡️ Master Directives & Core Invariants Summary


0. **Zero Proprietary Third-Party Tool (5etools) Coupling & Clean Room ACL:**
   - The codebase MUST NOT contain hardcoded third-party site keys (e.g. 5etools bundle lists like `monsterfluff`, `racefluffmeta`, `subclassfeature`), third-party naming conventions, or splatbook identifiers in core business logic.
   - Remote repository ingestion (`GithubIngestorAdapter`) uses an agnostic recursive structural Anti-Corruption Layer (ACL) identifying entities via generic tabletop indicators (`name`, `entries`, `hitDie`, `stats`, `type`, `level`, `actions`).
   - External pipe-delimited syntax (`Feature|Class|Source|Level`, `Spell|Source#c`) is strictly isolated into dedicated infrastructure ACL parsers (`CompendiumPipeParser`).
   - Character mechanics, substitutions, and combat capabilities are strictly driven by domain `FeatureGrant`s (`GrantType.attackAbilitySubstitution`, `GrantType.capabilityFlag`, `GrantType.acFormula`) or normalized capability flags (`initiativeBonusMode`, `mediumArmorDexCapBonus`, `passivePerceptionBonus`). Never pattern match on non-SRD string names.

1. **Hexagonal Architecture & Domain/DTO Purity:**
   - **Zero Flutter in Domain & DTOs:** Files in `lib/domain/` and `lib/infrastructure/dtos/` MUST NOT import `package:flutter/...`. Use pure Dart annotations (`package:meta/meta.dart`). Verified by `domain_purity_test.dart` and `dto_purity_test.dart`.
   - **Ports & Adapters:** Abstract interfaces live in `lib/domain/ports/` and `lib/domain/storage/ports/`; concrete implementations live in `lib/infrastructure/`. Ports must never import application services or infrastructure DTOs.
   - **Deep Immutability:** All domain models and value objects must have `const` constructors and `copyWith()` mutators. Never expose mutable lists or maps directly. All in-place mutating methods (`takeDamage`, `heal`, `applyHeal`, `grantTempHp`) and silent empty setters are eradicated in favor of pure copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`).

2. **CvRDT Primitives, Monotonic Clocks & Tombstone Safety:**
   - **Hybrid Logical Clock (HLC):** Implements `Comparable`. When timestamps (`l`) and counters (`c`) collide, use `nodeId` as the strict deterministic lexicographical tie-breaker.
   - **Cryptographic Node Identity Enforcement:** Orchestrators stamping CRDT registers (`HomebrewImportOrchestrator`, `PartyRoomService`) generate pure cryptographically secure UUID v4 identifiers (`const Uuid().v4()`) resolved once and shared uniformly with HLC.
   - **Observed-Remove Set (`CrdtOrSet`):** Deletions record tombstones. Internal items and tombstones maps are strictly sealed via `Map.unmodifiable()`. Bulk insertions use `addBatch` to eliminate $O(N^2)$ re-allocations. `remove()` unconditionally records a tombstone (preventing out-of-order add revivals). `prune(threshold)` purges tombstones older than the sync horizon. Obsolete tombstones older than active items are suppressed on merge to preserve commutativity ($A \sqcup B = B \sqcup A$).
   - **LWW Register (`CrdtLwwRegister`):** Modifications return a new immutable instance.
   - **Authoritative Milestone Pruning Decoupling:** `RoomStateReconciliationService` requires constructor injection of `networkTimeProvider` (sourced from `ClockSyncService.currentNetworkTimeMs`), pruning anchored to authoritative server/ledger timestamps. When extreme clock skew inverts the pruning horizon ($threshold \ge networkTime$), pruning is deferred gracefully (`safePrune`).
   - **Field-Level Sub-Resource Reconciliation:** Base room state hydrates from milestone snapshots, with incremental deltas merged via `RoomStateReconciliationService.reconcileProfile`. Sub-resources (notes via `CrdtLwwRegister`, currency via `PnCounter`, rosters, minions keyed by `m.id`, encounters keyed by `participantId`, change logs) merge independently rather than whole-document LWW overwrite.

3. **P2P Transport Waterfall, Concurrency Mutex & Re-entrant Deadlock Immunity:**
   - **Unified Polymorphic Transport Port:** `IP2pTransportPort` is the single domain contract for networking. Downcasting `transportPort as CascadingTransportRouter` is strictly forbidden.
   - **4-Tier Waterfall:** `CascadingTransportRouter` cascades through Tier 1 (Local Wi-Fi), Tier 2 (WebRTC Mesh), Tier 3 (Firebase Cloud Relay), Tier 4 (Offline). Enforces sequential failure thresholds (`sequentialFailureThreshold = 3`) and holdoff cooldowns (`stepUpHoldoff = 5s`) to dampen flapping. Periodically probes higher tiers (`probeHigherTiers()`) via `IP2pTransportPort.probeViability()`.
   - **Narrow Mutex Critical Section:** In `RoomSyncOrchestrator`, `_syncMutex.protect()` is strictly restricted to in-memory CRDT joins and profile reconciliation. Disk persistence (`saveProfileImmediate`) executes asynchronously *outside* the mutex lock to prevent re-entrant deadlocks. Entities implement value equality (`operator ==`, `hashCode`) to prevent echo broadcast triggers.
   - **Sliding Lookback Window & LinkedHashMap O(1) LRU Deduplication:** Incoming packets enforce a 30-second sliding lookback window (`inboundTimestamp >= localTime - 30000`) and an in-memory 500-entry `LinkedHashMap<String, bool>` SHA-256 LRU cache. Malformed or unrecognized payloads (`UnknownSyncMessage`) are rejected *before* LRU caching to prevent cache poisoning.
   - **Asynchronous Stream Emission & Microtask Payload Dispatch:** Reactive broadcast `StreamController`s across persistence repositories and transport services MUST specify `sync: false`. Inbound transport payloads are dispatched via `scheduleMicrotask()` to prevent synchronous re-entrant `_syncMutex` deadlocks during failovers.
   - **WebRTC Async Microtask Dispatching:** In `WebRtcMeshAdapter`, `_incomingPayloadsController` is `broadcast(sync: false)` and DataChannel message arrivals are dispatched via `scheduleMicrotask()` to eliminate synchronous event-loop contention.

4. **WebRTC Signaling, Polite Glare Rollback & Readiness Gate:**
   - **Peer-Scoped Ephemeral Signaling Isolation:** `FirebaseSignalingAdapter` tracks signaling documents by peer ID (`_peerTrackedDocPaths`). Peer connects invoke `cleanUpPeerSignaling(peerId)` rather than wiping all room signaling documents (`cleanUpSignalingSession()`). Document deletions enforce a 5-second timeout.
   - **W3C Polite Peer Glare Rollback:** When signaling collisions occur (receiving offer while in `have-local-offer`), the polite peer rolls back its local offer (`RTCSessionDescription('', 'rollback')`) and accepts the incoming offer. If rollback throws, it prunes the peer and recreates a clean `RTCPeerConnection`.
   - **DataChannel Readiness Gate:** ICE connection state transitions to `connected` defer ephemeral signaling document deletion until the peer DataChannel is fully established (`RTCDataChannelOpen`) or ICE reaches `completed`.

5. **Party Currency Convergence, Scalar Priority & Vault Zero-Wipe Protection:**
   - **CvRDT PN-Counter:** Currency denominations (`cp, sp, ep, gp, pp`) in `PartyPurse` converge using `PnCounter` (positive/negative registers per node ID). Individual mutations route via `modifyCoin(denomination, delta, nodeId: id)`.
   - **Differential Decrement Enforcement:** All coin reductions calculate delta against `effectiveCounter` and record negative decrements (`counter.decrement(nodeId, delta)`); never re-seed with positive scalars via `PnCounter.withInitialValue(val)`.
   - **Scalar Priority & Lattice Join Idempotence:** `PartyPurse.fromMap` prioritizes scalar coins over stale counters if scalars differ, parsing across dynamic map types and applying deterministic deltas on `nodeId: 'cloud'` for lattice join idempotence ($A \sqcup A = A$).
   - **Vault Zero-Wipe Immunity:** Non-currency campaign operations (`ensureRoomExists`, `joinCampaign`, `linkCharacterToCampaign`, `updateMemberPurse`, `updateCharacterRoster`) and transport signaling MUST NEVER overwrite or transmit `partyPurse` in Firestore.
   - **Vault Dispersal vs External Loot:** Dispersing coins from vault reserve (`isVaultDispersal: true`) withdraws shares from `partyPurse` via `withdrawCoins(...)`, conserving party wealth. External loot hoards (`isVaultDispersal: false`) deposit reserve shares as new treasure.
   - **crdt_purse_delta Protocol:** Currency mutations emit focused `crdt_purse_delta` packets and reconcile directly without full document dumps.

6. **Stateless Room Stub Rehydration & 30-Day Lease Auto-Renewal:**
   - In stateless P2P mesh architectures, `PartyRoomService.joinCampaign()` inspects active subcollection presence (`nodes` and `relay_messages`) before concluding a room is missing, preventing false `"Campaign not found"` errors.
   - Any connect (host init, player join, or screen mount) touches `/rooms/{cleanCode}` with `isStateless: true` and resets the 30-day lease (`expiresAt: now + 30 days`) via `SetOptions(merge: true)`. Confirmed non-existent rooms reject cleanly without generating phantom stubs.
   - `firestore.rules` gracefully permits unverified App Check tokens (`isAppCheckVerified() { return true; }`), tolerates $\pm 24$-hour timestamp drift, validates flexible non-negative coin bounds across `int` and `number`, permits 128-char node IDs and 1MB relays, and allows full room deletion.

7. **Campaign Lifecycle, Outbox Resilience & Shared Character Storage:**
   - **Existing Campaign Cloud Sync:** `PartyRoomService.syncAllExistingCampaignsToFirestore()` iterates local memberships on `LandingScreen` mount and rehydrates room stubs on Firestore.
   - **Outbox Auto-Flushing & Poison-Pill Purge:** `PartyRoomService.flushOutbox` aggregates coin operations into single document writes, tracks retries, purges poison pills after 3 consecutive failures, and auto-flushes on debounced schedules and room entry.
   - **Shared Character Storage & Local Priority:** `session.sharedCharacters` stores the full `character.toMap()` payload (including `maxHp`, `currentHp`, `tempHp`, `armorClass`). UI consumers opening character sheets in party rooms check local persistent storage (`CharacterPersistenceService.getCharacter`) first before remote stubs, pushing updated telemetry back on route return.
   - **Campaign Management UI:** Exposes confirmation-guarded Player Leave (purges membership, removes from roster in Firestore, disposes dice streams) and DM Delete (verifies `hostKeyHash`, deletes `/rooms/{roomCode}`, purges local state).

8. **Dual-Ruleset Architecture (2014 RAW vs 2024 Revised):**
   - Canonical `RulesetEdition` (`lib/domain/rules/ruleset_edition.dart`) serves as the pure domain enum with bi-directional adapters to legacy DTO enums (`DmRulesEdition`, `RulesetVersion`).
   - Key differences: Drinking Potions (Action vs Bonus Action), Exhaustion (6 discrete tiers vs 10 linear steps), Counterspell (DC check vs CON save), Cure Wounds / Healing Word (1d8/1d4 vs 2d8/2d4), Divine Smite (no action vs bonus action concentration), Heavy Weapon / Power Attack & GWF (-5/+10 & reroll 1-2 vs +PB & floor 3), Weapon Masteries (absent in 2014; active in 2024).
   - Subclass milestones: 2014 varies by class (Level 1 Cleric/Sorcerer/Warlock, Level 2 Druid/Wizard, Level 3 others via `characterClass.getSubclassLevel(ruleset)`); 2024 standardizes all classes to Level 3.
   - Pure Warlock Pact Magic: Uniform slot level (`pactMagicSlotLevel`), auto-upcasting lower-level spells, dynamic effect scaling (*Armor of Agathys*), distinct short-rest pool tracking.

9. **5e RAW Health & Instant Death Decoupling:**
   - In `HitPoints`, 0 HP unconsciousness (`isDowned => currentHp <= 0`) is decoupled from permanent death (`isDead`). Standard healing (`heal(amount)`) revives downed actors at 0 HP per 5e RAW, while permanent death from massive damage requires explicit revival (`allowRevive: true` or `revive()`).
   - Instant death: Reducing Strength or effectiveMaxHp to 0 sets `currentHp = 0`, logs instant death, and marks the actor defeated (`isAlive` returns false if Strength <= 0).

10. **Ingestion Concurrency Bounding, $O(N)$ Batch Indexing, & Memory Stability:**
    - **Bounded Ingestion:** In `GithubIngestorAdapter`, network downloads are bounded to sequential processing (`concurrentDownloads: 1`) with cooperative event-loop yields (`await Future<void>.delayed(Duration.zero)`) between files and stream chunks (`streamChunkSize: 25`).
    - **Copy-On-Write AST Transformations:** `GenericTagScrubber.scrubMap` and `_resolveRefs` apply copy-on-write semantics, returning original references unmodified if no child tokens changed to eliminate heap allocations and GC spikes.
    - **Ledger Suppression & Error Window:** `HomebrewImportOrchestrator` provides optional ledger suppression (`retainLedger: false`) and sliding-window error accumulation (max 100 entries) to prevent heap exhaustion during large imports.
    - **$O(N)$ Fast-Path Persistence:** `HomebrewPersistenceService._saveEntitiesBatchFast` uses slug-to-index maps to merge batches into storage in $O(N)$ time without re-decoding/re-serializing historical databases.
    - **SharedPreferences OOM Crash Shield:** `HomebrewPersistenceService._saveStringList` and `_saveRawPayloadsBatch` suppress mirroring large collections (`list.length > 20`) to `SharedPreferences` when Hive storage (`AppDatabaseService.boxHomebrew`) is open.

11. **Monster vs Race Disambiguation & Recipe Filtering:**
    - In `GithubIngestorAdapter._inferEntityType` and `HomebrewPersistenceService.saveHomebrewEntitiesBatch`, non-generic category hints (`monster`, `monsters`, `bestiary`, `creature`, `npc`) immediately route to monster. Compound creature types extract and evaluate the primary type.
    - Entities possessing monster attributes (`actions`, `action`, `ac`, `hp`, `cr`, `challengeRating`, `hitDice`, `reactions`, `reaction`, `legendary`, `trait`, `isNpc`, `isNamedCreature`, `save`, `passive`) or template clones (`_copy`) strictly reject classification as playable races. `speed` and `size` alone MUST NEVER classify an entity as a playable race.
    - Non-tabletop crochet and recipe assets (`recipes.json`, `recipe`, `recipes`, `recipefluff`) are excluded across remote manifest discovery and bundle unpacking.
    - Internal ACL parser (`StatBlockAclParser`) is strictly favored on any discrepancy with incoming raw declarations.

12. **Subclass Feature Ingestion, Multi-Permutation Matching & AST Expansion:**
    - **Multi-Permutation Matching:** `SrdClassesLibrary.findSubclass` normalizes class-slug prefixes (`fighter-rift-warden` <-> `rift-warden`), spaces, hyphens, and underscores across all custom and core subclasses.
    - **Recursive AST Expansion:** Milestone features referencing child abilities through pointer nodes (`refSubclassFeature`, `refClassFeature`) or choice structures in `options`/`list` blocks are recursively expanded via `CompendiumClassParser._expandFeatureAst`, elevating feature pointers to standalone milestone headers and inlining choices with rich rules text.
    - **Header & Bold Priority (Zero Stub Early Returns):** `AbilitiesAndTraitsTab` and `FeaturesTraitsSection` never early-return on pipe matches; headers and bold blocks take precedence over placeholder stubs. Combat action requirements (`bonus action`, `reaction`, `action`) and resource charges are dynamically detected and populated into `CharacterCombatAction`.

13. **Subrace Attribute Replacement, Lineage Spells & Background Compilation:**
    - In 2014 mode, subrace mechanical attributes (ability score increases, walking speed, darkvision) REPLACE base species attributes rather than adding to them. Innate cantrips and spells from subraces/species (`SkillTraitResolver.getInnateSpeciesSpells`) auto-register into `character.cantrips` and `character.spellsKnown`. Flexible choices are bounded by `flexibleAbilityPool`.
    - 2014 backgrounds do not grant ASIs; they grant canonical skills, starting equipment packages, and narrative background features (`customProperties['backgroundFeature']`) without polluting feats.
    - Class starting skills ingest from `startingProficiencies.skills` into `allowedSkills` and `skillChoiceCount`. In compendiums, `raw['proficiency']` contains saving throws, NOT starting skills.
    - When stats precede species (`attributesFirst`), selecting a flexible lineage renders inline choices with live attribute totals and gates progression.

14. **Character Sheet Self-Healing Reparse Engine:**
    - `CharacterReparseEngine.reparse(Character)` provides deterministic, non-destructive state healing for existing characters in local persistence. Re-evaluates tool proficiencies, armor/weapon proficiencies, lineage spells, cleanses contaminated skill choice pools, resolves 2014 narrative background features, recomputes max HP and clamps current HP.
    - Automatically triggered on homebrew compendium reparse via `HomebrewPersistenceService.reparseAllHomebrew()`.

15. **Combat Action Rider AST & Zero Runtime Regex in Hot Loops:**
    - Attack action descriptions are parsed at the ACL ingestion boundary (`StatBlockAclParser.extractRiders`) into strongly typed `CombatEffectRider` ASTs (`ConditionRider`, `AttributeDrainRider`, `MaxHpReductionRider`, `ForcedMovementRider`, `HealingSupressionRider`, `PeriodicDamageRider`).
    - Combat simulations (`ArenaCombatant.applyAttackHit`) execute composite riders with zero runtime regex, clamping `effectiveMaxHp` and dynamically scaling down attack and saving throw modifiers.
    - Simulation turn runner forwards `hitResult.riderLogs` directly into `ArenaAttackEvent.appliedRiderLogs` and appends formatted pass/fail condition logs to `summaryText`.
    - `DprSimulator.runInIsolate` accepts an optional `seed` parameter and propagates `Random(seed)` for bit-identical reproducible Monte Carlo simulations.

16. **Storage Durability & Eviction-Immunity Architecture:**
    - Pure domain models in `lib/domain/storage/models/` (`EngineProfile`, `StorageTelemetryReport`, `StorageSnapshotBundle`) and port contracts (`IStorageDurabilityPort`, `IPhysicalSnapshotPort`) maintain zero Flutter dependencies.
    - `StorageDurabilityCoordinator.executeSilentPreflight()` runs prior to IndexedDB/Hive connection pool initialization to prevent ephemeral storage locking. Cold-storage backups are sealed with constant-time SHA-256 (`SHA-256(vaultId + payloadBytes)`) and hydrated with 30s sliding lookback verification.
    - CPU-intensive cold storage serialization (`jsonEncode`/`jsonDecode`) is offloaded to background isolates via `Isolate.run()`.
    - `_DangerouslyNerdy5eToolkitAppState` wires `AppLifecycleListener` for awaited asynchronous storage flushes (`onPause`, `onHide`, `onDetach`, `onExitRequested`) with error isolation.

17. **System-Wide Backup & 11-Category Invariant:**
    - All backup and export services (`DmBackupService`, `AppBackupService`, `HomebrewPersistenceService`) capture and restore all 11 categories: `spells`, `monsters`, `items`, `classes`, `subclasses`, `races`, `subraces`, `feats`, `backgrounds`, `otherEntries`, `fluff`.
    - Unifies persistent storage collections with in-memory custom registries, sweeping attached sub-entities (`c.subclasses`, `r.subraces`) alongside standalone records. Per-item `try-catch` deserialization ensures single malformed records do not discard entire collections.

18. **Tabular UI Rendering & Markdown Formatting:**
    - Compendium tables are classified into Rollable Tables (`tables`) vs Data & Reference Tables (`dataTables`) via `isRollingTable`.
    - Markdown tables (`| ... |`) inside rule cards (`DmRuleCard`) are grouped and rendered as native Flutter `Table` widgets via `FormattedMarkdownText`. Card badges are placed in the subtitle `Wrap` inside an `Expanded` column to prevent horizontal `RenderFlex` overflow under narrow viewports or 2.0x dynamic type scaling.
    - Universal compendium formatting: All compendium cards and detail dialogs (`ItemCard`, `ItemDetailDialog`, `SpellCard`, `SpellComparisonDialog`, `CreatureStatBlockDialog`, `FeatCard`, `HomebrewStudioScreen`, `CharacterBuilderScreen`, `AddFeatDialog`) MUST use `FormattedMarkdownText`.

19. **Accessibility (a11y) & Mobile Responsive Layout Standards:**
    - Touch targets minimum **48x48dp** (`minSize: const Size(48, 48)`).
    - Screen readers: Wrap icons and custom actions in `Semantics` with expanded abbreviation labels (STR -> Strength, AC -> Armor Class, HP -> Hit Points, DC -> Difficulty Class, GP -> Gold Pieces, RAW -> Rules As Written).
    - Dynamic type scaling: UI must render cleanly up to `TextScaler.linear(2.0)` without `RenderFlex` overflow errors.
    - Reduced motion: `MediaQuery.disableAnimationsOf(context)` checks before triggering particle effects or 3D animations.
    - Party room banner employs `LayoutBuilder` so session identity spans full width on compact screens (`maxWidth < 620`), with action buttons wrapping cleanly in a dedicated `Wrap`.

20. **Legal & SRD Compliance Invariant Suite:**
    - Strictly SRD 5.1 & 5.2.1 open content (CC-BY-4.0). Tests and code must use generic or invented homebrew names.
    - `srd_legal_compliance_test.dart` asserts that all bundled static compendiums (`SrdClassesLibrary.allOptions`, `SrdBackgroundsLibrary.allBackgrounds`, `SrdSpeciesLibrary.allSpecies`, `MonsterCodexLibrary.allMonsters`, `MagicItemLibrary.allItems`) contain zero proprietary Product Identity tokens. Test fixtures must strictly use generic variant lineages (`Human (Lineage of the Forge)`, `CUSTOM_LINEAGE`).

21. **Continuous Documentation & Living Rules Protocol (Definition of Done):**
    - Before completing any engineering task, the agent MUST verify test counts (updating badges across documentation), update feature matrices in [README.md](file:///README.md), codify newly established conventions into `.agents/rules/`, and keep the Fast Codebase Navigation Index in [AGENTS.md](file:///AGENTS.md) up to date.
