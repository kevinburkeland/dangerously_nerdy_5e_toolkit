# Gemini / Antigravity AI Directives

This project enforces **Domain-Driven Design (DDD)**, **Hexagonal Architecture**, **CvRDT Distributed State Synchronization**, and **SRD 5.1 / 5.2.1 Dual-Ruleset Compliance**.

For full system architecture, fast navigation indexes, and detailed engineering directives, refer to the canonical governance files:
- [.antigravityrules](file:///.antigravityrules): Repository Constitution & Hard Architectural Invariants
- [AGENTS.md](file:///AGENTS.md): Architecture & Navigation Operating Manual
- [.agents/rules/architecture.md](file:///.agents/rules/architecture.md): Hexagonal Boundaries, Layers & Semantic Ownership
- [.agents/rules/crdt_and_sync.md](file:///.agents/rules/crdt_and_sync.md): CvRDT Convergence, Protocols & Transport Waterfall
- [.agents/rules/dnd_rulesets.md](file:///.agents/rules/dnd_rulesets.md): 2014 RAW vs 2024 Revised Dual-Ruleset Matrix
- [.agents/rules/data_and_performance.md](file:///.agents/rules/data_and_performance.md): DTO Boundaries, Hot-Loop Math & Storage Durability
- [.agents/rules/a11y_and_ui.md](file:///.agents/rules/a11y_and_ui.md): Touch Targets (48dp), Semantics & Dynamic Type Scaling (2.0x)
- [.agents/rules/testing_and_workflows.md](file:///.agents/rules/testing_and_workflows.md): Targeted Test Commands & Quality Gates
- [.agents/rules/codebase_map.md](file:///.agents/rules/codebase_map.md): Codebase Fast Lookup Map

---

## 🛡️ Core Architectural Principles Summary

1. **Agnostic Core Boundary (`vtt_engine_core`):**
   - Agnostic tabletop primitives, CvRDT primitives, storage snapshot ports, and ruleset SPI reside in `../vtt-engine-core`.
   - Never re-implement or leak D&D 5e-specific mechanics into engine primitives.
   - Pinned Git dependency synchronization protocol (`git.ref` in `pubspec.yaml`) is mandatory.

2. **Standalone Ruleset Module Boundary (`vtt_ruleset_dnd5e`):**
   - Reusable D&D 5e mechanics, progression engines, spellcasting rules, combat resolution, and canonical 5e domain models reside in `../vtt-ruleset-dnd5e`.
   - Consumed by the toolkit via pinned Git dependency (`package:vtt_ruleset_dnd5e`).
   - The toolkit must not silently re-grow an internal D&D rules engine.

3. **Semantic Ownership Principle:**
   - Reusable D&D mechanics belong in `vtt-ruleset-dnd5e`. Application orchestration and platform integration belong in the toolkit. Generic tabletop concepts belong in `vtt-engine-core`. Ownership follows semantics, not convenience or current call-site count.
   - Extend or adapt engine contracts at the ruleset/application boundary rather than reimplementing generic engine infrastructure locally.

4. **Dependency Direction:**
   - `vtt_engine_core` -> `vtt_ruleset_dnd5e` -> Application Orchestration -> Infrastructure -> Presentation.
   - Zero Flutter in `vtt_ruleset_dnd5e` or toolkit `lib/domain/` and `lib/infrastructure/dtos/` (`package:meta/meta.dart` only).

5. **Cross-Boundary Repository Pivot Protocol:**
   - When inspecting or editing `../vtt-engine-core` or `../vtt-ruleset-dnd5e`, read the target repo's `.antigravityrules` and `AGENTS.md`, suspend toolkit-specific assumptions, and adhere strictly to target repo local governance.

5. **Clean Room SRD Purity & Anti-Hallucination:**
   - Bundled code and fixtures adhere strictly to SRD 5.1 / 5.2.1 (CC-BY-4.0) with zero Wizards of the Coast Product Identity.
   - Zero coupling to third-party tool schemas; ingestion utilizes agnostic structural indicators.
   - Unknown stays unknown: missing attributes remain `null`; never synthesize tabletop defaults.

6. **Distributed State & Distributed Mutex:**
   - Replicated state converges deterministically via CvRDT join-semilattice merges.
   - In-memory CRDT joins and profile reconciliation are scoped within `_syncMutex`; persistence executes asynchronously outside the lock to prevent deadlocks.
   - Currency reductions apply differential decrements against the underlying signed mathematical value in `PnCounter`; never re-seed with positive scalars.
   - Inbound transport frames enforce SHA-256 LRU deduplication and sliding lookback filtering.

7. **Definition of Done:**
   - Static analysis (`flutter analyze`) must pass with zero issues.
   - Relevant test suites must pass.
   - Living documentation is updated when architecture, public behavior, or documented capabilities change.
