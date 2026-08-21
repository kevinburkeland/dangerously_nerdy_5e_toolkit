import 'package:flutter/material.dart';

/// Reusable numeric stepper component for parameter adjustments (+/-).
class NumericStepper extends StatelessWidget {
  final String? label;
  final int value;
  final int? min;
  final int? max;
  final int step;
  final String? display;
  final String Function(int value)? displayFormat;
  final ValueChanged<int> onChanged;
  final bool compact;
  final double? width;

  const NumericStepper({
    super.key,
    this.label,
    required this.value,
    this.min,
    this.max,
    this.step = 1,
    this.display,
    this.displayFormat,
    required this.onChanged,
    this.compact = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textToShow = display ?? (displayFormat != null ? displayFormat!(value) : '$value');

    final canDecrement = min == null || (value - step) >= min!;
    final canIncrement = max == null || (value + step) <= max!;

    final content = Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2 : 3,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: canDecrement ? () => onChanged(value - step) : null,
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.remove,
                size: compact ? 12 : 14,
                color: canDecrement
                    ? theme.colorScheme.onSurface
                    : theme.disabledColor,
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  textToShow,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: canIncrement ? () => onChanged(value + step) : null,
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.add,
                size: compact ? 12 : 14,
                color: canIncrement
                    ? theme.colorScheme.onSurface
                    : theme.disabledColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (label == null) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        content,
      ],
    );
  }
}
