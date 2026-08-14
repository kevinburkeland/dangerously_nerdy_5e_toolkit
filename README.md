# 🧙‍♂️ DangerouslyNerdy 5e Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![PWA Ready](https://img.shields.io/badge/PWA-Installable-5A0FC8?logo=pwa)](https://web.dev/progressive-web-apps/)

A modern, high-performance Flutter application designed for 5th Edition (5e) tabletop RPG players and Game Masters. Features a suite of **10 dedicated player tools**, including simultaneous batch attack rolling for 5e summoning spells and magic items, custom dice pool builders with JSON preset import/export, real-time multiplayer dice rooms, and a cryptographically secure random number generator.

---

## ✨ Key Features & Suite of Tools

### 🎲 1. Core Dice Roller & Live Multiplayer Rooms
* **Multi-Dice Pools**: Roll any combination of standard polyhedral RPG dice (`d4`, `d6`, `d8`, `d10`, `d12`, `d20`, `d100`) plus custom N-sided dice (`d3`, `d7`, `d30`, etc.).
* **Roll Modes & Modifiers**: Apply flat positive/negative modifiers and toggle Advantage or Disadvantage.
* **Detailed Breakdown**: Visual display showing individual die results, natural 20 / natural 1 highlights, and total sums.
* **JSON Presets**: Save custom dice pools (e.g., "Fireball 8d6", "Rogue Sneak Attack") and export/import JSON presets across devices.
* **Live Multiplayer Rooms**: Connect to shared dice rooms powered by Firebase Firestore for real-time party transparency.

### 🔮 2. Spell Minion Companions
* **⚔️ Animate Objects Companion**: Enforces RAW point budgets (10 pts at 5th level up to 18 pts at 9th level) across Tiny, Small, Medium, Large, and Huge animated objects.
* **🐾 Conjure Animals Squad Manager**: Summons 8 Wolves (CR 1/4) at 3rd level up to 32 beasts at 9th level with built-in **Pack Tactics** advantage detection and trip saves.
* **💀 Animate Dead Squad Tracker**: Manages Skeleton archers and Zombie frontline HP, tracking upcast limits from 1 to 13 undead.
* **🧟 Create Undead Manager**: Commands 3 Ghouls (6th level) up to 6 Ghouls, Ghasts, Wights, or Mummies at higher slot levels.
* **🌋 Conjure Elementals Companion**: Manages Air, Earth, Fire, and Water Elementals (CR 5+) and swarms of Mephits/Gargoyles.
* **🦗 Giant Insect Squad Tracker**: Transforms ordinary insects into Giant Centipedes (10), Giant Wasps (5), or Giant Spiders (3).

### 📯 3. Magic Item Rollers & Minions
* **👜 Bag of Tricks Roller**: Interactive puller randomly drawing animals from Gray, Rust, or Tan bags directly into your active squad.
* **📯 Horn of Valhalla Roller**: Roll variant Berserker squads for Silver (2d4+2), Brass (3d4+3), Bronze (4d4+4), and Iron (5d4+5) horns.
* **🗿 Figurines of Wondrous Power**: Animates Bronze Griffon, Onyx Dog (with Pack Tactics), and Marble Elephant statblocks with batch rolling.

### ⚔️ 4. Instant Batch Attack Roller & HP Tracker
* **Batch Attack Engine**: Roll attack and damage for up to 50 minions simultaneously against target AC with Advantage, Disadvantage, Normal rolling, and RAW Critical Hit doubling.
* **Live Squad HP Tracker**: Visual progress bars per minion, custom object naming, quick +/- HP adjustments, group AoE damage, and group healing.
* **Integrated SRD 5.1 Rulebook**: Interactive reference tables, stat cards, upcasting rules, and RAW tactical tips per tool.

### 🔒 5. Cryptographically Secure RNG
* Built using Dart's native `Random.secure()` (`lib/utils/secure_random.dart`) to ensure completely unbiased, cryptographically secure random distribution.

### 📱 6. Progressive Web App (PWA) & Cross-Platform
* Fully responsive web application with offline PWA Service Worker support and native app installation prompt on desktop and mobile web.

---

## 🛠 Project Structure

```
dangerously_nerdy_5e_toolkit/
├── assets/
│   └── images/                     # App logo and graphical assets
├── lib/
│   ├── main.dart                   # Entry point, navigation hub, & theme
│   ├── firebase_options.dart       # Firebase configuration initialization
│   ├── models/                     # Core data models
│   │   ├── animated_object.dart    # Minion statblocks, size rules, & HP tracker
│   │   ├── custom_preset.dart      # Custom dice pool preset data model
│   │   ├── dice_roll.dart          # Roll pool breakdown & calculation
│   │   ├── room_roll.dart          # Live room multiplayer roll event
│   │   ├── spell_session.dart      # Spell session state, upcasting, & batch roller
│   │   └── srd_summons/            # SRD 5.1 summon presets & statblocks
│   │       ├── magic_items/        # Bag of Tricks, Horn of Valhalla, Figurines
│   │       ├── spells/             # Animate Objects, Beasts, Undead, Elementals, Insects
│   │       └── srd_summons_library.dart # Preset catalog library
│   ├── screens/                    # Application screens
│   │   ├── animate_objects_screen.dart # Animate Objects tool wrapper
│   │   ├── dice_roller_screen.dart # Dice roller, presets, & multiplayer room
│   │   ├── landing_screen.dart     # Categorized dashboard with 10 dedicated tool cards
│   │   └── minion_tool_screen.dart # Parametric dedicated minion tool screen
│   ├── services/                   # Data services & external integrations
│   │   ├── base_room_service.dart  # Abstract interface for room syncing
│   │   ├── dice_room_service.dart  # Firebase Firestore real-time room sync
│   │   └── preset_service.dart     # SharedPreferences & JSON import/export
│   ├── utils/                      # Utilities & helpers
│   │   ├── pwa_helper.dart         # PWA installation prompt helper
│   │   └── secure_random.dart      # Cryptographically secure RNG generator
│   └── widgets/                    # Modular UI components
│       ├── animate_objects/        # Active session & squad cards
│       ├── batch_attack/          # Batch attack results summary
│       ├── dice_roller/            # Dice pool builders, roll history, & presets
│       ├── dialogs/                # Modals for presets, custom dice, & JSON IO
│       ├── batch_attack_dialog.dart# Batch attack modal
│       ├── object_card.dart        # Individual minion HP card
│       ├── room_banner_widget.dart # Live room connection status banner
│       ├── spell_reference.dart   # Interactive 5e spell rulebook table
│       └── squad_builder.dart      # Quick squad configuration builder
├── scripts/
│   └── build_web.sh                # PWA web build script
├── test/                           # Unit & widget test suites
│   ├── models/                     # Model tests & upcasting audit suite
│   ├── screens/                    # Screen navigation & tool tests
│   ├── services/                   # Service & preset tests
│   └── widgets/                    # Component & dialog widget tests
├── web/                            # Web platform manifest & service worker
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

To run the automated unit and widget test suite (75 tests):
```bash
flutter test
```

---

## 🤖 AI Disclosure

This project was developed with the assistance of Artificial Intelligence tools. Specifically, **Google DeepMind's Antigravity / Gemini** models were utilized during the development lifecycle for:
- Architecture design, state management planning, and code refactoring.
- Implementation of batch attack algorithms, RAW 5e upcasting rules, and cryptographically secure RNG utilities.
- Writing comprehensive unit and widget tests.
- UI styling, responsive layout refinements, and documentation.

All AI-generated contributions were thoroughly audited, tested, verified, and refined by human developers to ensure high code quality, security, and accuracy to 5e RAW rules.

---

## 📄 License

This project is open-source and licensed under the **[MIT License](LICENSE)**.
