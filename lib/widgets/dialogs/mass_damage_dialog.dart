import 'package:flutter/material.dart';

class MassDamageDialog extends StatefulWidget {
  const MassDamageDialog({super.key});

  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => const MassDamageDialog(),
    );
  }

  @override
  State<MassDamageDialog> createState() => _MassDamageDialogState();
}

class _MassDamageDialogState extends State<MassDamageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final dmg = int.tryParse(_controller.text);
    if (dmg != null && dmg > 0) {
      Navigator.pop(context, dmg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      title: const Text('Apply Group Damage (e.g. AoE spell)', style: TextStyle(color: Colors.redAccent)),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Damage Amount to ALL minions',
          labelStyle: TextStyle(color: Colors.white70),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: _submit,
          child: const Text('Apply Damage', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
