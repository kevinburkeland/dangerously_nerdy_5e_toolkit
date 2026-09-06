import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../services/ingestion/compendium_json_ingestion_pipeline.dart';
import '../../services/io/compendium_file_picker_service.dart';
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

  RulesetVersion? _selectedRuleset = RulesetVersion.v2024;
  IngestionBatchResult? _previewResult;
  LoadedCompendiumFile? _loadedFile;
  bool _isImporting = false;

  void _handleAnalyze() {
    final input = _textController.text.trim();
    if (input.isEmpty) {
      setState(() => _previewResult = null);
      return;
    }

    final result = _pipeline.ingestJsonString(input, forceRuleset: _selectedRuleset);
    setState(() => _previewResult = result);
  }

  Future<void> _pickFile() async {
    final file = await CompendiumFilePickerService.pickCompendiumJsonFile();
    if (file == null) return;
    final result = _pipeline.ingestJsonString(file.content, forceRuleset: _selectedRuleset);
    setState(() {
      _loadedFile = file;
      _textController.clear();
      _previewResult = result;
    });
  }

  Future<void> _handleCommitImport() async {
    if (_previewResult == null || _previewResult!.totalEntities == 0) return;

    setState(() => _isImporting = true);

    try {
      final persistence = HomebrewPersistenceService();

      if (_previewResult!.spells.isNotEmpty) {
        await persistence.saveCustomSpellsBatch(_previewResult!.spells);
      }
      if (_previewResult!.monsters.isNotEmpty) {
        await persistence.saveCustomMonstersBatch(_previewResult!.monsters);
      }
      if (_previewResult!.items.isNotEmpty) {
        await persistence.saveCustomItemsBatch(_previewResult!.items);
      }
      if (_previewResult!.classes.isNotEmpty) {
        await persistence.saveCustomClassesBatch(_previewResult!.classes);
      }
      if (_previewResult!.subclasses.isNotEmpty) {
        await persistence.saveCustomSubclassesBatch(_previewResult!.subclasses);
      }
      if (_previewResult!.races.isNotEmpty) {
        await persistence.saveCustomRacesBatch(_previewResult!.races);
      }
      if (_previewResult!.feats.isNotEmpty) {
        await persistence.saveCustomFeatsBatch(_previewResult!.feats);
      }
      if (_previewResult!.backgrounds.isNotEmpty) {
        await persistence.saveCustomBackgroundsBatch(_previewResult!.backgrounds);
      }
      if (_previewResult!.otherEntries.isNotEmpty) {
        await persistence.saveCustomOtherEntriesBatch(_previewResult!.otherEntries);
      }
      await persistence.syncToLibraries();

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
    final loadedFile = _loadedFile;

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
              'Select the target ruleset edition for parsed homebrew entries:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<RulesetVersion?>(
                segments: const [
                  ButtonSegment<RulesetVersion?>(
                    value: RulesetVersion.v2024,
                    icon: Icon(Icons.auto_awesome, size: 16),
                    label: Text('2024 Revision'),
                  ),
                  ButtonSegment<RulesetVersion?>(
                    value: RulesetVersion.v2014,
                    icon: Icon(Icons.history_edu, size: 16),
                    label: Text('2014 Classic'),
                  ),
                  ButtonSegment<RulesetVersion?>(
                    value: null,
                    icon: Icon(Icons.auto_mode, size: 16),
                    label: Text('Auto-Detect'),
                  ),
                ],
                selected: {_selectedRuleset},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedRuleset = newSelection.first;
                  });
                  _handleAnalyze();
                },
              ),
            ),
            const SizedBox(height: 14),
            // ── File Upload ───────────────────────────────────────────────
            if (loadedFile == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload JSON File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.tealAccent,
                    side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.6)),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loadedFile.fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            loadedFile.formattedSize,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove file',
                      onPressed: () => setState(() {
                        _loadedFile = null;
                        _previewResult = null;
                      }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            // ── Paste Divider ─────────────────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    loadedFile == null ? 'OR PASTE JSON TEXT' : 'OR PASTE JSON TEXT INSTEAD',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              maxLines: 8,
              enabled: loadedFile == null,
              decoration: const InputDecoration(
                hintText: '{\n  "class": [...],\n  "race": [...],\n  "feat": [...],\n  "spell": [...],\n  "monster": [...],\n  "item": [...]\n}',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                if (val.trim().isNotEmpty) setState(() => _loadedFile = null);
                _handleAnalyze();
              },
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
                    if (preview.classes.isNotEmpty)
                      Text('• Classes: ${preview.classes.length} (${preview.classes.map((c) => c.name).take(3).join(', ')}${preview.classes.length > 3 ? '...' : ''})'),
                    if (preview.subclasses.isNotEmpty)
                      Text('• Subclasses: ${preview.subclasses.length} (${preview.subclasses.map((s) => s.name).take(3).join(', ')}${preview.subclasses.length > 3 ? '...' : ''})'),
                    if (preview.races.isNotEmpty)
                      Text('• Races / Species: ${preview.races.length} (${preview.races.map((r) => r.name).take(3).join(', ')}${preview.races.length > 3 ? '...' : ''})'),
                    if (preview.feats.isNotEmpty)
                      Text('• Feats: ${preview.feats.length} (${preview.feats.map((f) => f.name).take(3).join(', ')}${preview.feats.length > 3 ? '...' : ''})'),
                    if (preview.backgrounds.isNotEmpty)
                      Text('• Backgrounds: ${preview.backgrounds.length} (${preview.backgrounds.map((b) => b.name).take(3).join(', ')}${preview.backgrounds.length > 3 ? '...' : ''})'),
                    if (preview.spells.isNotEmpty)
                      Text('• Spells: ${preview.spells.length} (${preview.spells.map((s) => s.name).take(3).join(', ')}${preview.spells.length > 3 ? '...' : ''})'),
                    if (preview.monsters.isNotEmpty)
                      Text('• Monsters: ${preview.monsters.length} (${preview.monsters.map((m) => m.name).take(3).join(', ')}${preview.monsters.length > 3 ? '...' : ''})'),
                    if (preview.items.isNotEmpty)
                      Text('• Items: ${preview.items.length} (${preview.items.map((i) => i.name).take(3).join(', ')}${preview.items.length > 3 ? '...' : ''})'),
                    if (preview.otherEntries.isNotEmpty)
                      Text('• Other / Rules / Tables: ${preview.otherEntries.length} (${preview.otherEntries.map((o) => o.name).take(3).join(', ')}${preview.otherEntries.length > 3 ? '...' : ''})'),
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
