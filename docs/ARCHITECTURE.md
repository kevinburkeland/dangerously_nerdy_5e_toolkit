# System Architecture

This repository strictly follows **Domain-Driven Design (DDD)** combined with **Hexagonal Architecture (Ports and Adapters)**.

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

## Directory Structure & Layer Responsibilities

### `lib/domain/` (The Pure Core)
The pure Dart center of the application.
- **`models/`**: Immutable business entities (e.g., `AnimatedObject`, `CampaignProfile`, `WeaponMastery`).
- **`models/value_objects/`**: Immutable value objects (e.g., `HitPoints`).
- **`ports/`**: Abstract interfaces defining domain requirements (e.g., `ICampaignRepository`, `ICharacterRepository`, `IP2pTransportPort`, `INetworkTimePort`).
- **`rules/`**: Pure mechanical logic contracts (e.g., `RulesetContext`).
- **`simulation/`**: Combat simulation contracts and precomputed attack profiles (`DprSimulator`, `PrecomputedAttack`).
- **`crdt/`**: Distributed data structures (`HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`).
- **RULE:** Absolutely no `package:flutter/...` or external persistence libraries allowed here. Enforced by `test/domain/domain_purity_test.dart`.

### `lib/application/` (Use Cases & Orchestration)
The orchestration layer coordinating Domain and Infrastructure.
- **`services/`**:
  - `RoomStateReconciliationService`: Applies incoming CRDT deltas on top of milestone snapshots.
  - `CombatEncounterService`: Manages multi-creature encounter lifecycles and turn execution.
  - `PartyRoomService`: Handles campaign room connectivity and state streaming.

### `lib/infrastructure/` (The Adapters & External I/O)
Implementations of domain ports, external serialization, and storage adapters.
- **`dtos/`**: Data Transfer Objects (`CharacterDto`, `CampaignProfileDto`, `AnimatedObjectDto`, `CharacterTelemetryDto`). Handles `fromJson` and `toJson`, numeric bounds clamping, and unparsed payload preservation.
- **`dtos/crdt/`**: DTOs for distributed CRDT types (`HybridLogicalClockDto`, `CrdtLwwRegisterDto`, `CrdtOrSetDto`).
- **`repositories/`**: Concrete implementations of domain ports (e.g., `LocalCampaignRepository`, `LocalCharacterRepository`).
- **`resolvers/`**: Telemetry and migration adapters (`CharacterTelemetryResolver`).
- **`di/`**: Service Locator registration (`injection_container.dart` with `sl`).

### `lib/presentation/`, `lib/screens/`, `lib/widgets/` (The UI)
Flutter presentation layer.
- **`core/`**: Shared accessible widgets (`AccessibleActionTile`).
- **`screens/`**: Top-level page views (e.g., `CharacterSheetView`, `ArenaSimulatorScreen`, `DiceRollerScreen`).
- **`widgets/`**: Modular UI components, custom painters, and interactive dialogs.
- **`providers/`**: State management (e.g., `CharacterSheetController`, `SettingsProvider`).
- **RULE:** UI code must not contain core business logic or dice math. It formats domain data and dispatches user intents.

## Decentralized State (CvRDT)
Network and room state is event-sourced and conflict-free:
- State mutations are packaged into Convergent Replicated Data Types (CvRDTs).
- Causality and ordering are tracked via **Hybrid Logical Clocks (HLC)**.
- Collisions are resolved deterministically using `nodeId` lexicographical tie-breaking.
- Detailed rules are documented in `docs/DATA_SAFETY_AND_CRDT.md` and `.agents/rules/crdt_and_sync.md`.