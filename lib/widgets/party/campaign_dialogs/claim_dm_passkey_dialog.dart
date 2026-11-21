import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../models/party/campaign_membership.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/party_room_service.dart';
import '../../../utils/crypto_utils.dart';

class ClaimDmPasskeyDialog extends StatefulWidget {
  final String? initialRoomCode;
  final String? initialPlayerName;
  final Function(CampaignMembership membership)? onClaimed;
  final Function(CampaignMembership membership)? onImported;

  const ClaimDmPasskeyDialog({
    super.key,
    this.initialRoomCode,
    this.initialPlayerName,
    this.onClaimed,
    this.onImported,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialRoomCode,
    String? initialPlayerName,
    Function(CampaignMembership)? onClaimed,
    Function(CampaignMembership)? onImported,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ClaimDmPasskeyDialog(
        initialRoomCode: initialRoomCode,
        initialPlayerName: initialPlayerName,
        onClaimed: onClaimed ?? onImported,
      ),
    );
  }

  @override
  State<ClaimDmPasskeyDialog> createState() => _ClaimDmPasskeyDialogState();
}

/// Backward-compatible alias for ClaimDmPasskeyDialog
typedef ImportDmPasskeyDialog = ClaimDmPasskeyDialog;

class _ClaimDmPasskeyDialogState extends State<ClaimDmPasskeyDialog> {
  late final TextEditingController _roomController;
  late final TextEditingController _nameController;
  final _passkeyController = TextEditingController();
  CampaignRole _selectedRole = CampaignRole.host;
  bool _isLoading = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: widget.initialRoomCode ?? '');
    _nameController =
        TextEditingController(text: widget.initialPlayerName ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    _passkeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;

    final extractedKey = CryptoUtils.extractHostKey(text);
    if (extractedKey.isNotEmpty) {
      _passkeyController.text = extractedKey;
    } else {
      _passkeyController.text = text.trim();
    }

    final roomMatch = RegExp(r'Room\s*:\s*([^\s\n\r]+)', caseSensitive: false)
        .firstMatch(text);
    if (roomMatch != null && _roomController.text.trim().isEmpty) {
      _roomController.text = roomMatch.group(1)!.trim().toUpperCase();
    }

    if (mounted) {
      HapticService.selectionTick(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('DM Passkey pasted from clipboard!'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _submit() async {
    final roomCode = _roomController.text.trim().toUpperCase();
    final passkey = _passkeyController.text.trim();
    final playerName = _nameController.text.trim();

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code.')),
      );
      return;
    }

    if (passkey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the DM passkey.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      final membership = await _partyService.claimDmRole(
        roomCode: roomCode,
        hostKeyOrPasskey: passkey,
        targetRole: _selectedRole,
        playerName: playerName.isNotEmpty ? playerName : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onClaimed?.call(membership);
        widget.onImported?.call(membership);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedRole == CampaignRole.host ? "Dungeon Master" : "Co-DM"} privileges activated for "${membership.campaignName}" (${membership.roomCode})!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } on UnauthorizedHostActionException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on CampaignNotFoundException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
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
          Icon(Icons.vpn_key, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('Claim DM / Co-DM Status',
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
              'Enter the private DM passkey or host key provided by the campaign creator to unlock administrative authority (restoring deleted loot, resetting party funds, resolving cloud sync conflicts, and delegating passkeys).',
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              autofocus: widget.initialRoomCode == null ||
                  widget.initialRoomCode!.isEmpty,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'e.g. ROOM-A1B2C3',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passkeyController,
              autofocus: widget.initialRoomCode != null &&
                  widget.initialRoomCode!.isNotEmpty,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'DM Passkey / Host Key',
                hintText: 'Paste DM passkey (host key)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your DM / Display Name (Optional)',
                hintText: 'e.g. Dungeon Master Kevin',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Role: ',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('DM / Host'),
                  selected: _selectedRole == CampaignRole.host,
                  onSelected: (selected) {
                    if (selected)
                      setState(() => _selectedRole = CampaignRole.host);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Co-DM'),
                  selected: _selectedRole == CampaignRole.coDm,
                  onSelected: (selected) {
                    if (selected)
                      setState(() => _selectedRole = CampaignRole.coDm);
                  },
                ),
              ],
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
              : const Icon(Icons.vpn_key, size: 18),
          label: const Text('Claim DM Role'),
        ),
      ],
    );
  }
}

/// Dialog to Add a Custom Loot Item to the Vault
