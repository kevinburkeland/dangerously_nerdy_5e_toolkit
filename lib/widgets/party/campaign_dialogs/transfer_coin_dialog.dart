import 'package:material_ui/material_ui.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/party_room_service.dart';

/// Dialog to Transfer Coins between Personal Store and Party Reserve
class TransferCoinDialog extends StatefulWidget {
  final String roomCode;
  final String characterName;
  final String performedBy;
  final bool toReserve;

  const TransferCoinDialog({
    super.key,
    required this.roomCode,
    required this.characterName,
    required this.performedBy,
    required this.toReserve,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomCode,
    required String characterName,
    required String performedBy,
    required bool toReserve,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TransferCoinDialog(
        roomCode: roomCode,
        characterName: characterName,
        performedBy: performedBy,
        toReserve: toReserve,
      ),
    );
  }

  @override
  State<TransferCoinDialog> createState() => _TransferCoinDialogState();
}

class _TransferCoinDialogState extends State<TransferCoinDialog> {
  final _cpController = TextEditingController(text: '0');
  final _spController = TextEditingController(text: '0');
  final _epController = TextEditingController(text: '0');
  final _gpController = TextEditingController(text: '0');
  final _ppController = TextEditingController(text: '0');
  final PartyRoomService _partyService = PartyRoomService();
  bool _isLoading = false;

  @override
  void dispose() {
    _cpController.dispose();
    _spController.dispose();
    _epController.dispose();
    _gpController.dispose();
    _ppController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cp = int.tryParse(_cpController.text.trim()) ?? 0;
    final sp = int.tryParse(_spController.text.trim()) ?? 0;
    final ep = int.tryParse(_epController.text.trim()) ?? 0;
    final gp = int.tryParse(_gpController.text.trim()) ?? 0;
    final pp = int.tryParse(_ppController.text.trim()) ?? 0;

    if (cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      if (widget.toReserve) {
        await _partyService.transferMemberToReserve(
          roomCode: widget.roomCode,
          characterName: widget.characterName,
          performedBy: widget.performedBy,
          cp: cp,
          sp: sp,
          ep: ep,
          gp: gp,
          pp: pp,
        );
      } else {
        await _partyService.transferReserveToMember(
          roomCode: widget.roomCode,
          characterName: widget.characterName,
          performedBy: widget.performedBy,
          cp: cp,
          sp: sp,
          ep: ep,
          gp: gp,
          pp: pp,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.toReserve
                  ? 'Transferred coins from ${widget.characterName} to Party Reserve'
                  : 'Transferred coins from Party Reserve to ${widget.characterName}',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Transfer failed: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.sync_alt, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.toReserve
                  ? 'Transfer to Party Reserve'
                  : 'Withdraw from Party Reserve',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.toReserve
                  ? 'Move personal coins from ${widget.characterName} into the shared party vault.'
                  : 'Move funds from the shared party reserve into ${widget.characterName}\'s pouch.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField('Platinum (PP)', _ppController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Gold (GP)', _gpController)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildField('Electrum (EP)', _epController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Silver (SP)', _spController)),
              ],
            ),
            const SizedBox(height: 8),
            _buildField('Copper (CP)', _cpController),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: const Text('Confirm Transfer'),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}

