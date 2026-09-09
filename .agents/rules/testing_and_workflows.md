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
