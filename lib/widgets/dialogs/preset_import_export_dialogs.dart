import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExportPresetDialog extends StatelessWidget {
  final String jsonStr;

  const ExportPresetDialog({
    super.key,
    required this.jsonStr,
  });

  static Future<void> show(BuildContext context, String jsonStr) {
    return showDialog<void>(
      context: context,
      builder: (context) => ExportPresetDialog(jsonStr: jsonStr),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      title: const Row(
        children: [
          Icon(Icons.download, color: Colors.cyanAccent, size: 22),
          SizedBox(width: 8),
          Text('Export Presets JSON', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Copy this JSON backup to transfer or save your presets:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr.isNotEmpty ? jsonStr : '[]',
                style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontFamily: 'monospace',
                    fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to Clipboard',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonStr));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Presets JSON copied to clipboard!'),
                backgroundColor: Color(0xFF28243D),
              ),
            );
          },
        ),
      ],
    );
  }
}

class ImportPresetDialog extends StatefulWidget {
  const ImportPresetDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const ImportPresetDialog(),
    );
  }

  @override
  State<ImportPresetDialog> createState() => _ImportPresetDialogState();
}

class _ImportPresetDialogState extends State<ImportPresetDialog> {
  late final TextEditingController _importController;

  @override
  void initState() {
    super.initState();
    _importController = TextEditingController();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _importController.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF242038),
      title: const Row(
        children: [
          Icon(Icons.upload, color: Colors.cyanAccent, size: 22),
          SizedBox(width: 8),
          Text('Import Presets JSON', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste custom presets JSON text below:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _importController,
            maxLines: 6,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText:
                  '[{"name": "Fireball", "dieType": "d6", "count": 8, "modifier": 0}]',
              hintStyle: TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton.icon(
          icon: const Icon(Icons.paste, size: 16, color: Colors.cyanAccent),
          label: const Text('Paste Clipboard',
              style: TextStyle(color: Colors.cyanAccent)),
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              _importController.text = data!.text!;
            }
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black),
          onPressed: _submit,
          child: const Text('Import',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
