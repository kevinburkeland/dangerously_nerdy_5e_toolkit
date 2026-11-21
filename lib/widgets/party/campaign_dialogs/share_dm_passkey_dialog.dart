import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../models/party/campaign_membership.dart';
import '../../../services/haptic_service.dart';

class ShareDmPasskeyDialog extends StatelessWidget {
  final CampaignMembership membership;

  const ShareDmPasskeyDialog({super.key, required this.membership});

  static void show(BuildContext context, CampaignMembership membership) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ShareDmPasskeyDialog(membership: membership),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hostKey = membership.hostKey ?? '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.key, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('DM Passkey Delegation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this passwordless passkey with a Co-DM or secondary device to grant administrative rights (rehydrating dormant campaigns, restoring trash items, and resetting party funds).',
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Room Code:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(
              membership.roomCode,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('DM passkey:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amber.shade400.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                hostKey,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(
                text: 'Room: ${membership.roomCode}\nHostKey: $hostKey'));
            HapticService.lightImpact(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('DM Passkey copied to clipboard!')),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 6),
              Text('Copy Passkey'),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Dialog to Enter a DM Passkey / Host Key to Claim DM or Co-DM Rights
