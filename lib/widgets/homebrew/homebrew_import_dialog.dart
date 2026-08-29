import 'package:flutter/material.dart';
import '../../services/ingestion/compendium_json_ingestion_pipeline.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog for importing custom or community compendium JSON into local Homebrew storage.
class HomebrewImportDialog extends StatefulWidget {
  const HomebrewImportDialog({super.key});

  @override
  State<HomebrewImportDialog> createState() => _HomebrewImportDialogState();
}

class _HomebrewImportDialogState extends State<HomebrewImportDialog> {
  final _textController = TextEditingController();
  final _pipeline = CompendiumJsonIngestionPipeline();

  IngestionBatchResult? _previewResult;
  bool _isImporting = false;

  void _handleAnalyze() {
    final input = _textController.text.trim();
    if (input.isEmpty) {
      setState(() => _previewResult = null);
      return;
    }

    final result = _pipeline.ingestJsonString(input);
    setState(() => _previewResult = result);
  }

  Future<void> _handleCommitImport() async {
    if (_previewResult == null || _previewResult!.totalEntities == 0) return;

    setState(() => _isImporting = true);

    try {
      final persistence = HomebrewPersistenceService();

      for (final spell in _previewResult!.spells) {
        await persistence.saveCustomSpell(spell);
      }
      for (final monster in _previewResult!.monsters) {
        await persistence.saveCustomMonster(monster);
      }
      for (final item in _previewResult!.items) {
        await persistence.saveCustomItem(item);
      }

      if (mounted) {
        Navigator.of(context).pop(_previewResult);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to commit import: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _previewResult;

    return AppDialogFrame(
      icon: Icons.download,
      iconColor: Colors.tealAccent,
      title: 'Import Compendium JSON',
      maxWidth: 580,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paste a standard JSON compendium snippet or bundle (Spells, Monsters, or Items):',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '{\n  "spell": [\n    {\n      "name": "Custom Spell",\n      "level": 1,\n      ...\n    }\n  ]\n}',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _handleAnalyze(),
            ),
            const SizedBox(height: 12),
            if (preview != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: preview.totalEntities > 0
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: preview.totalEntities > 0
                        ? Colors.tealAccent.withValues(alpha: 0.4)
                        : Colors.redAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.totalEntities > 0
                          ? '✅ Detected ${preview.totalEntities} entities to import:'
                          : '⚠️ No valid entities found in payload',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    if (preview.spells.isNotEmpty)
                      Text('• Spells: ${preview.spells.length} (${preview.spells.map((s) => s.name).take(3).join(', ')}${preview.spells.length > 3 ? '...' : ''})'),
                    if (preview.monsters.isNotEmpty)
                      Text('• Monsters: ${preview.monsters.length} (${preview.monsters.map((m) => m.name).take(3).join(', ')}${preview.monsters.length > 3 ? '...' : ''})'),
                    if (preview.items.isNotEmpty)
                      Text('• Items: ${preview.items.length} (${preview.items.map((i) => i.name).take(3).join(', ')}${preview.items.length > 3 ? '...' : ''})'),
                    if (preview.hasErrors) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Errors / Warnings: ${preview.errors.join('; ')}',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (preview != null && preview.totalEntities > 0 && !_isImporting)
              ? _handleCommitImport
              : null,
          icon: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_done),
          label: Text(_isImporting ? 'Importing...' : 'Import to Compendium'),
        ),
      ],
    );
  }
}
