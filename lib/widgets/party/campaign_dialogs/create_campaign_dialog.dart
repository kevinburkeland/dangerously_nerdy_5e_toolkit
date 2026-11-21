import 'package:material_ui/material_ui.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/party_room_service.dart';

/// Dialog to explicitly Create a New Campaign Room
class CreateCampaignDialog extends StatefulWidget {
  final Function(String roomCode)? onCreated;
  final String? linkProfileId;
  final String? initialCampaignName;

  const CreateCampaignDialog({
    super.key,
    this.onCreated,
    this.linkProfileId,
    this.initialCampaignName,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String roomCode)? onCreated,
    String? linkProfileId,
    String? initialCampaignName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CreateCampaignDialog(
        onCreated: onCreated,
        linkProfileId: linkProfileId,
        initialCampaignName: initialCampaignName,
      ),
    );
  }

  @override
  State<CreateCampaignDialog> createState() => _CreateCampaignDialogState();
}

class _CreateCampaignDialogState extends State<CreateCampaignDialog> {
  final _campaignController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void initState() {
    super.initState();
    if (widget.initialCampaignName != null &&
        widget.initialCampaignName!.isNotEmpty) {
      _campaignController.text = widget.initialCampaignName!;
    }
  }

  @override
  void dispose() {
    _campaignController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final campaignName = _campaignController.text.trim();
    final playerName = _nameController.text.trim();

    if (campaignName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a campaign name.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      final session = await _partyService.createCampaign(
        campaignName: campaignName,
        playerName: playerName.isEmpty ? 'DM' : playerName,
        linkProfileId: widget.linkProfileId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated?.call(session.roomCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Campaign "${session.campaignName}" created! Room Code: ${session.roomCode}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create campaign: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Create New Campaign',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a live campaign party vault and shared dice room. A secure 6-character room code and private DM passkey will be generated automatically.',
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _campaignController,
              autofocus: true,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Campaign / Party Name',
                hintText: 'e.g. Crown of the Dragon King, Vault of Winter',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Your DM / Display Name',
                hintText: 'e.g. Dungeon Master Kevin',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 18),
          label: const Text('Launch Campaign'),
        ),
      ],
    );
  }
}

/// Dialog to explicitly Join an Existing Campaign Room
