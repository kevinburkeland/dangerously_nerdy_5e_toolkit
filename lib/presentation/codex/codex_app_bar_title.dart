import 'package:flutter/material.dart';
import 'codex_header_config.dart';

/// Reusable AppBar title widget for codex screens.
///
/// Consistently renders the icon/glyph, screen title, and dynamic count badge
/// with full accessibility semantics and 2.0x dynamic type scaling tolerance.
class CodexAppBarTitle extends StatelessWidget {
  final CodexHeaderConfig config;

  const CodexAppBarTitle({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = config.accentColor ?? theme.colorScheme.primary;

    final Widget leadingIcon;
    if (config.iconWidget != null) {
      leadingIcon = config.iconWidget!;
    } else if (config.icon != null) {
      leadingIcon = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Icon(config.icon, size: 16, color: accent),
      );
    } else {
      leadingIcon = const SizedBox.shrink();
    }

    final fullSemanticsLabel = config.semanticsLabel ??
        (config.visibleCount != null
            ? '${config.title}, ${config.visibleCount} items'
            : config.title);

    return Semantics(
      header: true,
      label: fullSemanticsLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.icon != null || config.iconWidget != null) ...[
            leadingIcon,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              config.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          if (config.visibleCount != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${config.visibleCount}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
