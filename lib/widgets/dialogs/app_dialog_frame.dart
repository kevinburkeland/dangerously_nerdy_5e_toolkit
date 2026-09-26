import 'package:flutter/material.dart';

/// Design-token-aligned modal dialog shell providing consistent
/// title styling, typography, padding, rounded geometries, and action layouts.
class AppDialogFrame extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;

  const AppDialogFrame({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = iconColor ?? theme.colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: maxWidth,
        child: content,
      ),
      actions: actions,
    );
  }
}
