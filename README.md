# 🧙‍♂️ D&D 5e Animate Objects Spell Tracker (Flutter)

A modern, feature-rich Flutter application designed for Dungeons & Dragons 5th Edition players and DMs to easily track, manage, and batch-attack with animated objects under the *Animate Objects* spell (5th-level Transmutation).

---

## ✨ Features

- **⚡ Instant Batch Attack Roller**:
  - Roll attack and damage for up to 10+ animated objects simultaneously against target AC.
  - Supports Advantage, Disadvantage, and Normal rolling modes.
  - Automatically calculates total hits, natural 20 critical hits (doubling damage dice RAW), and total damage dealt.
  - Detailed roll breakdown per object instance.

- **📊 Live Squad Tracker & Health Management**:
  - Live HP tracking per object with progress bars and quick +/- HP buttons.
  - Support for customized object names (e.g. "Silver Coin #1", "Flying Greatsword", "Marble Statue").
  - Group AoE damage and group healing actions.

- **⚖️ Point Budget Enforcement (5e RAW)**:
  - Tracks spell budget (10 points at 5th level).
  - Size budget scaling: Tiny (1pt), Small (1pt), Medium (2pt), Large (4pt), Huge (8pt).
  - Upcasting support: Select spell slot level (5th through 9th level) to automatically expand point budget up to 18 points.

- **📖 Integrated 5e Spell Reference**:
  - Complete 5e RAW stat tables for all object sizes (HP, AC, Attack Bonus, Damage Formula, STR/DEX scores).
  - Tactical advice & RAW clarifications (Silvering weapons, maximum DPR builds, concentration).

---

## 🚀 Setup & Installation Guide for Ubuntu Linux (26.04)

### 1. Install Flutter SDK

#### Option A: Via Snap (Recommended on Ubuntu)
```bash
sudo snap install flutter --classic
```

#### Option B: Via Git / Manual Download
```bash
# Clone Flutter SDK into ~/development/flutter
mkdir -p ~/development
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter

# Add Flutter to your PATH (add this line to your ~/.bashrc)
export PATH="$PATH:$HOME/development/flutter/bin"
source ~/.bashrc
```

Verify installation:
```bash
flutter doctor
```

---

### 2. Install Android Studio & Android SDK

1. Install Android Studio via Snap or download from official developer site:
   ```bash
   sudo snap install android-studio --classic
   ```
2. Launch Android Studio, run the setup wizard, and install the **Android SDK**, **Android SDK Command-line Tools**, and **Flutter Plugin**.
3. Accept Android Licenses:
   ```bash
   flutter doctor --android-licenses
   ```

---

### 3. Open & Run the Project

#### In Antigravity / VS Code:
1. Open Antigravity and select **File -> Open Folder...** -> select `/home/kevin/Documents/animate_objects_5e`.
2. Open terminal in Antigravity (`Ctrl + ~`) and run:
   ```bash
   flutter pub get
   flutter run -d chrome    # Or flutter run -d linux
   ```

#### In Android Studio:
1. Launch Android Studio.
2. Click **Open** and select `/home/kevin/Documents/animate_objects_5e`.
3. Android Studio will recognize the `pubspec.yaml` and prompt to run `flutter pub get`.
4. Select target device (Android Emulator, Linux Desktop, or Web) and click **Run▶️**.

---

## 🛠 Project Structure

```
animate_objects_5e/
├── lib/
│   ├── main.dart                   # Main UI theme, tabs, & spell state
│   ├── models/
│   │   ├── animated_object.dart    # 5e stats (Tiny to Huge) & HP tracker
│   │   └── spell_session.dart      # Spell level, budget, & batch attack dice roller
│   └── widgets/
│       ├── object_card.dart        # Individual object HP & stat card
│       ├── batch_attack_dialog.dart# Group attack modal with dice roller
│       ├── squad_builder.dart      # Quick preset & budget builder
│       └── spell_reference.dart   # Interactive 5e spell rulebook
├── pubspec.yaml                    # Flutter dependencies & metadata
└── README.md
```
