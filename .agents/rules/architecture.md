# Hexagonal Architecture & Clean DDD Rules

## 1. Architectural Layers & Boundaries

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
│  (consumes vtt_engine_core)│ │   - dtos/ & dtos/crdt/  │
│  - rules/ & simulation/    │ │   - repositories/       │
│  - modules/dnd5e/          │ │   - adapters/ & mappers/│
│  - ports/ (Interfaces)     │ │   - di/                 │
└────────────────────────────┘ └─────────────────────────┘
```

### 1.1. Domain Layer (`lib/domain/`)
- **Zero Flutter Engine Runtime:** Files in `lib/domain/` MUST NOT import `package:flutter/...`. Use `package:meta/meta.dart` for `@immutable`. Enforced automatically by `test/domain/domain_purity_test.dart`.
- **Engine Core Decoupling:** Standalone engine contracts (CRDT primitives, agnostic tabletop value objects, storage snapshot ports) are consumed from `vtt_engine_core` (`../vtt-engine-core`). Domain logic in this repository provides the D&D 5e-specific ruleset implementations (`lib/infrastructure/modules/dnd5e/`, `lib/domain/rules/`).
- **No I/O Imports:** No persistence (Hive, SQLite), network (HTTP, WebSockets, Firebase), or device platform channel imports are permitted in `lib/domain/`.
- **Pure Models & Copy-Transforms:** All entities and value objects must have `const` constructors and `copyWith()` mutators. In-place mutating methods (`takeDamage`, `heal`, `applyHeal`, `grantTempHp`) are strictly forbidden; use pure copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`).
- **Ports (Dependency Inversion):** Abstract repository, transport, and time ports reside in `lib/domain/ports/`. Ports must import pure domain contracts only; never import application services or infrastructure DTOs.

### 1.2. Application Layer (`lib/application/`)
- Orchestrates workflows between Domain logic and Infrastructure ports.
- Application services (e.g., `RoomStateReconciliationService`, `CombatEncounterService`, `RoomSyncOrchestrator`, `StorageDurabilityCoordinator`) hold no long-term persistent state; they process domain events, invoke rules, and delegate I/O to ports.
- Application services MUST NOT import infrastructure DTOs or concrete adapters directly.

### 1.3. Infrastructure Layer (`lib/infrastructure/`)
- Implements domain ports defined in `lib/domain/ports/`.
- **Repositories (`lib/infrastructure/repositories/`):** Persistence implementations (e.g., `LocalCampaignRepository`, `LocalCharacterRepository`).
- **Adapters (`lib/infrastructure/adapters/`):** Transport (`WebRtcMeshAdapter`, `FirebaseFallbackAdapter`), storage serializers, and network ingestors (`GithubIngestorAdapter`).
- **DTOs (`lib/infrastructure/dtos/`):** Translate wire/disk JSON to domain models and vice versa. Files in `lib/infrastructure/dtos/` must not import Flutter; use `package:meta/meta.dart` for `@immutable` (enforced by `test/infrastructure/dtos/dto_purity_test.dart`).
- **Dependency Injection (`lib/infrastructure/di/`):** Service Locator (`injection_container.dart` / `sl`) registers singletons and factories. Downcasting ports to concrete implementations (e.g., `transportPort as CascadingTransportRouter`) is strictly prohibited.

### 1.4. Presentation Layer (`lib/presentation/`, `lib/screens/`, `lib/widgets/`)
- User interface and rendering only.
- Zero business logic, rule evaluations, or dice math. All mechanics are delegated to application services or domain rules. State consumption routes through providers/controllers (`lib/providers/`).

### 1.5. Clean Room Anti-Corruption Layer (ACL)
- **Zero Third-Party Tool Coupling:** Core logic must not contain proprietary site keys, splatbook abbreviations, or tool-specific bundle names.
- **Agnostic Structural Ingestion:** Ingestion adapters dynamically traverse payloads using generic structural indicators (`name`, `entries`, `hitDie`, `stats`, `type`, `level`, `actions`).
- **External Syntax Isolation:** External pipe-delimited syntax (`Feature|Class|Source|Level`, `Spell|Source#c`) is isolated into dedicated infrastructure ACL parsers (`CompendiumPipeParser`).
- **Capability-Driven Mechanics:** Combat calculations, attack substitutions, and capabilities must resolve via domain `FeatureGrant`s (`GrantType.attackAbilitySubstitution`, `GrantType.capabilityFlag`) or normalized capability flags (`flags['initiativeBonusMode']`). Never pattern match on non-SRD class, subclass, or feat names.

### 1.6. Cross-Boundary Repository Pivot Protocol
When inspecting, editing, or executing commands in an external repository (e.g. `../vtt-engine-core`):
1. **Mandatory Ingestion:** The agent MUST view and parse `../<target-repo>/.antigravityrules` and `../<target-repo>/AGENTS.md` before making any modifications.
2. **Context Suspension:** For any code inside that target repository, the agent MUST explicitly suspend and disregard host-specific guidelines (e.g. Flutter UI widgets, D&D 5e mechanics, 48dp touch targets, SRD legal compendiums).
3. **Local Governance:** The target repository's rules, pure Dart constraints, and compliance gates (`test/compliance/`) take absolute precedence for that directory.
