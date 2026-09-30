# Testing & Development Workflows

## 1. Targeted Test Commands
Execute targeted test suites during active development for fast feedback loops (< 5s):

```bash
# Domain purity & pure Dart rules
flutter test test/domain/domain_purity_test.dart
flutter test test/infrastructure/dtos/dto_purity_test.dart

# Application state reconciliation & CRDT DTOs
flutter test test/application/services/room_state_reconciliation_service_test.dart
flutter test test/infrastructure/dtos/crdt_dtos_test.dart

# Application services & orchestration
flutter test test/application/

# Infrastructure adapters, repositories & D&D 5e module
flutter test test/infrastructure/

# Legal & product identity compliance invariants
flutter test test/infrastructure/compliance/srd_legal_compliance_test.dart

# Accessibility & dynamic type scaling (2.0x)
flutter test test/accessibility/

# Character sheet & action economy
flutter test test/widgets/character_sheet/
flutter test test/services/rules/

# Compendium & ACL ingestion
flutter test test/services/ingestion/
flutter test test/services/importers/

# Full test suite
flutter test
```

## 2. Static Analysis & Lint Quality Gates
Static analysis must pass with zero warnings or errors before committing:
```bash
flutter analyze
```

## 3. Web & Production Build Verification
To verify the production PWA bundle:
```bash
./scripts/build_web.sh
```
This script compiles Flutter Web to `build/web`, injects dynamic build version timestamps into service workers and HTML for cache-busting, and verifies PWA manifest integrity.

## 4. Test Suite Reliability Directives
- **SharedPreferences Mock Initialization:** Tests interacting with persistence services (`PartyRoomService`, `DiceRoomService`, `LocalCampaignRepository`) must invoke `SharedPreferences.setMockInitialValues({})` in `setUp()` to prevent unhandled channel errors.
- **Homebrew Cache Invalidation:** Tests verifying homebrew persistence or compendium ingestion must invoke `HomebrewPersistenceService().invalidateAllCaches()` and `clearAllHomebrew()` in `setUp()` to eliminate cache bleed across tests.
- **Zero Matchers in Hot Loops:** Never execute `expect()` inside high-iteration loops (e.g., 10,000 Monte Carlo runs). Matcher tracking incurs massive overhead; accumulate results and assert once outside the loop.
- **Strict SRD Fixture Compliance:** Test names, descriptions, groups, and mock fixtures must strictly use SRD or generic homebrew terms (e.g., `Tenacious`, `Champion`, `Voidling`). Prohibited WotC Product Identity terms must never appear in test suites.

## 5. Definition of Done & Living Documentation Protocol
Before completing any engineering task:
1. **Verification:** Ensure static analysis (`flutter analyze`) reports zero issues and relevant test suites pass.
2. **Living Documentation:** Update living documentation (`README.md`, `AGENTS.md`, or `.agents/rules/`) when architecture, public behavior, or documented capabilities change. Do not perform documentation churn for routine internal code changes.
