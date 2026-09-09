# Testing & Development Workflows

## 1. Targeted Test Commands

Always prefer running targeted tests during active development rather than the entire 1,297-test suite to ensure fast feedback loops (< 5 seconds):

```bash
# Domain purity & pure Dart rules
flutter test test/domain/domain_purity_test.dart

# CvRDT & Distributed State tests
flutter test test/domain/crdt/
flutter test test/infrastructure/dtos/crdt/
flutter test test/application/services/room_state_reconciliation_service_test.dart

# Application Services
flutter test test/application/

# Infrastructure Repositories & DTOs
flutter test test/infrastructure/

# Accessibility & Dynamic Type Scaling (2.0x)
flutter test test/accessibility/

# Character Sheet & Action Economy
flutter test test/widgets/character_sheet/
flutter test test/services/rules/

# Compendium & ACL Ingestion
flutter test test/services/acl/

# Full test suite
flutter test
```

## 2. Static Analysis & Lint Quality Gates

Static analysis must pass with zero issues:

```bash
flutter analyze
```

Options are defined in `analysis_options.yaml`.

## 3. Web & Production Build Verification

To verify the web PWA build:

```bash
./scripts/build_web.sh
```

This script:
- Compiles Flutter Web to `build/web` (with wasm optimizations if enabled).
- Injects a dynamic build timestamp into `web/flutter_service_worker.js` and `web/index.html` to guarantee cache-busting.
- Verifies PWA manifest and service worker integrity.

## 4. Run Finalization & Living Documentation Protocol (Definition of Done)

Before completing any task or feature delivery, the agent must perform the following two audit gates:

### Gate 1: `README.md` & Project Documentation Synchronization
1. **Test Verification & Metric Updates:** Run relevant tests. If the test count changes from the previous milestone (e.g., 1,297 tests), update the test counts in [README.md](file:///README.md) and [AGENTS.md](file:///AGENTS.md).
2. **Feature Matrix & Capabilities:** If new features, P2P capabilities, screens, or mechanical rules were introduced, add them to the feature tables/checklists in [README.md](file:///README.md).
3. **Architecture & CLI Scripts:** Update directory trees, data flow diagrams, or script instructions if project layout or tooling was altered.

### Gate 2: Self-Refining AI Rules Audit
1. **Codify New Conventions:** If a new architecture pattern (e.g., port/adapter, DTO serialization policy, CRDT message format) was introduced, document it in the corresponding rule file in `.agents/rules/`.
2. **Prevent Regression of Fixes:** If a subtle framework quirk, platform-specific issue (Flutter Web, PWA service worker, Hive caching), or user correction was encountered during the run, codify the preventive guideline directly into `.agents/rules/<topic>.md` or [AGENTS.md](file:///AGENTS.md).
3. **Directory Map Maintenance:** If new domain entities, application services, or widgets were added, ensure they are reflected in the Fast Codebase Navigation Index in [AGENTS.md](file:///AGENTS.md) and `.agents/rules/codebase_map.md`.

