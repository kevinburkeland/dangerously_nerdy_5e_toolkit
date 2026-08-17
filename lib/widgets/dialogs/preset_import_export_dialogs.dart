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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.download, color: primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Export Presets JSON',
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Copy this JSON backup to transfer or save your presets:',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black38 : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr.isNotEmpty ? jsonStr : '[]',
                style: TextStyle(
                    color: isDark ? Colors.cyanAccent : theme.colorScheme.primary,
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
          child: Text('Close', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: theme.colorScheme.onPrimary),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to Clipboard',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonStr));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Presets JSON copied to clipboard!'),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.upload, color: primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Import Presets JSON',
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste custom presets JSON text below:',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _importController,
            maxLines: 6,
            maxLength: 50000,
            style: TextStyle(
                color: theme.colorScheme.onSurface, fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              counterStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
              hintText:
                  '[{"name": "Fireball", "dieType": "d6", "count": 8, "modifier": 0}]',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        TextButton.icon(
          icon: Icon(Icons.paste, size: 16, color: primary),
          label: Text('Paste Clipboard',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              _importController.text = data!.text!;
            }
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: theme.colorScheme.onPrimary),
          onPressed: _submit,
          child: const Text('Import',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
