import 'package:flutter/material.dart';

/// Dialog for granting Temporary HP to the entire squad.
/// Owns its own [TextEditingController] lifecycle internally.
class GrantTempHpDialog {
  static Future<int?> show(BuildContext context) async {
    final controller = TextEditingController(text: '5');

    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Grant Group Temp HP',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Temporary HP Amount',
            labelStyle: TextStyle(color: Colors.cyanAccent),
            prefixIcon: Icon(Icons.shield, color: Colors.cyanAccent),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
            ),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, int.tryParse(val)?.clamp(1, 999)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text)?.clamp(1, 999)),
            child: const Text(
              'Grant Temp HP',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    return amount;
  }
}
