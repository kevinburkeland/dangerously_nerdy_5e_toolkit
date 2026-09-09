# System Architecture

This repository strictly follows **Domain-Driven Design (DDD)** combined with **Hexagonal Architecture (Ports and Adapters)**.

## Directory Structure

### `lib/domain/` (The Core)
The pure Dart center of the application. 
- **`models/`**: Immutable business objects (e.g., `Character`, `CampaignProfile`).
- **`rules/`**: Pure mechanical logic (e.g., `RulesetEngine`, `CombatEncounterService`).
- **`crdt/`**: Distributed data structures (`HybridLogicalClock`, `CrdtLwwRegister`).
- **`ports/`**: Abstract interfaces defining what the domain needs (e.g., `ICampaignRepository`).
- **RULE:** Absolutely no `package:flutter` or external persistence libraries (Hive, Firebase, HTTP) allowed here.

### `lib/infrastructure/` (The Adapters)
Implementations of the domain ports, handling external data formats.
- **`dtos/`**: Data Transfer Objects (e.g., `CharacterDto`). Handles `fromJson` and `toJson`, clamping, and legacy schema migrations.
- **`repositories/`**: Concrete implementations of domain ports (e.g., `LocalCampaignRepository` using SharedPreferences/Hive).
- **RULE:** This layer translates the dirty outside world into pure Domain models.

### `lib/application/` (Use Cases)
Orchestration layer. 
- **`services/`**: Coordinates tasks between the Domain and Infrastructure (e.g., taking an incoming network sync, updating the local database, and pushing the new state to the UI).

### `lib/presentation/` (The UI)
Flutter-specific code.
- **`screens/`**: Top-level page layouts.
- **`widgets/`**: Reusable UI components.
- **`providers/`**: State management (e.g., ChangeNotifier, Riverpod).
- **RULE:** UI code must not contain core business logic or dice math. It only formats Domain data and dispatches user intents.

## Decentralized State (CvRDT)
Network state is event-sourced and conflict-free.
- We do not use standard "last-write-wins" JSON overwrites for network synchronization.
- Volatile state is wrapped in Convergent Replicated Data Types (CvRDTs) utilizing Hybrid Logical Clocks (HLC) to guarantee deterministic merging across P2P partitions.