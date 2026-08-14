import 'package:flutter/material.dart';

class SetObjectHpResult {
  final int currentHp;
  final int tempHp;
  const SetObjectHpResult({required this.currentHp, required this.tempHp});
}

class SetObjectHpDialog extends StatefulWidget {
  final String objectName;
  final int currentHp;
  final int maxHp;
  final int tempHp;

  const SetObjectHpDialog({
    super.key,
    required this.objectName,
    required this.currentHp,
    required this.maxHp,
    this.tempHp = 0,
  });

  static Future<SetObjectHpResult?> show(
    BuildContext context, {
    required String objectName,
    required int currentHp,
    required int maxHp,
    int tempHp = 0,
  }) {
    return showDialog<SetObjectHpResult>(
      context: context,
      builder: (ctx) => SetObjectHpDialog(
        objectName: objectName,
        currentHp: currentHp,
        maxHp: maxHp,
        tempHp: tempHp,
      ),
    );
  }

  @override
  State<SetObjectHpDialog> createState() => _SetObjectHpDialogState();
}

class _SetObjectHpDialogState extends State<SetObjectHpDialog> {
  late final TextEditingController _hpController;
  late final TextEditingController _tempHpController;

  @override
  void initState() {
    super.initState();
    _hpController = TextEditingController(text: '${widget.currentHp}');
    _tempHpController = TextEditingController(text: '${widget.tempHp}');
  }

  @override
  void dispose() {
    _hpController.dispose();
    _tempHpController.dispose();
    super.dispose();
  }

  void _submit() {
    final newHp = int.tryParse(_hpController.text) ?? widget.currentHp;
    final newTemp = int.tryParse(_tempHpController.text) ?? widget.tempHp;
    Navigator.pop(
      context,
      SetObjectHpResult(
        currentHp: newHp.clamp(0, widget.maxHp),
        tempHp: newTemp < 0 ? 0 : newTemp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.favorite, color: Colors.amber, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Set HP: ${widget.objectName}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.amber, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _hpController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current HP (Max ${widget.maxHp})',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.shield_outlined, color: Colors.greenAccent),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tempHpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.cyanAccent),
              decoration: const InputDecoration(
                labelText: 'Temporary HP (Absorbs damage first)',
                labelStyle: TextStyle(color: Colors.cyanAccent),
                prefixIcon: Icon(Icons.health_and_safety, color: Colors.cyanAccent),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent, width: 2)),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          onPressed: _submit,
          child: const Text('Save HP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
