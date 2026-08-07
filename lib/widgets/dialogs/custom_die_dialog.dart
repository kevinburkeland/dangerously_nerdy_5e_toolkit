import 'package:flutter/material.dart';

class CustomDieDialog extends StatefulWidget {
  final int initialSides;

  const CustomDieDialog({
    super.key,
    this.initialSides = 7,
  });

  static Future<int?> show(BuildContext context, {int initialSides = 7}) {
    return showDialog<int>(
      context: context,
      builder: (context) => CustomDieDialog(initialSides: initialSides),
    );
  }

  @override
  State<CustomDieDialog> createState() => _CustomDieDialogState();
}

class _CustomDieDialogState extends State<CustomDieDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialSides}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final sides = int.tryParse(_controller.text.trim());
    if (sides != null && sides >= 2 && sides <= 1000) {
      Navigator.pop(context, sides);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid side count between 2 and 1000.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      title: const Row(
        children: [
          Icon(Icons.tune, color: Colors.cyanAccent, size: 22),
          SizedBox(width: 8),
          Text('Custom Sided Die', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter number of sides (e.g. 7 for d7, 14 for d14, 30 for d30):',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Number of Sides (2 to 1000)',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black),
          onPressed: _submit,
          child: const Text('Add Die',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
