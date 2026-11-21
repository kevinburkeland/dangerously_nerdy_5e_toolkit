import 'package:material_ui/material_ui.dart';
import '../../../models/party/party_purse.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/party_room_service.dart';

class MemberCoinTransactionDialog extends StatefulWidget {
  final String roomCode;
  final String characterName;
  final String performedBy;
  final bool isDeposit;

  const MemberCoinTransactionDialog({
    super.key,
    required this.roomCode,
    required this.characterName,
    required this.performedBy,
    required this.isDeposit,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomCode,
    required String characterName,
    required String performedBy,
    required bool isDeposit,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MemberCoinTransactionDialog(
        roomCode: roomCode,
        characterName: characterName,
        performedBy: performedBy,
        isDeposit: isDeposit,
      ),
    );
  }

  @override
  State<MemberCoinTransactionDialog> createState() =>
      _MemberCoinTransactionDialogState();
}

class _MemberCoinTransactionDialogState
    extends State<MemberCoinTransactionDialog> {
  final _cpController = TextEditingController(text: '0');
  final _spController = TextEditingController(text: '0');
  final _epController = TextEditingController(text: '0');
  final _gpController = TextEditingController(text: '0');
  final _ppController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  final PartyRoomService _partyService = PartyRoomService();
  bool _isLoading = false;

  @override
  void dispose() {
    _cpController.dispose();
    _spController.dispose();
    _epController.dispose();
    _gpController.dispose();
    _ppController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cp = int.tryParse(_cpController.text.trim()) ?? 0;
    final sp = int.tryParse(_spController.text.trim()) ?? 0;
    final ep = int.tryParse(_epController.text.trim()) ?? 0;
    final gp = int.tryParse(_gpController.text.trim()) ?? 0;
    final pp = int.tryParse(_ppController.text.trim()) ?? 0;
    final note = _noteController.text.trim();

    if (cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      final session = await _partyService.streamSession(widget.roomCode).first;
      final currentPurse =
          session?.getMemberPurse(widget.characterName) ?? const PartyPurse.empty();

      final newPurse = widget.isDeposit
          ? currentPurse.depositCoins(
              cp: cp,
              sp: sp,
              ep: ep,
              gp: gp,
              pp: pp,
              replicaId: _partyService.replicaId,
            )
          : currentPurse.withdrawCoins(
              cp: cp,
              sp: sp,
              ep: ep,
              gp: gp,
              pp: pp,
              replicaId: _partyService.replicaId,
            );

      await _partyService.updateMemberPurse(
        roomCode: widget.roomCode,
        characterName: widget.characterName,
        newPurse: newPurse,
        performedBy: widget.performedBy,
        note: note.isNotEmpty
            ? note
            : (widget.isDeposit ? 'Deposit' : 'Withdrawal'),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isDeposit
                  ? 'Deposited coins to ${widget.characterName}\'s store'
                  : 'Withdrew coins from ${widget.characterName}\'s store',
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
              content: Text('Transaction failed: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isDeposit ? Icons.add_circle : Icons.remove_circle,
              color: isDeposit ? Colors.green : Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${isDeposit ? "Deposit to" : "Withdraw from"} ${widget.characterName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Reason / Note (Optional)',
                hintText: 'e.g. Bought potions, Tavern bill',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDeposit ? Colors.green.shade700 : Colors.amber.shade800,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: Text(isDeposit ? 'Deposit Coins' : 'Withdraw Coins'),
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

