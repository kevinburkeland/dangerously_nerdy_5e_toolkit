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
- **Pure Models & Immutability:** All entities and value objects (e.g., `HitPoints`, `AnimatedObject`, `CampaignProfile`) must be immutable pure Dart classes with `const` constructors and `copyWith()` methods.
- **Ports (Interfaces):** Define all repository contracts and synchronization ports in `lib/domain/ports/` (e.g., `ICampaignRepository`, `ICharacterRepository`, `IPartySyncPort`).
- **Distributed Primitives:** Core CvRDT state types (`HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`) reside in `lib/domain/crdt/`.

### 1.2. Application Layer (`lib/application/`) - Orchestration
- Coordinates tasks between the Domain and Infrastructure.
- Examples: `RoomStateReconciliationService` (merges CRDT deltas on top of base snapshots), `CombatEncounterService` (initiates combat encounters and evaluates actions), `PartyRoomService`.
- Application services do not hold long-term persistent state; they process inputs, invoke domain rules, and delegate storage to infrastructure ports.

### 1.3. Infrastructure Layer (`lib/infrastructure/`) - Adapters & IO
- Implements the abstract domain ports defined in `lib/domain/ports/`.
- **Repositories (`lib/infrastructure/repositories/`):** Implement persistence using local storage or remote backends (e.g., `LocalCampaignRepository`, `LocalCharacterRepository`).
- **DTOs (`lib/infrastructure/dtos/`):** Translate outside JSON/network formats into pure domain entities and vice versa. Always preserve unparsed payload and clamp numeric bounds.
- **Dependency Injection (`lib/infrastructure/di/`):** Service Locator (`injection_container.dart` / `sl`) registers singletons and factories for repositories and services.

### 1.4. Presentation Layer (`lib/presentation/`, `lib/screens/`, `lib/widgets/`)
- Purely presentation and user interaction.
- **No business logic or dice math:** Delegates all mechanical evaluations to domain rules or application services.
- Interacts with application state via controllers/providers (`lib/providers/`).
