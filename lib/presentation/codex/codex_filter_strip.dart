import 'package:flutter/material.dart';

/// Single option model within a [CodexFilterStrip].
@immutable
class CodexFilterOption<T> {
  /// The value associated with this filter option.
  final T value;

  /// Display text for the filter chip.
  final String label;

  /// Optional icon displayed at the start of the chip.
  final IconData? icon;

  /// Optional item count associated with this filter.
  final int? count;

  /// Optional screen reader label.
  final String? semanticsLabel;

  const CodexFilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.semanticsLabel,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodexFilterOption<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          label == other.label &&
          icon == other.icon &&
          count == other.count &&
          semanticsLabel == other.semanticsLabel;

  @override
  int get hashCode => Object.hash(value, label, icon, count, semanticsLabel);
}

/// Generic, single-selection horizontal FilterChip strip for secondary filtering
/// across codex and compendium screens (e.g. Roles, Categories, Size, CR Bands).
class CodexFilterStrip<T> extends StatelessWidget {
  /// Available filter options.
  final List<CodexFilterOption<T>> options;

  /// Currently selected value.
  final T? selectedValue;

  /// Callback when a filter option is selected.
  final ValueChanged<T> onSelected;

  /// Optional callback invoked when the active option is tapped again to deselect it.
  /// If null, tapping an active chip re-invokes [onSelected] with the option's value.
  final VoidCallback? onDeselected;

  /// Padding around the scrollable strip.
  final EdgeInsetsGeometry padding;

  /// Visual density of the chips (default: [VisualDensity.compact]).
  final VisualDensity visualDensity;

  /// Optional accent color override for the selected state.
  final Color? activeColor;

  const CodexFilterStrip({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.onDeselected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.visualDensity = VisualDensity.compact,
    this.activeColor,
  });

  /// Factory for deselectable / optional filter strips where deselection emits null.
  ///
  /// When tapping an already selected chip, [onSelected] is invoked with null.
  factory CodexFilterStrip.optional({
    Key? key,
    required List<CodexFilterOption<T>> options,
    required T? selectedValue,
    required ValueChanged<T?> onSelected,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    VisualDensity visualDensity = VisualDensity.compact,
    Color? activeColor,
  }) {
    return CodexFilterStrip<T>(
      key: key,
      options: options,
      selectedValue: selectedValue,
      onSelected: (val) => onSelected(val),
      onDeselected: () => onSelected(null),
      padding: padding,
      visualDensity: visualDensity,
      activeColor: activeColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option.value == selectedValue;

          final Widget labelWidget;
          if (option.count != null) {
            labelWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(option.label),
                const SizedBox(width: 4),
                Text(
                  '(${option.count})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
              ],
            );
          } else {
            labelWidget = Text(option.label);
          }

          final semanticsLabel = option.semanticsLabel ??
              (option.count != null
                  ? '${option.label}, ${option.count} available'
                  : option.label);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              selected: isSelected,
              button: true,
              label: semanticsLabel,
              child: FilterChip(
                avatar: option.icon != null
                    ? Icon(option.icon, size: 14)
                    : null,
                label: labelWidget,
                selected: isSelected,
                selectedColor: activeColor,
                visualDensity: visualDensity,
                onSelected: (_) {
                  if (isSelected && onDeselected != null) {
                    onDeselected!();
                  } else {
                    onSelected(option.value);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
