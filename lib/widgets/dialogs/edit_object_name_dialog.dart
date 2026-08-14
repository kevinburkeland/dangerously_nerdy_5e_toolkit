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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.edit_note, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Rename Object',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Enter custom object name',
          hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
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
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          onPressed: _submit,
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
