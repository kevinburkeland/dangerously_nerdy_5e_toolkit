import 'package:flutter/material.dart';

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
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.casino, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text(
              'Squad Initiative Roll',
              style: TextStyle(color: Colors.amber, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'd20 ($natRoll) ${dexMod >= 0 ? "+$dexMod" : "$dexMod"} DEX modifier',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Rolled for $minionName squad',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            icon: const Icon(Icons.refresh, color: Colors.black, size: 16),
            label: const Text(
              'Re-roll',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
