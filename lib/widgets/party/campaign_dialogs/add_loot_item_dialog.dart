import 'package:material_ui/material_ui.dart';
import '../../../models/party/party_loot_item.dart';
import '../../../services/party/party_room_service.dart';

class AddLootItemDialog extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const AddLootItemDialog(
      {super.key, required this.roomCode, required this.playerName});

  static Future<void> show(BuildContext context,
      {required String roomCode, required String playerName}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          AddLootItemDialog(roomCode: roomCode, playerName: playerName),
    );
  }

  @override
  State<AddLootItemDialog> createState() => _AddLootItemDialogState();
}

class _AddLootItemDialogState extends State<AddLootItemDialog> {
  final _nameController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _gpController = TextEditingController(text: '0');
  String _category = 'gear';
  bool _requiresAttunement = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _gpController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final count = int.tryParse(_countController.text) ?? 1;
    final gp = double.tryParse(_gpController.text) ?? 0.0;
    final itemId =
        'loot_${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(RegExp(r'\W+'), '_').toLowerCase()}';

    final item = PartyLootItem(
      id: itemId,
      name: name,
      category: _category,
      count: count.clamp(1, 9999),
      gpValue: gp.clamp(0.0, 9999999.0),
      requiresAttunement: _requiresAttunement,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    _partyService.addLootItem(
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      item: item,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Vault Item',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Item Name', hintText: 'e.g. Cloak of Protection'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _category,
              items: const [
                DropdownMenuItem(
                    value: 'gear', child: Text('Adventuring Gear / Equipment')),
                DropdownMenuItem(
                    value: 'magicItem', child: Text('✨ Magic Item')),
                DropdownMenuItem(value: 'gem', child: Text('💎 Gemstone')),
                DropdownMenuItem(value: 'art', child: Text('🎨 Art Object')),
                DropdownMenuItem(
                    value: 'currency', child: Text('💰 Currency / Ingot')),
              ],
              onChanged: (val) => setState(() => _category = val ?? 'gear'),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _gpController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'GP Value Each'),
                  ),
                ),
              ],
            ),
            if (_category == 'magicItem') ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Requires Attunement'),
                value: _requiresAttunement,
                onChanged: (val) =>
                    setState(() => _requiresAttunement = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Add to Vault')),
      ],
    );
  }
}

