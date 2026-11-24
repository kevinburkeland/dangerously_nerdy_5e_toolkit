import 'package:material_ui/material_ui.dart';

import '../../models/party/campaign_membership.dart';
import '../../services/party/party_room_service.dart';

Future<void> showConfirmLeaveCampaignDialog({
  required BuildContext context,
  required String campaignName,
  required String roomCode,
  required String playerName,
  required PartyRoomService partyService,
}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Leave Campaign'),
          ],
        ),
        content: Text(
          'Are you sure you want to leave "$campaignName" ($roomCode)?\n\n'
          'Your active player status and local campaign link will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave Campaign'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await partyService.leaveCampaign(
          roomCode: roomCode,
          playerName: playerName,
        );
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left campaign "$campaignName"')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error leaving campaign: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

Future<void> showConfirmDeleteCampaignDialog({
  required BuildContext context,
  required String campaignName,
  required String roomCode,
  required CampaignMembership? currentMembership,
  required PartyRoomService partyService,
}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Campaign'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$campaignName" ($roomCode)?\n\n'
          'This will delete the room, party loot, and all cloud records for all participants. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await partyService.deleteCampaign(
          roomCode: roomCode,
          hostKey: currentMembership?.hostKey,
        );
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Campaign "$campaignName" permanently deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error deleting campaign: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }
