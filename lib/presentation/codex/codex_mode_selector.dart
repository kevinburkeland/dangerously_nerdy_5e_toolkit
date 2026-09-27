import 'package:flutter/material.dart';
import 'codex_view_mode.dart';

/// Visual presentation style for [CodexModeSelector].
enum CodexModeSelectorStyle {
  /// Scrollable row of styled [FilterChip]s (default).
  chips,

  /// Material 3 [SegmentedButton] row.
  segmented,
}

/// Reusable horizontal view-mode selector for codex and compendium screens.
///
/// Renders a scrollable strip of mode chips or segmented buttons (such as
/// All / Bookmarks / 2024 Diffs / Homebrew) with active accenting and optional counts.
class CodexModeSelector<T> extends StatelessWidget {
  /// The view modes available in this selector.
  final List<CodexViewMode<T>> modes;

  /// The currently selected mode key.
  final T selectedMode;

  /// Callback invoked when a new mode is selected.
  final ValueChanged<T> onModeSelected;

  /// Default accent color when a mode does not specify its own.
  final Color? defaultAccentColor;

  /// Padding around the scrollable strip.
  final EdgeInsetsGeometry padding;

  /// Visual presentation style (chips or segmented).
  final CodexModeSelectorStyle style;

  const CodexModeSelector({
    super.key,
    required this.modes,
    required this.selectedMode,
    required this.onModeSelected,
    this.defaultAccentColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.style = CodexModeSelectorStyle.chips,
  });

  @override
  Widget build(BuildContext context) {
    if (style == CodexModeSelectorStyle.segmented) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            SegmentedButton<T>(
              segments: modes.map((mode) {
                final labelText = mode.count != null
                    ? '${mode.label} (${mode.count})'
                    : mode.label;
                return ButtonSegment<T>(
                  value: mode.key,
                  label: Text(labelText, style: const TextStyle(fontSize: 12)),
                  icon: Icon(mode.icon, size: 15),
                );
              }).toList(),
              selected: {selectedMode},
              onSelectionChanged: (val) {
                onModeSelected(val.first);
              },
            ),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((mode) {
          final isSelected = mode.key == selectedMode;
          final accent = mode.accentColor ??
              defaultAccentColor ??
              theme.colorScheme.primary;

          final Widget labelWidget;
          if (mode.count != null) {
            labelWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mode.label),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? accent.withValues(alpha: 0.4)
                            : accent.withValues(alpha: 0.2))
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${mode.count}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isDark ? Colors.white : accent)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          } else {
            labelWidget = Text(mode.label);
          }

          final semanticsLabel = mode.semanticsLabel ??
              (mode.count != null
                  ? '${mode.label}, ${mode.count} items'
                  : mode.label);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: isSelected,
              button: true,
              label: semanticsLabel,
              child: FilterChip(
                avatar: Icon(
                  mode.icon,
                  size: 16,
                  color: isSelected
                      ? (isDark ? Colors.white : accent)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: labelWidget,
                selected: isSelected,
                showCheckmark: false,
                selectedColor: isDark
                    ? accent.withValues(alpha: 0.3)
                    : accent.withValues(alpha: 0.15),
                side: BorderSide(
                  color: isSelected ? accent : theme.colorScheme.outlineVariant,
                  width: isSelected ? 1.4 : 1.0,
                ),
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.white : accent)
                      : theme.colorScheme.onSurface,
                  fontSize: 12.5,
                ),
                onSelected: (_) {
                  onModeSelected(mode.key);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
