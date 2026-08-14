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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.tune, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Custom Sided Die',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter number of sides (e.g. 7 for d7, 14 for d14, 30 for d30):',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Number of Sides (2 to 1000)',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          onPressed: _submit,
          child: const Text(
            'Add Die',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
