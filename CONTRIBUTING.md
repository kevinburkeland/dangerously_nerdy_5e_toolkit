# Contributing to DangerouslyNerdy 5e Toolkit

Thank you for your interest in contributing to the **DangerouslyNerdy 5e Toolkit**! We welcome contributions ranging from bug reports and SRD 5.1 rule corrections to UI/UX improvements, accessibility enhancements, and new companion tools.

---

## Code of Conduct

All contributors and maintainers are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful and collaborative in all discussions and pull requests.

---

## Development Setup

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0.0 or higher)
* [Dart SDK](https://dart.dev/get-started/sdk) (3.0.0 or higher)
* A modern browser (Chrome / Edge / Firefox) or an Android emulator/device

### Getting Started

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/dangerously_nerdy_5e_toolkit.git
   cd dangerously_nerdy_5e_toolkit
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application locally:**
   ```bash
   flutter run -d chrome
   ```

4. **Verify tests and linter:**
   ```bash
   flutter analyze
   flutter test
   ```

5. **Build web bundle (PWA):**
   ```bash
   ./scripts/build_web.sh
   ```

---

## Architectural Guidelines

To maintain code hygiene, performance, and accessibility:

1. **State Management:**
   * Global app settings and persistent configurations use `SettingsProvider` and `SettingsScope` (ChangeNotifier + InheritedNotifier).
   * Local, ephemeral UI state uses standard `StatefulWidget` (`setState`) or dedicated `ValueNotifier`.
   * Avoid adding redundant or heavy state management libraries unless strictly needed.

2. **D&D 5e Rules & Math:**
   * All 5e score-to-modifier conversions, proficiency calculations, and ratio scaling live in `lib/services/rules/dnd_5e_rules_engine.dart`.
   * Dice formula generation and expression formatting live in `lib/utils/dice_formatters.dart`.
   * Data stat blocks must adhere to the System Reference Document 5.1 (SRD 5.1) or official Open Gaming / Creative Commons guidelines.

3. **Accessibility & Semantics:**
   * Ensure interactive custom elements provide descriptive `Semantics` tags, header announcements, and screen-reader support via `A11yService`.
   * Touch targets should adhere to the standard 48x48dp minimum size.

4. **Code Cleanliness & Quality:**
   * Zero warnings on `flutter analyze`.
   * Write unit or widget tests for any new business logic, stat block calculations, or dialogs in the `test/` directory.

---

## Submitting Pull Requests

1. **Create a descriptive feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Commit your changes:**
   * Write clear, concise commit messages following standard conventional commits (e.g. `feat: add Owlbear stat block`, `fix: correct prone advantage toggle in batch attacks`).
3. **Run validation checks:**
   * Ensure `flutter analyze` passes with 0 diagnostics.
   * Ensure `flutter test` passes 100% of test cases.
4. **Open a Pull Request:**
   * Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
   * Reference any relevant Issue numbers (e.g., `Fixes #42`).
