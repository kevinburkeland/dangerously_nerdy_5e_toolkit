# Accessibility (a11y) & UI Directives

All UI components in this repository must meet rigorous tabletop and mobile accessibility standards.

## 1. Touch Targets (Minimum 48x48dp)

- **Mandatory Size:** Every interactive button, icon button, tap target, and chip must have an effective hit testing area of at least **48x48 logical pixels**.
- Use Flutter's `minSize: const Size(48, 48)` on button styles or wrap custom gestures in `ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48))`.
- Interactive cards and list tiles must ensure internal clickable actions maintain 48dp spacing.

## 2. Screen Reader & Semantics

- Every icon-only button and custom interactive widget must be wrapped in a `Semantics` widget or provide a descriptive `tooltip`.
- **Expand Tabletop Abbreviations in Semantics Labels:**
  - "STR" -> "Strength"
  - "DEX" -> "Dexterity"
  - "CON" -> "Constitution"
  - "INT" -> "Intelligence"
  - "WIS" -> "Wisdom"
  - "CHA" -> "Charisma"
  - "AC" -> "Armor Class"
  - "HP" -> "Hit Points"
  - "DC" -> "Difficulty Class"
  - "GP" -> "Gold Pieces", "SP" -> "Silver Pieces", etc.
  - "RAW" -> "Rules As Written"
- Use `AccessibleActionTile` (`lib/presentation/core/accessible_action_tile.dart`) where appropriate for consistent narrative voice and accessibility announcements.

## 3. Dynamic Type & Text Scaling (Up to 2.0x)

- UI layouts must NOT throw `RenderFlex` overflow errors when tested under `TextScaler.linear(2.0)`.
- Use `Wrap`, `SingleChildScrollView`, `Flexible`, or `Expanded` instead of fixed-height rows/containers.
- Avoid hardcoded container heights around text elements; prefer padding and intrinsic layouts.

## 4. Reduced Motion & Performance

- Check `MediaQuery.disableAnimationsOf(context)` before triggering intensive particle effects, camera shakes, or 3D dice physics loops.
- Support OLED pitch black theme (`#000000`) and the 9 curated fantasy theme accent palettes in `lib/theme/app_theme.dart`.
- When rendering complex vector art or glyphs, use custom painters (`CustomPainter`) with cached paints to maintain 60/120Hz frame rates.
