import 'package:flutter/material.dart';

class SavePresetDialog extends StatefulWidget {
  final String formulaText;

  const SavePresetDialog({
    super.key,
    required this.formulaText,
  });

  static Future<String?> show(BuildContext context, {required String formulaText}) {
    return showDialog<String>(
      context: context,
      builder: (context) => SavePresetDialog(formulaText: formulaText),
    );
  }

  @override
  State<SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends State<SavePresetDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.formulaText);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      title: const Row(
        children: [
          Icon(Icons.bookmark_add, color: Colors.amber, size: 22),
          SizedBox(width: 8),
          Text('Save Custom Preset', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Config: ${widget.formulaText}',
            style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Preset Name (e.g. Sneak Attack)',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber)),
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
              backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: _submit,
          child: const Text('Save Preset',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
