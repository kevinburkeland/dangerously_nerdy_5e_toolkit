# Accessibility (a11y) & UI Directives

All UI components must satisfy strict tabletop usability, mobile responsiveness, and accessibility standards.

## 1. Touch Targets (Minimum 48x48dp)
- Every interactive button, icon button, tap target, chip, and dismissible control must have an effective hit testing area of at least **48x48 logical pixels**.
- Apply `minSize: const Size(48, 48)` on button styles or wrap custom gestures in `ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48))`.
- Interactive cards and list tiles must ensure internal clickable actions maintain at least 48dp spacing.

## 2. Screen Reader & Semantics
- Every icon-only button and custom interactive widget must be wrapped in `Semantics` or provide a descriptive `tooltip`.
- **Expand Tabletop Abbreviations in Semantics Labels:**
  - "STR" -> "Strength", "DEX" -> "Dexterity", "CON" -> "Constitution"
  - "INT" -> "Intelligence", "WIS" -> "Wisdom", "CHA" -> "Charisma"
  - "AC" -> "Armor Class", "HP" -> "Hit Points", "DC" -> "Difficulty Class"
  - "GP" -> "Gold Pieces", "SP" -> "Silver Pieces", "CP" -> "Copper Pieces"
  - "RAW" -> "Rules As Written", "PB" -> "Proficiency Bonus"
- Use `AccessibleActionTile` (`lib/presentation/core/accessible_action_tile.dart`) for narrative voice and accessibility announcements.

## 3. Dynamic Type & Responsive Layouts (Up to 2.0x)
- UI layouts must render cleanly without `RenderFlex` overflow errors when tested under `TextScaler.linear(2.0)`.
- Use `Wrap`, `SingleChildScrollView`, `Flexible`, or `Expanded` instead of fixed-height rows or containers around text.
- Badges and chip tags on cards must be wrapped in a responsive `Wrap` inside an `Expanded` column to prevent horizontal clipping on narrow displays (320-352px).

## 4. Universal Markdown & Tabular UI Rendering
- **Universal Formatted Markdown:** All compendium cards and detail views (`ItemCard`, `ItemDetailDialog`, `SpellCard`, `SpellComparisonDialog`, `CreatureStatBlockDialog`, `FeatCard`, `DmRuleCard`, `HomebrewStudioScreen`, `CharacterBuilderScreen`) must render descriptions and rules text via `FormattedMarkdownText`.
- **Horizontal Table Scrolling:** Tables must be enclosed in horizontal `SingleChildScrollView` with an interactive `Scrollbar`. `ScrollConfiguration` must include `PointerDeviceKind.mouse` alongside touch/stylus to support mouse drag-scrolling on desktop and web.
- **Card Edge Protection:** Cards containing tables must use `clipBehavior: Clip.antiAlias` to prevent table content from bleeding over rounded borders. Horizontal table dragging must NOT trigger parent card tap actions (`InkWell.onTap`).
- **Table Normalization:** `FormattedMarkdownText` isolates markdown tables with paragraph breaks and normalizes all rows to equal column lengths with empty cell padding, preventing framework table assertions.
- **Safe Truncation:** When card surfaces specify `maxLines` and `overflow: TextOverflow.ellipsis`, `FormattedMarkdownText` isolates block elements without throwing runtime layout exceptions.

## 5. Reduced Motion & Display Themes
- Wrap intensive particle effects, camera shakes, or 3D dice physics in `if (!MediaQuery.disableAnimationsOf(context))` checks.
- Support OLED pitch black theme (`#000000`) and the 9 fantasy theme accent palettes in `lib/theme/app_theme.dart`.
- Vector glyphs and custom canvas painters must cache `Paint` objects to sustain 60/120Hz frame rates.
