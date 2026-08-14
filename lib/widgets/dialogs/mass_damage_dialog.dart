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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final damageColor = colorScheme.error;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.local_fire_department, color: damageColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Apply Group Damage (e.g. AoE spell)',
              style: TextStyle(
                color: damageColor,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: 'Damage Amount to ALL minions',
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: damageColor, width: 2),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: damageColor,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: _submit,
          child: const Text('Apply Damage', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
