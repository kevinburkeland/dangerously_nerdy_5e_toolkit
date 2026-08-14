import 'package:flutter/material.dart';

class EditObjectNameDialog extends StatefulWidget {
  final String initialName;

  const EditObjectNameDialog({
    super.key,
    required this.initialName,
  });

  static Future<String?> show(BuildContext context, {required String initialName}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => EditObjectNameDialog(initialName: initialName),
    );
  }

  @override
  State<EditObjectNameDialog> createState() => _EditObjectNameDialogState();
}

class _EditObjectNameDialogState extends State<EditObjectNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      title: const Text('Rename Object', style: TextStyle(color: Colors.amber)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Enter custom object name',
          hintStyle: TextStyle(color: Colors.white54),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          onPressed: _submit,
          child: const Text('Save', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
