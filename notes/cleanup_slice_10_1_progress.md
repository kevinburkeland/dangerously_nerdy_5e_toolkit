# Cleanup slice 10.1 progress notes
Status: COMPLETE
Start heads: core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 857ac8e271b882885e5251a53bdc09ad20aa6ede
Last pushed heads (CI green): core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 51ee3f68243e27f508e69dc051e0e91b679bff1d
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4
Fix ids: 2.1 2.2 3.1 3.2 3.3 3.4 3.5 3.6 4.1 4.2 4.3 4.4 4.5 5.1 5.2 5.3 6.1 6.2 6.3 6.4 6.5 6.6

## Steps
- [x] Step 1 Retire cs10: app 7df7c8787daeb9a6490202146d290c83ae941c95 run 42313342876
- [x] Step 2 Two small fixes from the slice 10 review: app 3cf9945e7525d620bb5f0a6c7211fd138bd80da6 run 42315746680
- [x] Step 3 Combat actions carry data, not callbacks: app 3e04380d86e4ff14e65fb0031cb852f0759a8147 run 42319428544
- [x] Step 4 Colour and icon values, and the glyph token split: app 4b513a5ef6feda95c9600b9d60059be9a3439dcf run 42517789367
- [x] Step 5 Creatures and summons hold plain values: app 0a5b62c618e3623c7cc22031f5e95ccdf07c1680 run 42519569653
- [x] Step 6 The rest of models hold plain values: app 51ee3f68243e27f508e69dc051e0e91b679bff1d run 42731813465
- [x] Step 7 Mutations and report:
  - mutation/cs101-a1 cfd0c328f1c00de659d904a540f97287dbdb31b5
  - mutation/cs101-a2 4b1aa4d3df3dd98b1033d22edea4de39124bbbd2
  - mutation/cs101-r1 f86566f1d60f84ebe048ed52be3868ef872ef148
  - mutation/cs101-r2 b66821a1c4bc4f159fc9b3d1b89c5206c9d01ea1
  - mutation/cs101-g1 89f8fe3dd56688abb6609a9280aeb8ffd71ecd5e
  - mutation/cs101-g2 0e3aeb27b36eca0dcface1f2d7ea7bbadc497a8c
  - mutation/cs101-u1 e8a00e4e033ee9d3cface25aceb9b100952fc02f
  - mutation/cs101-u2 145e73effcacd9c1fe2eb59a58282fc0427f4819
  - mutation/cs101-m1 bdf3db41fd22fe8b6ae77dbff376a5fafe20ccc0
  - mutation/cs101-m2 457fa3568082cba092f80b7a09e1f0df598eb425
  - mutation/cs101-n1 0eedaa4bc670cd3fcc23f69ce4f9562d0389a988
  - mutation/cs101-n2 dc932373fd80ee84e235a0ed62b9ff62639a79a6

## Fix checklist
Fix 2.1 done: check_notes_shas.py verifies Fix checklist against Fix ids with NS23-NS31 self-tests in test_check_notes_shas.sh.
Fix 2.2 done: PartyRoomService.newInstance restored isolated DiceRoomService.newInstance default with isolation test and updated test setups.
Fix 3.1 done: Characterization test pinned Fighter, Bard, and Warlock combat action buttons, formulas, and slot recovery.
Fix 3.2 done: ActionRoll and ActionUse defined and CharacterCombatAction callback fields replaced with pure data.
Fix 3.3 done: CharacterActionsResolver converted to pure data roll expressions with all callback closures and UI imports removed.
Fix 3.4 done: Presentation combat action runner created with ARCHITECTURE.md and codebase map updated.
Fix 3.5 done: Character sheet tabs updated to dispatch via combat action runner with line count under ceiling.
Fix 3.6 done: Presentation boundary bars compliance test enforces Rules P1, P2, and P3 with controls.
Fix 4.1 done: UI value snapshot characterization test and fixture pin 1801 entries across models and glyph tokens.
Fix 4.2 done: Argb and AppIcon pure-Dart representation types in visual models with zero Flutter imports.
Fix 4.3 done: Presentation bridge visual_ui provides ArgbUi toColor and AppIconUi iconData with exhaustive switches.
Fix 4.4 done: Glyph tokens split into models glyph kinds and presentation glyph kinds UI restoring all original names via extensions.
Fix 4.5 done: Architecture documentation and codebase map updated for visual models and presentation visual folders.
Fix 5.1 done: Summons presets and minion stat block converted to Argb with Flutter imports removed.
Fix 5.2 done: Bestiary files and monster codex data converted to Argb and AppIcon with Flutter imports removed.
Fix 5.3 done: Layer import table allowlist updated removing flutter kind from all 15 files dropping allowlist to 27 files.
Fix 6.1 done: AppSettings converted to pure-Dart ThemeMode and Argb with Flutter imports removed and presentation UI extension created.
Fix 6.2 done: ArenaEnvironment colour and icon fields converted to Argb and AppIcon with presentation UI extension created.
Fix 6.3 done: SrdEquipmentPackage converted to AppIcon iconKey with presentation UI extension created.
Fix 6.4 done: TableCategory converted to Argb and AppIcon, SpellClass iconKey converted to AppIcon, and Flutter imports removed.
Fix 6.5 done: Glyph gallery and magic item models converted to Argb and AppIcon with Flutter imports removed.
Fix 6.6 done: Layer import table updated with zero Flutter imports in models enforced by dedicated test with control, allowlist reduced to 19 files.

## Red runs on main
None

## Next
None — Cleanup slice 10.1 is complete.

## Open issues and deviations
In DiceRoomService, removed visibleForTesting annotation from DiceRoomService.newInstance so PartyRoomService.newInstance can instantiate it without triggering analyzer warnings or requiring an ignore comment.
