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
   * Spell slot matrices, cantrip tier scaling, upcasting formulas, pact magic, and preparation caps live in `lib/services/rules/spellcasting_rules_engine.dart`.
   * Dice formula generation and expression formatting live in `lib/utils/dice_formatters.dart`.
   * Data stat blocks and spell catalogs must adhere strictly to the System Reference Document 5.1 & 5.2 (SRD 5.1 & SRD 5.2) Creative Commons (CC-BY-4.0) guidelines.

3. **Accessibility & Semantics:**
   * Ensure interactive custom elements provide descriptive `Semantics` tags, header announcements, and screen-reader support via `A11yService`.
   * Touch targets should adhere to the standard 48x48dp minimum size.

4. **Code Cleanliness & Quality:**
   * Zero warnings on `flutter analyze`.
   * Write unit or widget tests for any new business logic, stat block calculations, or dialogs in the `test/` directory.

---

## Developer Certificate of Origin (DCO) & Licensing

This project operates strictly under an **inbound = outbound** contribution model under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE).

To decentralize copyright ownership and keep this project truly community-owned, **we deliberately do not use a Contributor License Agreement (CLA)**. You retain 100% copyright ownership of your contributions. In exchange, all contributions are made under the Developer Certificate of Origin (DCO) version 1.1.

By contributing to this repository, you certify that you have the right to submit your work under the AGPL-3.0 license according to the DCO:

```text
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

### Dual Licensing Scope: AGPL-3.0 vs. SRD CC-BY-4.0

This repository maintains a strict separation between software implementation and tabletop game mechanics:

| Component Type | Applicable License | Details |
| :--- | :--- | :--- |
| **Software Implementation & Code** | **GNU AGPLv3** | All Dart code, Flutter UI widgets, state architecture, simulation engines (combat arena, Monte Carlo rollers, DPR calculators), Anti-Corruption Layer (ACL) parsers, build scripts, and automated test suites. |
| **D&D 5e Rules Content & Game Mechanics** | **Creative Commons CC-BY-4.0** | All stat blocks, spells, spell slot matrices, creature attributes, item tables, and rules text derived from the System Reference Document 5.1 & 5.2 (SRD 5.1 & 5.2). |
| **Third-Party Product Identity** | **STRICTLY PROHIBITED** | No trademarked monolith creatures (Mind Flayers, Beholders, Displacer Beasts, Yuan-Ti), no named lore wizards (Bigby, Mordenkainen, Tasha), and no proprietary campaign setting lore. |

### Signing Off Commits (`git commit -s`)

Every commit submitted to this project must be signed off with a `Signed-off-by:` trailer matching your commit author name and email. Git provides the `-s` flag to automate this:

```bash
git commit -s -m "feat: your descriptive commit message"
```

This sign-off confirms that you agree to the DCO and assert your right to submit your contribution under the applicable project licenses (AGPLv3 for software, CC-BY-4.0 for SRD game data) without transferring your copyright.

---

## Submitting Pull Requests

1. **Create a descriptive feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Commit your changes with DCO sign-off:**
   * Write clear, concise commit messages following standard conventional commits (e.g. `feat: add Owlbear stat block`, `fix: correct prone advantage toggle in batch attacks`).
   * Always include `-s` to sign off on the DCO:
     ```bash
     git commit -s -m "feat: add Owlbear stat block"
     ```
3. **Run validation checks:**
   * Ensure `flutter analyze` passes with 0 diagnostics.
   * Ensure `flutter test` passes 100% of test cases.
4. **Open a Pull Request:**
   * Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
   * Reference any relevant Issue numbers (e.g., `Fixes #42`).
