<p align="center">
  <img src="web/icons/Icon-512.png" width="128" height="128" alt="DangerouslyNerdy 5e Toolkit Logo" />
</p>

# 🧙‍♂️ DangerouslyNerdy 5e Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![PWA Ready](https://img.shields.io/badge/PWA-Installable-5A0FC8?logo=pwa)](https://web.dev/progressive-web-apps/)
[![Tests](https://img.shields.io/badge/Tests-521%20Passing-brightgreen.svg)](test)
[![SRD 5.1 & 5.2](https://img.shields.io/badge/Rules-SRD%205.1%20%26%205.2%20CC--BY--4.0-blueviolet.svg)](LEGAL_ATTRIBUTION_MODAL.md)

A modern, high-performance Flutter application designed for 5th Edition (5e) tabletop RPG players and Game Masters. Features a suite of **core tabletop apps, campaign tools, and compendiums**, including a **Shared Party Vault & Campaign Hub**, a **Core Polyhedral Dice Roller** with interactive 3D physics and **Real-Time Multiplayer Dice Rooms**, a comprehensive **5e Spellbook Companion**, a dual-rulebook **DM's Screen with 2014 RAW vs 2024 Revised rules toggle**, a **Monster Codex & Bestiary Browser**, a **Magic Item Compendium**, advanced **DPR Calculators & Bezier Graph Visualizers**, an interactive **Monster Fighting Arena ("Tools for Nerds")** with Monte Carlo simulations, simultaneous **Batch Attack Rolling** for summoning spells and magic items, a **Techno-Rune Glyph Studio**, custom dice pool builders with JSON preset import/export, and a cryptographically secure random number generator.

---

## ✨ Key Features & Suite of Tools

### 🏰 1. Shared Party Vault, Campaign Rooms & Multi-Tier Sync
* **Multi-Campaign Hub**: Host or join persistent campaign rooms with 6-character alphanumeric room codes (`ROOM-XXXXXX`).
* **Passwordless DM Host Key Authority**: Cryptographic private host keys generated on room creation and stored securely in local device storage, providing Game Masters with administrative control (item restoration, conflict resolution) without requiring user accounts or third-party sign-ins.
* **Shared Party Vault & Magic Item Stash**:
  - Centralized inventory for weapons, armor, potions, rings, wands, and wondrous items.
  - **1-Tap Item Claiming & Attunement**: Players can claim items to their character personas and manage their 3-item attunement limit in real time.
  - **Soft Deletions & Trash Restoration**: Items deleted by players move to the **Vault Trash** and can be restored exclusively by the Campaign Host.
* **Personal Character Gold Stores & Party Reserve**:
  - Dedicated coin purses for each character in the active roster (`CP`, `SP`, `EP`, `GP`, `PP`).
  - **Shared Party Reserve**: Centralized treasury for shared party funds.
  - **Two-Way Coin Transfers**: Effortlessly transfer gold and currency between individual character purses and the shared party reserve.
  - **Auto-Sweep on Character Retirement**: Deleting a character automatically sweeps their remaining currency into the Party Reserve to prevent lost party wealth.
* **Treasure Hoard & Loot Roller Dispersal**:
  - 1-tap dispersal of generated treasure hoards to all active party members.
  - Optional **"A share for the party reserve"** checkbox to split loot evenly among $N$ characters plus the reserve fund.
  - Automatic liquidation of gems and art objects into GP shares with coin remainders cleanly deposited into the party reserve.
* **Active Character Personas & Roster Manager**:
  - Create and manage custom character personas (e.g. *"Gandalf (Wizard)"*, *"Frodo (Rogue)"*).
  - Quick-switch active session identities from the top status banner to attribute claims, rolls, and coin transactions accurately.
* **Multi-Tier Conflict & Race Resolution Engine**:
  - **Tier 1 (Additive Merging)**: Delta coin mutations via atomic `FieldValue.increment` and independent subcollection document writes.
  - **Tier 2 (Deterministic Last-Write-Wins Claims)**: Automatic claim race resolution if two disconnected players claim the same item offline; losing clients unbind smoothly and receive real-time notification toasts.
  - **Tier 3 (Host Diff & Structural Fork Dialog)**: Interactive visual diff modal (`LootConflictResolutionDialog`) allowing Game Masters to compare divergent Cloud vs Local versions side-by-side and choose *Use Cloud*, *Overwrite with Local*, or *Keep Both (Duplicate Item)*.
  - **Purse Overdraft Clamping**: Prevents negative coin balances by clamping overdrawn spends to zero and logging high-priority warning alerts.
* **Append-Only Audit Stream**: Live event log capturing coin deposits, withdrawals, loot additions, claims, attunements, and restorations.

---

### 🎲 2. Core Dice Roller & 3D Polyhedral Physics
* **Multi-Dice Pools**: Roll any combination of standard polyhedral RPG dice (`d4`, `d6`, `d8`, `d10`, `d12`, `d20`, `d100`) plus custom N-sided dice (`d3`, `d7`, `d30`, `d1000`, etc.).
* **Optimized 3D Polyhedral Visualizer**: Real-time 3D rendered dice rolling with realistic angular momentum, winning-face illumination, natural 20 critical burst particle effects, and screen shake. Powered by allocation-free rasterization loops and cached typography painters for 60/120Hz smoothness.
* **Roll Modes & Modifiers**: Apply flat positive/negative modifiers and toggle Advantage or Disadvantage.
* **Expandable Roll History**: Visual breakdown showing individual die results, dropped rolls, natural 20 / natural 1 highlights, formulas, and expandable roll detail feeds.
* **JSON Presets**: Save custom dice formulas (e.g., "Fireball 8d6", "Rogue Sneak Attack") and export/import JSON presets across devices.
* **Haptic Feedback**: Multi-level tactile vibration triggers (Off, Light Ticks, Heavy Combat Rumble) for dice clicks, roll animations, and critical successes.

### 🌐 3. Live Multiplayer Dice Rooms
* **Real-Time Synchronization**: Connect to shared dice rooms powered by Firebase Firestore for live party transparency.
* **6-Character Room Codes**: Simple 6-character alphanumeric room codes (`ROOM-XXXXXX`) with input sanitization and random code generation.
* **Live Connection Status**: Visual status banner indicating active room connection, participant display names, and real-time roll event feeds.
* **Ephemeral Architecture**: Stream-only roll broadcasts designed for privacy and minimal latency without permanent data harvesting.

---

### 📜 4. 5e Spellbook Companion & Rules Engine (2014 RAW vs 2024 Revised)
* **Modular Official SRD Spell Catalog**: Built-in support for official SRD spells across all tiers (Cantrips through 9th Level) with side-by-side 2014 & 2024 revision data.
* **Virtualized Viewport Architecture**: Full `CustomScrollView` and responsive `SliverList.builder` virtualization for fluid 60/120fps scrolling and instant search filtering across 100+ spells.
* **Pre-Computed Search Indexing**: Zero-allocation search caching for instant keystroke query matching across spell descriptions, tags, classes, and damage types.
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

---

### 🛡️ 5. DM's Screen & Dual Rulebook Engine (2014 RAW vs 2024 Revised)
* **2014 vs 2024 Rules Switch**: Seamlessly toggle between 2014 5e RAW rules and the 2024 Revised rules across all combat mechanics, conditions, environment hazards, DCs, resting, and spell limits.
* **Side-by-Side Edition Comparison**: Interactive comparison dialogs and "2024 Diff" badges highlighting every major rule revision (e.g., -2 Exhaustion per level, Unarmed Strike Save DCs, Bonus Action potions, and Disadvantage Initiative for surprise).
* **Virtualized Rule Grids**: Fluid sliver-based layout that lazily renders rule cards on demand for optimal mobile and desktop performance.
* **Rule Pinning & Search**: Pin frequently referenced rules to the top of your screen, with instant real-time keyword search and category filtering.
* **Quick DM Roller**: Instant d20, d100, d12, d8, and d6 roller bar directly inside the DM screen.

---

### 🐉 6. Monster Codex & Bestiary Browser (2014 vs 2024)
* **Comprehensive SRD Bestiary**: 320+ official monsters across all Challenge Ratings (CR 0 to CR 30), Creature Types, and Sizes.
* **2014 vs 2024 Monster Statblock Diffs**: Side-by-side comparison tool highlighting stat, trait, and multiattack changes in the revised ruleset.
* **Integrated Multiattack & Quick-Roll Engine**: Execute monster attacks, saving throw DCs, and damage rolls directly inside the statblock view.
* **My Bestiary Pinning**: Pin frequently encountered monsters for rapid encounter access.

---

### 🧰 7. Magic Item Compendium & Reliquary
* **Categorized Magic Items**: Comprehensive SRD 5.1 item library organized across Armor, Weapons, Potions, Rings, Rods, Scrolls, Staffs, Wands, and Wondrous Items.
* **Attunement & Rarity Filters**: Instant search and filtering by Common, Uncommon, Rare, Very Rare, Legendary, and Artifact rarities.
* **Direct Summon Launchers**: Integrated shortcuts to summon companions (e.g. *Bags of Tricks*, *Horn of Valhalla*, *Figurines of Wondrous Power*).
* **Personal Reliquary**: Bookmark favorite and attuned magic items for quick access during adventures.

---

### ⚔️ 8. Monster Fighting Arena & Monte Carlo Simulator (Tools for Nerds)
* **Turn-by-Turn Combat Simulation**: Pit custom teams of monsters against each other (e.g. *1 Young Red Dragon vs 4 Knights*, *1 Giant Shark vs 6 Mariners*, or *1 T-Rex vs 8 Wolves*) and watch every attack, save, crit, fumble, and killshot play out in real time.
* **Strict 5e Action Economy Resolution**:
  - **Accurate Action & Multiattack Sequencing**: Strict enforcement of action economy where monsters with melee and ranged options make only their permitted actions/multiattack routines per round rather than firing all weapon profiles simultaneously.
  - **Dynamic Initiative & Natural Crits**: Automatic D20 initiative sorting, tie-breaking by DEX mod and max HP, and natural 20 critical hit damage doubling.
  - **D6 Recharge Mechanics**: Evaluates recharge abilities (e.g., Dragon Fire Breath recharge on 5–6) at the start of each turn, consuming recharge readiness upon use.
  - **Dynamic AoE Target Scaling**: Breath weapons, cones, lines, and spheres hit a dynamic number of targets based on AoE footprint, prompting individual saving throws vs Save DC.
  - **Mobility & Evasion Rules**: Accounts for flight, swim, climb, burrow, Flyby, Pack Tactics, and the **5e Evasion trait** (0 damage on DEX save success, half on failure).
  - **Damage Resistances & Immunities**: Enforces resistances, vulnerabilities, and damage immunities.
* **🏟️ Environmental Battlegrounds**:
  - **Open Colosseum**: Standard open-air battlefield with full flight and standard rules.
  - **Iron Cage Match**: 10-ft enclosed ceiling that **grounds flying creatures** and disables aerial advantage.
  - **Flooded Abyss (Water Match)**: Submerged battlefield where **creatures with swim speed gain Advantage**, non-swimmers suffer Disadvantage, and fire damage is halved.
  - **Volcanic Caldera**: Extreme heat and molten terrain.
* **🎲 High-Speed Monte Carlo Simulation**: Run **500x or 1,000x automated match iterations** in milliseconds to compute exact empirical win rates %, average round durations, surviving fighter counts, remaining HP %, and identify Match MVPs.
* **⚡ Interactive Playback Controls**: Advance turns step-by-step, toggle auto-playback with adjustable speed (0.5x to 4x), or press **"Skip to End"** to instantly resolve the battle and view final statistics.

---

### 🤓 9. DPR Calculator & Multi-Mode Graph Visualizer (Tools for Nerds)
* **Interactive Animated Bezier Canvas**: Real-time damage per round (DPR) curve renderer with smooth Bezier interpolation, pulsing radar nodes, and touch/mouse scrubbing across target AC 8–25.
* **Dual 2014 RAW vs 2024 Revised Rules**: Toggle between 2014 feats (GWM -5/+10, GWF reroll 1s/2s) and 2024 rules (GWM +PB damage, GWF floor 3), or unlock **"Anything Goes"** mode to mix cross-edition feats and masteries.
* **GWM / Sharpshooter Break-Even Analysis**: Automatic calculation of the exact crossover armor class (AC) where power attack feats outperform normal strikes, highlighted by a golden beacon and diamond marker.
* **Multi-Curve Situational Triangle**:
  - **Baseline Strike (Cyan)**
  - **GWM / Power Attack (Amber)**
  - **Advantage & Elven Accuracy (Emerald Green)**
  - **Disadvantage Curve (Coral Crimson)**
* **3 Interactive Graph View Modes**:
  1. **DPR vs AC**: Primary damage output comparison across enemy armor tiers.
  2. **Accuracy %**: Hit Chance %, Advantage Hit %, Disadvantage Hit %, and Crit Rate % on a 0%–100% bounded accuracy scale.
  3. **Damage on Hit Breakdown**: Regular Hit Damage, Critical Hit Damage, and Miss / Graze Damage output per attack.
* **2024 Weapon Masteries**: Full offensive modeling for **Graze** (guaranteed ability mod damage on miss), **Vex** (chained advantage on hit), **Nick** (extra light weapon attack without bonus action), and **Topple**.
* **Cantrip & Spell Weapon Presets**: 20+ built-in damage actions including *Eldritch Blast* (with **Agonizing Blast** +Mod toggle), *Fire Bolt*, *Toll the Dead*, *Booming Blade*, *Green-Flame Blade*, *Shillelagh*, *Magic Stone*, and upcastable *Shadow Blade*.
* **Racial & Feat Perks**: Support for **Halfling Luck / Lucky** (rerolls natural 1s), Champion Fighter (19–20 Crit), Half-Orc / Barbarian (Extra Crit Dice), Sneak Attack once-per-turn probability math, and Dueling / Thrown Weapon fighting styles (+2 flat damage).

---

### 🔮 10. Spell Minion Companions (6 Dedicated Tools)
* **⚔️ Animate Objects Companion**: Enforces RAW point budgets (10 pts at 5th level up to 18 pts at 9th level) across Tiny, Small, Medium, Large, and Huge animated objects.
* **🐾 Conjure Animals Squad Manager**: Summons 8 Wolves (CR 1/4) at 3rd level up to 32 beasts at 9th level with built-in **Pack Tactics** advantage detection.
* **💀 Animate Dead Squad Tracker**: Manages Skeleton archers and Zombie frontline HP, tracking upcast limits from 1 to 13 undead.
* **🧟 Create Undead Manager**: Commands 3 Ghouls (6th level) up to 6 Ghouls, Ghasts, Wights, or Mummies at higher slot levels.
* **🌋 Conjure Elementals Companion**: Manages Air, Earth, Fire, and Water Elementals (CR 5+) and swarms of Mephits/Gargoyles.
* **🦗 Giant Insect Squad Tracker**: Transforms ordinary insects into Giant Centipedes (10), Giant Wasps (5), or Giant Spiders (3).

---

### 📯 11. Magic Item Rollers & Minions (5 Dedicated Tools)
* **👜 Gray Bag of Tricks**: Roll d8 on the Gray Bag table (Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, or Giant Elk).
* **👜 Rust Bag of Tricks**: Roll d8 on the Rust Bag table (Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, or Brown Bear).
* **👜 Tan Bag of Tricks**: Roll d8 on the Tan Bag table (Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, or Tiger).
* **📯 Horn of Valhalla Roller**: Roll variant Berserker squads for Silver (2d4+2), Brass (3d4+3), Bronze (4d4+4), and Iron (5d4+5) horns.
* **🗿 Figurines of Wondrous Power**: Animates Bronze Griffon, Onyx Dog (with Pack Tactics), and Marble Elephant statblocks with batch rolling.

---

### ⚔️ 12. Instant Batch Attack Roller & HP Tracker
* **Batch Attack Engine**: Roll attack and damage for up to 50 minions simultaneously against target AC with Advantage, Disadvantage, Normal rolling, and RAW Critical Hit doubling.
* **Live Squad HP Tracker**: Visual progress bars per minion, custom creature naming, temporary HP tracking, squad initiative rolling, quick +/- HP adjustments, direct HP input, and damage resistance markers.
* **Mass Damage & Group Healing**: AoE damage and healing modal to apply group HP changes across all minions or selected squads with full/half damage saving throw calculations.

---

### 🎨 13. D&D Techno-Rune Glyph Studio & Style Guide Codex
* **Interactive Custom Glyph Builder**: Select core glyph icons, choose outer and inner frame geometry (Hexagonal, Circular, Octagonal, Diamond), configure particle effects, and pick damage type rings.
* **Full Style Guide Codex**: Comprehensive design tokens covering typography, surface elevations, fantasy color palettes, and procedural vector glyphs.
* **Spellbook Schematics & Minion Matrix**: Visual reference cards with dynamic action cost rings (Action, Bonus Action, Reaction, Concentration, Ritual) and creature stat badges.

---

### 🎨 14. Theme Engine & User Preferences
* **Theme Modes**: System, Dark Mode (default), and Light Mode.
* **OLED Pitch Black**: Pure `#000000` background for AMOLED battery savings.
* **Fantasy Accent Palettes**: Choose between 9 rich RPG themes: `Paladin Gold`, `Eldritch Purple`, `Ranger Emerald`, `Necrotic Slate`, `Dragonfire Crimson`, `Arcane Sapphire`, `Bardic Rose`, `Abyssal Teal`, and `Celestial Amber`.
* **Micro-Interactions & Performance**: Fine-grained toggles for Critical Hit & Fumble Effects (screen shake, rumble, and ember bursts), Spell Particle Canvas FX, 3D Dice Overlays, and a Performance/Battery Saver mode.
* **Pure Flutter Vector Branding**: 100% vector-rendered tech+fantasy d20 logo (`AppLogo`) with `DN` center crest, curved `DANGEROUSLY NERDY` telemetry ring, and interactive hover/tap momentum spin physics.
* **Preferences Persistence**: Automatically saves user settings locally via `SharedPreferences`.

---

### 🔒 15. Cryptographically Secure RNG & Production Security
* Built using Dart's native `Random.secure()` (`lib/utils/secure_random.dart`) to ensure completely unbiased, cryptographically secure random distribution.
* **Strict Content Security Policy (CSP)** and production-hardened Firebase Firestore rules ensure robust client-side isolation and safe multi-user interactions.
* **Data Minimization**: Zero PII collection, no account registration required, and complete user data sovereignty.

---

### 📱 16. Progressive Web App (PWA) & Cross-Platform
* Fully responsive web application with offline PWA Service Worker caching (Network-First asset delivery) and native app installation prompt on desktop and mobile web.
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
│   │   ├── arena/                  # Monster Arena combatants, action results, & battlegrounds
│   │   ├── custom_preset.dart      # Custom dice pool preset data model
│   │   ├── dice_roll.dart          # Roll pool breakdown & calculation
│   │   ├── dm_screen_data.dart     # DM reference rules (2014 & 2024 comparison)
│   │   ├── dpr/                    # DPR calculation & combatant profile models
│   │   ├── landing_tool_item.dart  # Launcher tool definitions & categories
│   │   ├── magic_item.dart         # Magic item compendium models
│   │   ├── monster_codex_data.dart # Monster codex, statblocks, & 2014/2024 diffs
│   │   ├── party/                  # Campaign rooms, shared vault items, purses, & memberships
│   │   │   ├── campaign_membership.dart # Local role & hostKey persistence
│   │   │   ├── party_audit_event.dart   # Append-only audit stream events
│   │   │   ├── party_loot_item.dart     # Shared vault items with claims & attunement
│   │   │   ├── party_purse.dart         # 5-tier coin dictionary (cp, sp, ep, gp, pp)
│   │   │   └── party_session_state.dart # Campaign root document state
│   │   ├── room_roll.dart          # Live room multiplayer roll event
│   │   ├── spell_session.dart      # Spell session state, upcasting, & batch roller
│   │   ├── spellbook_data.dart     # SpellItem, editions, schools, and library indexing
│   │   ├── spells/                 # Modular official SRD spell catalogs
│   │   └── srd_summons/            # SRD 5.1 summon presets & statblocks
│   ├── providers/                  # State management providers
│   │   └── settings_provider.dart  # Reactive theme & settings provider
│   ├── screens/                    # Application screens
│   │   ├── arena_simulator_screen.dart # Monster Fighting Arena & Monte Carlo simulator
│   │   ├── dice_roller_screen.dart # Dice roller, 3D physics, presets, & multiplayer rooms
│   │   ├── dm_reference_screen.dart # DM's screen with 2014 vs 2024 rules comparison
│   │   ├── dpr_calculator_screen.dart # DPR calculator, multi-curve graph, & character builder
│   │   ├── glyph_showcase_screen.dart # Techno-Rune Glyph Studio, Codex & Style Guide
│   │   ├── item_compendium_screen.dart # Magic item compendium & rarity filters
│   │   ├── landing_screen.dart     # Categorized dashboard with dedicated tool cards
│   │   ├── minion_tool_screen.dart # Parametric dedicated minion tool screen
│   │   ├── monster_codex_screen.dart # Monster codex & 2014/2024 diff browser
│   │   ├── party_room_screen.dart  # Shared Campaign Vault, Coin Store, & Audit Log
│   │   ├── settings_screen.dart    # Theme, accent color, haptics, & 3D dice preferences
│   │   └── spellbook_screen.dart   # 5e Spellbook companion & rules reference screen
│   ├── services/                   # Data services & external integrations
│   │   ├── a11y_service.dart       # Accessibility & screen reader announcements
│   │   ├── base_room_service.dart  # Abstract interface for room syncing
│   │   ├── dice_room_service.dart  # Firebase Firestore real-time room sync
│   │   ├── haptic_service.dart     # Multi-platform tactile haptic feedback
│   │   ├── logging_service.dart    # Structured application logging
│   │   ├── party/                  # Party & Campaign Vault services
│   │   │   ├── campaign_registry_service.dart # Local multi-campaign membership storage
│   │   │   └── party_room_service.dart        # Multi-tier conflict resolution & vault sync
│   │   ├── preset_service.dart     # SharedPreferences & JSON import/export
│   │   └── rules/                  # 5e RAW rules, combat & spellcasting engines
│   │       ├── arena_combat_engine.dart # Monster arena battle simulator & Monte Carlo engine
│   │       ├── combat_rules_engine.dart # Attacks, saves, critical hits, damage
│   │       ├── dnd_5e_rules_engine.dart # Core ability modifiers & DC formulas
│   │       ├── dpr_calculator_engine.dart # Multi-edition DPR calculations & break-even math
│   │       └── spellcasting_rules_engine.dart # Scaling, multiclass matrix, pact magic
│   ├── theme/                      # Visual design system
│   │   └── app_theme.dart          # Dynamic theme data & color schemes
│   ├── utils/                      # Utilities & helpers
│   │   ├── crypto_utils.dart       # SHA-256 hostKey passkey hashing
│   │   ├── dice_formatters.dart    # Dice notation formatters & tokenizers
│   │   ├── pwa_helper.dart         # PWA installation prompt helper (cross-platform stub/web)
│   │   └── secure_random.dart      # Cryptographically secure RNG generator
│   └── widgets/                    # Modular UI components
│       ├── app_logo.dart           # Pure Flutter vector tech+fantasy d20 logo & interactive spin
│       ├── arena/                  # Arena clash stage, combatant cards, combat log, & Monte Carlo modal
│       ├── batch_attack/           # Batch attack results summary
│       ├── common/                 # Shared widgets & search headers
│       ├── dialogs/                # Modals for presets, batch attacks, legal notices, statblocks, & rules
│       ├── dice_roller/            # 3D dice visualizer, pool builders, roll history, & presets
│       ├── dm_reference/           # Dual-rulebook comparison cards, edition toggles, & diff badges
│       ├── dpr/                    # Animated Bezier canvas chart with multi-curve & mode support
│       ├── fx/                     # Critical hit visual effects & overlays
│       ├── glyphs/                 # Vector procedural school glyphs & token painters
│       ├── interactive/            # Interactive tactile cards & buttons
│       ├── item_compendium/        # Item cards, detail sheets, and filter modals
│       ├── meters/                 # Animated resource meters & HP bars
│       ├── minions/                # Active session header, object cards, & squad builder
│       ├── monster_codex/          # Monster cards, comparison dialogs, and roll modals
│       ├── party/                  # Campaign dialogs, loot conflict diff modal, & coin dispersers
│       │   ├── coin_transaction_dialog.dart       # Deposit / withdraw / transfer modal
│       │   ├── loot_conflict_resolution_dialog.dart # Visual Cloud vs Local Host Diff modal
│       │   ├── party_coin_dispersal_dialog.dart    # Gold & liquidated gem split calculator
│       │   ├── party_roster_dialog.dart            # Character management & session switcher
│       │   ├── party_share_dialog.dart             # Party coin split calculator
│       │   └── vault_item_dialog.dart              # Custom loot item creation modal
│       ├── room_banner_widget.dart # Live room connection status banner
│       ├── spell_reference.dart    # Spell reference cards & stat components
│       └── spellbook/              # Spell cards, quick-roll dialogs, compare modals, filter sheets
├── scripts/
│   └── build_web.sh                # PWA web build script with full icon font packaging & cache-busting
├── test/                           # Unit, widget, accessibility, & resilience test suites (521 tests)
├── web/                            # Web platform manifest, strict CSP, & network-first service worker
├── firestore.rules                 # Production-hardened security rules for Firestore campaigns
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
```bash
flutter run
```

---

## 🧪 Running Tests

To execute the automated unit, widget, accessibility, spellcasting mechanics, conflict resolution, and resilience test suite (**521 tests with 100% pass rate**):
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
- Implementation of multi-tier conflict resolution, batch attack algorithms, RAW 5e upcasting rules, spellcasting math matrices, DPR binomial calculations, and cryptographically secure RNG utilities.
- Writing comprehensive unit and widget tests.
- UI styling, 3D dice physics, responsive layout refinements, and documentation.

All AI-generated contributions were thoroughly audited, tested, verified, and refined by human developers to ensure high code quality, security, and accuracy to 5e RAW rules.

---

## 📄 License & Legal Notice

- **Software License**: Licensed under the **[MIT License](LICENSE)**.
- **SRD 5.1 & 5.2 Attribution**: Game mechanics derived from the System Reference Document 5.1 & 5.2 are used under the **[Creative Commons Attribution 4.0 International License (CC-BY-4.0)](LEGAL_ATTRIBUTION_MODAL.md)**.
- **Privacy Policy**: View our **[Privacy Policy](PRIVACY_POLICY.md)**.
- **Terms of Service**: View our **[Terms of Service](TERMS_OF_SERVICE.md)**.
