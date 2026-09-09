# Gemini / Antigravity AI Directives

This project enforces strict **Domain-Driven Design (DDD)**, **Hexagonal Architecture (Ports and Adapters)**, **CvRDT Distributed State Synchronization**, and **SRD 5.1 / 5.2 Dual-Ruleset Compliance**.

For full codebase documentation, directory maps, and engineering directives, see:
- [AGENTS.md](file:///AGENTS.md): Master AI Directives & Codebase Fast Navigation Index
- [.agents/rules/architecture.md](file:///.agents/rules/architecture.md): Hexagonal Architecture & Domain Purity
- [.agents/rules/crdt_and_sync.md](file:///.agents/rules/crdt_and_sync.md): CvRDT & Distributed State Directives
- [.agents/rules/dnd_rulesets.md](file:///.agents/rules/dnd_rulesets.md): 2014 RAW vs 2024 Revised Rules Matrix
- [.agents/rules/a11y_and_ui.md](file:///.agents/rules/a11y_and_ui.md): Accessibility (48x48dp, Semantics, 2.0x Dynamic Type)
- [.agents/rules/data_and_performance.md](file:///.agents/rules/data_and_performance.md): DTOs, `unparsedPayload`, and Precomputation
- [.agents/rules/testing_and_workflows.md](file:///.agents/rules/testing_and_workflows.md): Targeted Test & Build Commands

## Quick Rules Summary
1. **Domain Purity:** Files in `lib/domain/` MUST NOT import `package:flutter/...`. Use pure Dart annotations (`package:meta/meta.dart`). Verified by `flutter test test/domain/domain_purity_test.dart`.
2. **Ports & Adapters:** Interfaces go in `lib/domain/ports/`; implementations go in `lib/infrastructure/repositories/`.
3. **CvRDT Immutability:** `HybridLogicalClock`, `CrdtLwwRegister`, and `CrdtOrSet` mutations return new instances. Use deterministic `nodeId` tie-breakers and implement `prune(threshold)`.
4. **DTO Safety:** Map JSON to DTOs in `lib/infrastructure/dtos/` with numeric bounds clamping and `unparsedPayload` retention.
5. **A11y:** 48x48dp touch targets minimum, expand abbreviations in `Semantics` labels, support `TextScaler.linear(2.0)`.
6. **No Product Identity:** Strictly SRD 5.1 & 5.2 open content (CC-BY-4.0).
7. **Continuous Documentation & Living Rules Protocol:** Before completing any run, sync [README.md](file:///README.md) (features, tests, architecture) and audit/codify newly learned patterns or corrections into [AGENTS.md](file:///AGENTS.md), [GEMINI.md](file:///GEMINI.md), and [.agents/rules/](file:///.agents/rules/).

