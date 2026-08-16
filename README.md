<p align="center">
  <img src="web/icons/Icon-512.png" width="128" height="128" alt="DangerouslyNerdy 5e Toolkit Logo" />
</p>

# 🧙‍♂️ DangerouslyNerdy 5e Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![PWA Ready](https://img.shields.io/badge/PWA-Installable-5A0FC8?logo=pwa)](https://web.dev/progressive-web-apps/)
[![Tests](https://img.shields.io/badge/Tests-258%20Passing-brightgreen.svg)](test)
[![SRD 5.1 & 5.2](https://img.shields.io/badge/Rules-SRD%205.1%20%26%205.2%20CC--BY--4.0-blueviolet.svg)](LEGAL_ATTRIBUTION_MODAL.md)

A modern, high-performance Flutter application designed for 5th Edition (5e) tabletop RPG players and Game Masters. Features a suite of **dedicated player & DM tools**, including a dual-rulebook **DM's Screen with 2014 RAW vs 2024 Revised rules toggle**, a comprehensive **5e Spellbook Companion & Rules Engine**, simultaneous batch attack rolling for 5e summoning spells and magic items, custom dice pool builders with JSON preset import/export, real-time multiplayer dice rooms, interactive 3D polyhedral dice physics, rich theme customization, and a cryptographically secure random number generator.

---

## ✨ Key Features & Suite of Tools

### 📜 1. 5e Spellbook Companion & Rules Engine (2014 RAW vs 2024 Revised)
* **Modular Official SRD Spell Catalog**: Built-in support for official SRD spells across all tiers (Cantrips through 9th Level) with side-by-side 2014 & 2024 revision data.
* **Side-by-Side Edition Comparisons**: High-contrast diff badges (`✨ 2024 Diff`) and side-by-side comparison modal highlighting major rule changes (*Counterspell* Constitution saves, *Cure Wounds* 2d8 base healing, *Divine Smite* Bonus Action casting, *Spiritual Weapon* Concentration, *Barkskin* temporary HP, *Conjure Animals* emanation rework, and more).
* **Tabletop Quick-Roll & Upcast Sandbox**: One-tap quick-roll modal with dynamic spell slot picker (1st to 9th level) and spellcasting ability modifier selector (-1 to +7), computing dice additions in real time.
* **RAW Mechanics Engine**:
  - **Cantrip Scaling Engine**: Tier scaling at character levels 1, 5, 11, and 17.
  - **Multiclass Spell Slot Matrix**: Enforces exact slot progression for Full Casters, Half Casters (Paladin/Ranger), and Artificers (`ceil(Level / 2)`).
  - **Pact Magic Pool Tracker**: Warlock short-rest slot progression separate from standard multiclass slots.
  - **Caster Preparation Limits**: Formula verification for Full Casters (`Level + Mod`), Half Casters (`floor(Level / 2) + Mod`), and Artificers.
  - **Action Economy & Concentration**: Enforces RAW 2014 & 2024 Bonus Action spellcasting restrictions and concentration break DCs.
* **Personal Spellbook Pinning**: Bookmark key spells for rapid in-combat access with dedicated filter tabs and search.
* **Dynamic School Glyphs**: Vector-drawn procedural D&D school glyphs with custom action rings (Action, Bonus Action, Reaction, Concentration, Ritual).

### 🛡️ 2. DM's Screen & Dual Rulebook Engine (2014 RAW vs 2024 Revised)
* **2014 vs 2024 Rules Switch**: Seamlessly toggle between 2014 5e RAW rules and the 2024 Revised rules across all combat mechanics, conditions, environment hazards, DCs, resting, and spell limits.
* **Side-by-Side Edition Comparison**: Interactive comparison dialogs and "2024 Diff" badges highlighting every major rule revision (e.g., -2 Exhaustion per level, Unarmed Strike Save DCs, Bonus Action potions, and Disadvantage Initiative for surprise).
* **Rule Pinning & Search**: Pin frequently referenced rules to the top of your screen, with instant real-time keyword search and category filtering.
* **Quick DM Roller**: Instant d20, d100, d12, d8, and d6 roller bar directly inside the DM screen.

### 🎲 3. Core Dice Roller & 3D Polyhedral Physics
* **Multi-Dice Pools**: Roll any combination of standard polyhedral RPG dice (`d4`, `d6`, `d8`, `d10`, `d12`, `d20`, `d100`) plus custom N-sided dice (`d3`, `d7`, `d30`, `d1000`, etc.).
* **3D Polyhedral Visualizer**: Real-time 3D rendered dice rolling with realistic angular momentum, winning-face illumination, natural 20 critical burst particle effects, and screen shake.
* **Roll Modes & Modifiers**: Apply flat positive/negative modifiers and toggle Advantage or Disadvantage.
* **Expandable Roll History**: Visual breakdown showing individual die results, dropped rolls, natural 20 / natural 1 highlights, formulas, and expandable roll detail feeds.
* **JSON Presets**: Save custom dice formulas (e.g., "Fireball 8d6", "Rogue Sneak Attack") and export/import JSON presets across devices.
* **Haptic Feedback**: Multi-level tactile vibration triggers (Off, Light Ticks, Heavy Combat Rumble) for dice clicks, roll animations, and critical successes.

### 🌐 4. Live Multiplayer Dice Rooms
* **Real-Time Synchronization**: Connect to shared dice rooms powered by Firebase Firestore for live party transparency.
* **6-Character Room Codes**: Simple 6-character alphanumeric room codes (`ROOM-XXXXXX`) with input sanitization and random code generation.
* **Live Connection Status**: Visual status banner indicating active room connection, participant display names, and real-time roll event feeds.
* **Ephemeral Architecture**: Stream-only roll broadcasts designed for privacy and minimal latency without permanent data harvesting.

### 🔮 5. Spell Minion Companions (6 Tools)
* **⚔️ Animate Objects Companion**: Enforces RAW point budgets (10 pts at 5th level up to 18 pts at 9th level) across Tiny, Small, Medium, Large, and Huge animated objects.
* **🐾 Conjure Animals Squad Manager**: Summons 8 Wolves (CR 1/4) at 3rd level up to 32 beasts at 9th level with built-in **Pack Tactics** advantage detection.
* **💀 Animate Dead Squad Tracker**: Manages Skeleton archers and Zombie frontline HP, tracking upcast limits from 1 to 13 undead.
* **🧟 Create Undead Manager**: Commands 3 Ghouls (6th level) up to 6 Ghouls, Ghasts, Wights, or Mummies at higher slot levels.
* **🌋 Conjure Elementals Companion**: Manages Air, Earth, Fire, and Water Elementals (CR 5+) and swarms of Mephits/Gargoyles.
* **🦗 Giant Insect Squad Tracker**: Transforms ordinary insects into Giant Centipedes (10), Giant Wasps (5), or Giant Spiders (3).

### 📯 6. Magic Item Rollers & Minions (5 Tools)
* **👜 Gray Bag of Tricks**: Roll d8 on the Gray Bag table (Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, or Giant Elk).
* **👜 Rust Bag of Tricks**: Roll d8 on the Rust Bag table (Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, or Brown Bear).
* **👜 Tan Bag of Tricks**: Roll d8 on the Tan Bag table (Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, or Tiger).
* **📯 Horn of Valhalla Roller**: Roll variant Berserker squads for Silver (2d4+2), Brass (3d4+3), Bronze (4d4+4), and Iron (5d4+5) horns.
* **🗿 Figurines of Wondrous Power**: Animates Bronze Griffon, Onyx Dog (with Pack Tactics), and Marble Elephant statblocks with batch rolling.

### ⚔️ 7. Instant Batch Attack Roller & HP Tracker
* **Batch Attack Engine**: Roll attack and damage for up to 50 minions simultaneously against target AC with Advantage, Disadvantage, Normal rolling, and RAW Critical Hit doubling.
* **Live Squad HP Tracker**: Visual progress bars per minion, custom creature naming, temporary HP tracking, squad initiative rolling, quick +/- HP adjustments, direct HP input, and damage resistance markers.
* **Mass Damage & Group Healing**: AoE damage and healing modal to apply group HP changes across all minions or selected squads with full/half damage saving throw calculations.
* **Creature Stat Block Dialog**: Interactive full statblock inspection for every summoned minion (AC, HP, Speed, Ability Scores, Actions, Traits, Senses, and Languages).

### 📖 8. Tactical Reference & Rules Engine
* **Action Economy Guide**: Interactive breakdown of Actions, Bonus Actions, Reactions, Movement, and Free Object Interactions.
* **5e Condition Reference**: Instant lookup for all 15 SRD conditions (Blinded, Charmed, Frightened, Grappled, Paralyzed, Poisoned, Prone, Restrained, Stunned, etc.) with tactical effects.
* **Integrated SRD 5.1 & 5.2 Rulebook**: Interactive reference tables, stat cards, upcasting rules, and RAW tactical tips per tool.

### 🎨 9. Theme Engine & User Preferences
* **Theme Modes**: System, Dark Mode (default), and Light Mode.
* **OLED Pitch Black**: Pure `#000000` background for AMOLED battery savings.
* **Fantasy Accent Palettes**: Choose between 9 rich RPG themes: `Paladin Gold`, `Eldritch Purple`, `Ranger Emerald`, `Necrotic Slate`, `Dragonfire Crimson`, `Arcane Sapphire`, `Bardic Rose`, `Abyssal Teal`, and `Celestial Amber`.
* **Micro-Interactions & Performance**: Fine-grained toggles for Critical Hit & Fumble Effects (screen shake, rumble, and ember bursts), Spell Particle Canvas FX, 3D Dice Overlays, and a Performance/Battery Saver mode.
* **Pure Flutter Vector Branding**: 100% vector-rendered tech+fantasy d20 logo (`AppLogo`) with `DN` center crest, curved `DANGEROUSLY NERDY` telemetry ring, and interactive hover/tap momentum spin physics.
* **Preferences Persistence**: Automatically saves user settings locally via `SharedPreferences`.

### 🔒 10. Cryptographically Secure RNG & Production Security
* Built using Dart's native `Random.secure()` (`lib/utils/secure_random.dart`) to ensure completely unbiased, cryptographically secure random distribution.
* **Strict Content Security Policy (CSP)** and Firebase security rules ensure robust client-side isolation and safe multi-user interactions.
* **Data Minimization**: Zero PII collection, no account registration required, and complete user data sovereignty.

### 📱 11. Progressive Web App (PWA) & Cross-Platform
* Fully responsive web application with offline PWA Service Worker caching and native app installation prompt on desktop and mobile web.
* Ready for deployment across Web, Android, iOS, and Linux desktop.

---

## 🛠 Project Structure

```
dangerously_nerdy_5e_toolkit/
├── lib/
│   ├── main.dart                   # Entry point, navigation hub, & theme provider setup
│   ├── firebase_options.dart       # Firebase configuration initialization
│   ├── models/                     # Core data models
│   │   ├── animated_object.dart    # Minion statblocks, size rules, & HP tracker
│   │   ├── app_settings.dart       # Theme mode, accent color, & haptic preferences
│   │   ├── custom_preset.dart      # Custom dice pool preset data model
│   │   ├── dice_roll.dart          # Roll pool breakdown & calculation
│   │   ├── dm_screen_data.dart     # DM reference rules (2014 & 2024 comparison)
│   │   ├── room_roll.dart          # Live room multiplayer roll event
│   │   ├── spell_session.dart      # Spell session state, upcasting, & batch roller
│   │   ├── spellbook_data.dart     # SpellItem, editions, schools, and library indexing
│   │   ├── spells/                 # Modular official SRD spell catalogs
│   │   │   ├── cantrips.dart       # Cantrips (0 level)
│   │   │   ├── level_1_spells.dart # 1st Level spells
│   │   │   ├── level_2_spells.dart # 2nd Level spells
│   │   │   ├── level_3_spells.dart # 3rd Level spells
│   │   │   ├── level_4_spells.dart # 4th Level spells
│   │   │   ├── level_5_spells.dart # 5th Level spells
│   │   │   └── high_level_spells.dart # 6th - 9th Level spells
│   │   └── srd_summons/            # SRD 5.1 summon presets & statblocks
│   │       ├── magic_items/        # Bag of Tricks, Horn of Valhalla, Figurines
│   │       ├── spells/             # Animate Objects, Beasts, Undead, Elementals, Insects
│   │       ├── minion_stat_block.dart # Comprehensive creature statblock model
│   │       └── srd_summons_library.dart # Preset catalog library
│   ├── providers/                  # State management providers
│   │   └── settings_provider.dart  # Reactive theme & settings provider
│   ├── screens/                    # Application screens
│   │   ├── dice_roller_screen.dart # Dice roller, 3D physics, presets, & multiplayer rooms
│   │   ├── dm_reference_screen.dart # DM's screen with 2014 vs 2024 rules comparison
│   │   ├── landing_screen.dart     # Categorized dashboard with dedicated tool cards
│   │   ├── minion_tool_screen.dart # Parametric dedicated minion tool screen
│   │   ├── settings_screen.dart    # Theme, accent color, haptics, & 3D dice preferences
│   │   └── spellbook_screen.dart   # 5e Spellbook companion & rules reference screen
│   ├── services/                   # Data services & external integrations
│   │   ├── a11y_service.dart       # Accessibility & screen reader announcements
│   │   ├── base_room_service.dart  # Abstract interface for room syncing
│   │   ├── dice_room_service.dart  # Firebase Firestore real-time room sync
│   │   ├── haptic_service.dart     # Multi-platform tactile haptic feedback
│   │   ├── logging_service.dart    # Structured application logging
│   │   ├── preset_service.dart     # SharedPreferences & JSON import/export
│   │   └── rules/                  # 5e RAW rules, combat & spellcasting engines
│   │       ├── combat_rules_engine.dart # Attacks, saves, critical hits, damage
│   │       ├── dnd_5e_rules_engine.dart # Core ability modifiers & DC formulas
│   │       └── spellcasting_rules_engine.dart # Scaling, multiclass matrix, pact magic
│   ├── theme/                      # Visual design system
│   │   └── app_theme.dart          # Dynamic theme data & color schemes
│   ├── utils/                      # Utilities & helpers
│   │   ├── pwa_helper.dart         # PWA installation prompt helper (cross-platform stub/web)
│   │   └── secure_random.dart      # Cryptographically secure RNG generator
│   └── widgets/                    # Modular UI components
│       ├── app_logo.dart           # Pure Flutter vector tech+fantasy d20 logo & interactive spin
│       ├── batch_attack/           # Batch attack results summary
│       ├── dice_roller/            # 3D dice visualizer, pool builders, roll history, & presets
│       ├── dialogs/                # Modals for presets, batch attacks, legal notices, statblocks, & rules
│       ├── dm_reference/           # Dual-rulebook comparison cards, edition toggles, & diff badges
│       ├── fx/                     # Critical hit visual effects & overlays
│       ├── glyphs/                 # Vector procedural school glyphs & token painters
│       ├── interactive/            # Interactive tactile cards & buttons
│       ├── meters/                 # Animated resource meters & HP bars
│       ├── minions/                # Active session header, object cards, & squad builder
│       ├── room_banner_widget.dart # Live room connection status banner
│       ├── spell_reference.dart    # Interactive 5e spell rulebook table
│       └── spellbook/              # Spell cards, quick-roll dialogs, compare modals, filter sheets
│           ├── spell_card.dart
│           ├── spell_comparison_dialog.dart
│           ├── spell_filter_sheet.dart
│           └── spell_quick_roll_dialog.dart
├── scripts/
│   └── build_web.sh                # PWA web build script with cache-busting timestamp
├── test/                           # Unit, widget, accessibility, & resilience test suites (258+ tests)
│   ├── accessibility/              # Dynamic type text scaling (1.5x - 2.0x) & screen reader tests
│   ├── models/                     # Model tests, SRD IP legality audit, & 2014 vs 2024 rules tests
│   ├── screens/                    # Screen navigation, DM screen, Spellbook screen, & tool tests
│   ├── services/                   # Service tests, spellcasting rules engine, crash guards
│   ├── theme/                      # WCAG 2.1 AA color contrast compliance suite
│   └── widgets/                    # Component, dialog, glyph, and spell card widget tests
├── web/                            # Web platform manifest, strict CSP, & service worker
├── firestore.rules                 # Strict security rules for Firestore shared rooms
├── firestore.indexes.json          # Firestore indexes configuration
├── LEGAL_ATTRIBUTION_MODAL.md      # SRD 5.1 & 5.2 Creative Commons attribution & IP safeguards
├── PRIVACY_POLICY.md               # Data minimization & privacy policy
├── TERMS_OF_SERVICE.md             # Terms of service & EULA
├── pubspec.yaml                    # Flutter dependencies & metadata
├── LICENSE                         # MIT License file
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0.0 or higher)
* [Dart SDK](https://dart.dev/get-dart) (v3.0.0 or higher)

### 1. Clone the Repository
```bash
git clone https://github.com/YourUsername/dangerously_nerdy_5e_toolkit.git
cd dangerously_nerdy_5e_toolkit
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the Application

#### Web (Chrome / Edge)
```bash
flutter run -d chrome
```

#### Linux Desktop
```bash
flutter run -d linux
```

#### Mobile (Android / iOS)
Connect your device or start an emulator, then:
```bash
flutter run
```

---

## 🧪 Running Tests

To execute the automated unit, widget, accessibility, spellcasting mechanics, and resilience test suite (258+ tests with 100% pass rate):
```bash
flutter test
```

To run static analysis with zero warnings:
```bash
flutter analyze
```

---

## 🤖 AI Disclosure

This project was developed with the assistance of Artificial Intelligence tools. Specifically, **Google DeepMind's Antigravity / Gemini** models were utilized during the development lifecycle for:
- Architecture design, state management planning, and code refactoring.
- Implementation of batch attack algorithms, RAW 5e upcasting rules, spellcasting math matrices, and cryptographically secure RNG utilities.
- Writing comprehensive unit and widget tests.
- UI styling, 3D dice physics, responsive layout refinements, and documentation.

All AI-generated contributions were thoroughly audited, tested, verified, and refined by human developers to ensure high code quality, security, and accuracy to 5e RAW rules.

---

## 📄 License & Legal Notice

- **Software License**: Licensed under the **[MIT License](LICENSE)**.
- **SRD 5.1 & 5.2 Attribution**: Game mechanics derived from the System Reference Document 5.1 & 5.2 are used under the **[Creative Commons Attribution 4.0 International License (CC-BY-4.0)](LEGAL_ATTRIBUTION_MODAL.md)**.
- **Privacy Policy**: View our **[Privacy Policy](PRIVACY_POLICY.md)**.
- **Terms of Service**: View our **[Terms of Service](TERMS_OF_SERVICE.md)**.

