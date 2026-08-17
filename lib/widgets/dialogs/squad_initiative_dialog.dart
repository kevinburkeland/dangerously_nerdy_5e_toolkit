import 'package:flutter/material.dart';
import 'app_dialog_frame.dart';

/// Dialog displaying a squad initiative roll result with a re-roll action.
class SquadInitiativeDialog {
  static Future<void> show(
    BuildContext context, {
    required int total,
    required int natRoll,
    required int dexMod,
    required String minionName,
    required VoidCallback onReroll,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialogFrame(
        icon: Icons.casino,
        iconColor: primary,
        title: 'Squad Initiative Roll',
        maxWidth: 320,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: TextStyle(
                color: primary,
                fontSize: 54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'd20 ($natRoll) ${dexMod >= 0 ? "+$dexMod" : "$dexMod"} DEX modifier',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Rolled for $minionName squad',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text(
              'Re-roll',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onReroll();
            },
          ),
        ],
      ),
    );
  }
}

