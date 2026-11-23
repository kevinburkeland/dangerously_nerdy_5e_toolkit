import 'package:material_ui/material_ui.dart';
import '../../../services/party/party_room_service.dart';

/// Dialog for Quick Coin Deposit & Withdrawal
class CoinTransactionDialog extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isDeposit;

  const CoinTransactionDialog({
    super.key,
    required this.roomCode,
    required this.playerName,
    this.isDeposit = true,
  });

  static Future<void> show(BuildContext context,
      {required String roomCode,
      required String playerName,
      bool isDeposit = true}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CoinTransactionDialog(
          roomCode: roomCode, playerName: playerName, isDeposit: isDeposit),
    );
  }

  @override
  State<CoinTransactionDialog> createState() => _CoinTransactionDialogState();
}

class _CoinTransactionDialogState extends State<CoinTransactionDialog> {
  final _cp = TextEditingController(text: '0');
  final _sp = TextEditingController(text: '0');
  final _ep = TextEditingController(text: '0');
  final _gp = TextEditingController(text: '0');
  final _pp = TextEditingController(text: '0');
  final _note = TextEditingController();
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void dispose() {
    _cp.dispose();
    _sp.dispose();
    _ep.dispose();
    _gp.dispose();
    _pp.dispose();
    _note.dispose();
    super.dispose();
  }

  void _addQuickGp(int amount) {
    final current = int.tryParse(_gp.text) ?? 0;
    _gp.text = (current + amount).toString();
    setState(() {});
  }

  void _submit() {
    final cp = int.tryParse(_cp.text) ?? 0;
    final sp = int.tryParse(_sp.text) ?? 0;
    final ep = int.tryParse(_ep.text) ?? 0;
    final gp = int.tryParse(_gp.text) ?? 0;
    final pp = int.tryParse(_pp.text) ?? 0;
    final note = _note.text.trim();

    if (cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0) {
      Navigator.pop(context);
      return;
    }

    if (widget.isDeposit) {
      _partyService.depositCoins(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        note: note.isNotEmpty ? note : null,
      );
    } else {
      _partyService.withdrawCoins(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        note: note.isNotEmpty ? note : null,
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;
    final color = isDeposit ? Colors.green : Colors.amber.shade800;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(isDeposit ? 'Deposit Coins' : 'Withdraw Coins',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Add Gold (GP):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                    label: const Text('+10 GP'),
                    onPressed: () => _addQuickGp(10)),
                ActionChip(
                    label: const Text('+50 GP'),
                    onPressed: () => _addQuickGp(50)),
                ActionChip(
                    label: const Text('+100 GP'),
                    onPressed: () => _addQuickGp(100)),
                ActionChip(
                    label: const Text('+500 GP'),
                    onPressed: () => _addQuickGp(500)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _pp,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'PP (Plat)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _gp,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'GP (Gold)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _ep,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'EP (Elec)'))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _sp,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'SP (Silv)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _cp,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'CP (Copp)'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Transaction Note / Source',
                  hintText: 'e.g. Goblin Lair chest'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: _submit,
            child: Text(isDeposit ? 'Deposit' : 'Withdraw')),
      ],
    );
  }
}

// ===========================================================================
// 7. SWITCH ACTIVE CHARACTER / PLAYER IDENTITY DIALOG
// ===========================================================================

