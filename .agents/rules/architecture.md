# Hexagonal Architecture & Clean DDD Rules

## 1. Architectural Layers & Boundaries

The codebase strictly follows **Domain-Driven Design (DDD)** combined with **Hexagonal Architecture (Ports and Adapters)**:

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│       lib/presentation/, lib/screens/, lib/widgets/    │
└───────────────────────────┬────────────────────────────┘
                            │ uses
┌───────────────────────────▼────────────────────────────┐
│                    Application Layer                   │
│               lib/application/services/                │
└──────────────┬───────────────────────────┬─────────────┘
               │ uses                      │ orchestrates
┌──────────────▼─────────────┐ ┌───────────▼─────────────┐
│        Domain Layer        │ │  Infrastructure Layer   │
│ lib/domain/                │ │  lib/infrastructure/    │
│  - models/ & value_objects │ │   - dtos/ & dtos/crdt/  │
│  - ports/ (Interfaces)     │ │   - repositories/       │
│  - rules/ & simulation/    │ │   - resolvers/          │
│  - crdt/ (CvRDTs & HLC)    │ │   - di/                 │
└────────────────────────────┘ └─────────────────────────┘
```

### 1.1. Domain Layer (`lib/domain/`) - Pure Dart Core
- **ZERO Flutter Imports:** Files in `lib/domain/` MUST NOT import `package:flutter/...`. Use `package:meta/meta.dart` for annotations like `@immutable`.
- **Enforced via Automated Test:** `test/domain/domain_purity_test.dart` scans `lib/domain/` recursively and fails CI if any Flutter package import is detected.
- **No Persistence or Network:** No Hive, SQLite, Firebase, HTTP, or device I/O imports are permitted in `lib/domain/`.
- **Pure Models & Immutability:** All entities and value objects (e.g., `HitPoints`, `AnimatedObject`, `CampaignProfile`) must be immutable pure Dart classes with `const` constructors and `copyWith()` methods. Mutable in-place mutation methods (`takeDamage`, `heal`, `applyHeal`, `grantTempHp`) are strictly forbidden; all modifications must return new immutable instances via pure copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`).
- **Ports (Interfaces):** Define all repository contracts, synchronization ports, and storage durability contracts in `lib/domain/ports/` and `lib/domain/storage/ports/` (e.g., `ICampaignRepository`, `ICharacterRepository`, `IP2pTransportPort`, `INetworkTimePort`, `IRoomSyncPayloadPort`, `ICampaignSnapshotSerializerPort`).
- **Distributed & Storage Primitives:** Core CvRDT state types (`HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`) reside in `lib/domain/crdt/`, while engine profiling, storage telemetry, and cold storage snapshot bundles (`EngineProfile`, `StorageTelemetryReport`, `StorageSnapshotBundle`) reside in `lib/domain/storage/models/`.

### 1.2. Application Layer (`lib/application/`) - Orchestration
- Coordinates tasks between the Domain and Infrastructure.
- Examples: `RoomStateReconciliationService` (merges CRDT deltas on top of base snapshots), `CombatEncounterService` (initiates combat encounters and evaluates actions), `StorageDurabilityCoordinator` (preflight persistence negotiation, contextual permission management, and cold-storage hydration with 30-second sliding lookback window), `RoomSyncOrchestrator` (bidirectional transport synchronization).
- Application services do not hold long-term persistent state; they process inputs, invoke domain rules, and delegate storage to infrastructure ports. Application services MUST NEVER import infrastructure DTOs or adapters directly.

### 1.3. Infrastructure Layer (`lib/infrastructure/`) - Adapters & IO
- Implements the abstract domain ports defined in `lib/domain/ports/` and `lib/domain/storage/ports/`.
- **Repositories (`lib/infrastructure/repositories/`):** Implement persistence using local storage or remote backends (e.g., `LocalCampaignRepository`, `LocalCharacterRepository`).
- **Storage & Ingestion Adapters (`lib/infrastructure/adapters/storage/`):** Implements `ICampaignSnapshotSerializerPort` via `CampaignSnapshotSerializerAdapter` offloaded to `Isolate.run()`. W3C StorageManager and Blob/FileReader adapters with non-web conditional stubs.
- **Mappers (`lib/infrastructure/mappers/`):** Implements `IRoomSyncPayloadPort` via `RoomSyncPayloadMapper` to map incoming network envelopes into strongly typed domain contracts.
- **DTOs (`lib/infrastructure/dtos/`):** Translate outside JSON/network formats into pure domain entities and vice versa. Always preserve unparsed payload and clamp numeric bounds.
- **Dependency Injection (`lib/infrastructure/di/`):** Service Locator (`injection_container.dart` / `sl`) registers singletons and factories for repositories, ports, and services.

### 1.4. Presentation Layer (`lib/presentation/`, `lib/screens/`, `lib/widgets/`)
- Purely presentation and user interaction.
- **No business logic or dice math:** Delegates all mechanical evaluations to domain rules or application services.
- Interacts with application state via controllers/providers (`lib/providers/`).
