# 🧙‍♂️ DangerouslyNerdy 5e Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![PWA Ready](https://img.shields.io/badge/PWA-Installable-5A0FC8?logo=pwa)](https://web.dev/progressive-web-apps/)

A modern, high-performance Flutter application designed for Dungeons & Dragons 5th Edition players and Dungeon Masters. Features simultaneous batch attack rolling for *Animate Objects*, custom dice pool builders with JSON preset import/export, real-time multiplayer dice rooms, and a cryptographically secure random number generator.

---

## ✨ Key Features

### ⚔️ 1. Animate Objects Companion & Squad Manager
* **RAW 5e Point Budget Enforcement**: Automatically tracks spell slot level (5th through 9th level) and scales point budget from 10 to 18 points. Enforces size scaling rules RAW:
  * **Tiny**: 1 pt | HP 20 | AC 18 | +8 to hit | 1d4+4 dmg
  * **Small**: 1 pt | HP 10 | AC 16 | +6 to hit | 1d8+2 dmg
  * **Medium**: 2 pts | HP 40 | AC 13 | +5 to hit | 1d10+1 dmg
  * **Large**: 4 pts | HP 50 | AC 10 | +6 to hit | 2d6+2 dmg
  * **Huge**: 8 pts | HP 80 | AC 10 | +8 to hit | 2d12+4 dmg
* **Instant Batch Attack Roller**: Roll attack and damage for up to 10+ animated objects simultaneously against target AC with support for Advantage, Disadvantage, and Normal rolling.
* **RAW Critical Hit Calculation**: Automatically detects Natural 20s and doubles damage dice per RAW 5e rules.
* **Live Squad HP Tracker**: Visual progress bars per object with custom object naming (e.g., "Silver Dagger #1", "Marble Statue"), quick +/- HP adjustments, group AoE damage, and group healing.
* **Squad Presets**: Save and load custom squad setups instantly.
* **Integrated 5e Rulebook**: Built-in reference tables, stat cards, silvering rules, DPR analysis, and tactical tips.

### 🎲 2. Advanced Dice Roller & Pool Builder
* **Multi-Dice Pools**: Roll any combination of standard D&D dice (`d4`, `d6`, `d8`, `d10`, `d12`, `d20`, `d100`) plus custom N-sided dice (`d3`, `d7`, `d30`, etc.).
* **Roll Modes & Flat Modifiers**: Apply flat positive/negative modifiers and toggle Advantage or Disadvantage.
* **Detailed Breakdown**: Visual display showing each individual die result, natural 20 / natural 1 highlights, and total sum.
* **Roll History**: Persistent history logging previous rolls.

### 💾 3. Custom Dice Presets & JSON Sharing
* **Preset Library**: Create, name, save, and manage frequent dice pools (e.g., "Fireball 8d6", "Rogue Sneak Attack").
* **JSON Export & Import**: Backup your custom presets to JSON or share preset files across devices and with party members.

### 🌐 4. Live Multiplayer Dice Rooms
* **Real-Time Sync**: Connect to shared dice rooms powered by Firebase Firestore.
* **Party Transparency**: View rolls live as party members or DMs roll in the shared room.

### 🔒 5. Cryptographically Secure RNG
* Built using Dart's native `Random.secure()` (`lib/utils/secure_random.dart`) to ensure completely unbiased, cryptographically secure random distribution for all dice rolls.

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
│   │   ├── animated_object.dart    # 5e stats, budget rules, & HP tracker
│   │   ├── custom_preset.dart      # Custom dice pool preset data model
│   │   ├── dice_roll.dart          # Roll pool breakdown & calculation
│   │   ├── room_roll.dart          # Live room multiplayer roll event
│   │   └── spell_session.dart      # Spell session state & batch roller
│   ├── screens/                    # Application screens
│   │   ├── animate_objects_screen.dart # Animate Objects tracker & squad manager
│   │   ├── dice_roller_screen.dart # Dice roller, presets, & multiplayer room
│   │   └── landing_screen.dart     # Central feature dashboard
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
│       ├── object_card.dart        # Individual animated object HP card
│       ├── room_banner_widget.dart # Live room connection status banner
│       ├── spell_reference.dart   # Interactive 5e spell rulebook table
│       └── squad_builder.dart      # Quick squad configuration builder
├── scripts/
│   └── build_web.sh                # PWA web build script
├── test/                           # Unit & widget test suites
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

To run the automated unit and widget test suite:
```bash
flutter test
```

---

## 🤖 AI Disclosure

This project was developed with the assistance of Artificial Intelligence tools. Specifically, **Google DeepMind's Antigravity / Gemini** models were utilized during the development lifecycle for:
- Architecture design, state management planning, and code refactoring.
- Implementation of batch attack algorithms, RAW 5e rule validation, and cryptographically secure RNG utilities.
- Writing unit and widget tests.
- UI styling, responsive layout refinements, and documentation.

All AI-generated contributions were thoroughly audited, tested, verified, and refined by human developers to ensure high code quality, security, and accuracy to 5e RAW rules.

---

## 📄 License

This project is open-source and licensed under the **[MIT License](LICENSE)**.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies.
