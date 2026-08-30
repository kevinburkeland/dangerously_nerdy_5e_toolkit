import 'package:flutter/material.dart';
import '../../models/domain/entity_reference.dart';
import '../../services/acl/homebrew_merge_resolver.dart';
import '../../services/ingestion/compendium_json_ingestion_pipeline.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog providing interactive preview, category filters, automated deduplication,
/// and collision resolution for incoming Homebrew Bundles or Compendium JSON.
class HomebrewImportPreviewDialog extends StatefulWidget {
  final String? initialJson;

  const HomebrewImportPreviewDialog({
    super.key,
    this.initialJson,
  });

  @override
  State<HomebrewImportPreviewDialog> createState() => _HomebrewImportPreviewDialogState();
}

class _HomebrewImportPreviewDialogState extends State<HomebrewImportPreviewDialog> {
  final _textController = TextEditingController();
  final _persistence = HomebrewPersistenceService();
  final _pipeline = CompendiumJsonIngestionPipeline();
  final _resolver = const HomebrewMergeResolver();

  ImportAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  bool _isImporting = false;
  bool _applyToRemainingCollisions = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialJson != null && widget.initialJson!.isNotEmpty) {
      _textController.text = widget.initialJson!;
      _analyzeInput(widget.initialJson!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyzeInput(String jsonString) async {
    if (jsonString.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final ingestion = _pipeline.ingestJsonString(jsonString);
      if (ingestion.hasErrors && ingestion.totalEntities == 0) {
        setState(() {
          _errorMessage = ingestion.errors.join('\n');
          _isAnalyzing = false;
        });
        return;
      }

      final bundle = ingestion.toBundle();

      // Load local items for deduplication
      final spells = await _persistence.loadCustomSpells();
      final monsters = await _persistence.loadCustomMonsters();
      final items = await _persistence.loadCustomItems();
      final classes = await _persistence.loadCustomClasses();
      final subclasses = await _persistence.loadCustomSubclasses();
      final races = await _persistence.loadCustomRaces();
      final feats = await _persistence.loadCustomFeats();
      final backgrounds = await _persistence.loadCustomBackgrounds();
      final others = await _persistence.loadCustomOtherEntries();

      final analysis = _resolver.analyzeBundle(
        incomingBundle: bundle,
        localSpells: spells,
        localMonsters: monsters,
        localItems: items,
        localClasses: classes,
        localSubclasses: subclasses,
        localRaces: races,
        localFeats: feats,
        localBackgrounds: backgrounds,
        localOtherEntries: others,
      );

      if (mounted) {
        setState(() {
          _analysisResult = analysis;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to analyze compendium: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _commitImport() async {
    final analysis = _analysisResult;
    if (analysis == null || !analysis.hasSelected) return;

    setState(() => _isImporting = true);

    try {
      await _persistence.importResolvedBundle(analysis);
      if (mounted) {
        Navigator.of(context).pop(analysis.selectedCount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analysis = _analysisResult;

    return AppDialogFrame(
      icon: Icons.file_download_outlined,
      iconColor: Colors.tealAccent,
      title: analysis == null ? 'Import Homebrew / Compendium JSON' : 'Homebrew Import Preview',
      maxWidth: 680,
      content: _isAnalyzing
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing schema and checking for conflicts...'),
                  ],
                ),
              ),
            )
          : analysis == null
              ? _buildInputView(theme)
              : _buildAnalysisPreview(theme, analysis),
      actions: [
        if (analysis != null)
          TextButton(
            onPressed: () => setState(() => _analysisResult = null),
            child: const Text('Back / Edit JSON'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (analysis == null)
          ElevatedButton.icon(
            onPressed: () => _analyzeInput(_textController.text),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Analyze Bundle'),
          )
        else
          ElevatedButton.icon(
            onPressed: analysis.hasSelected && !_isImporting ? _commitImport : null,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text('Confirm Import (${analysis.selectedCount} items)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
            ),
          ),
      ],
    );
  }

  Widget _buildInputView(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste Community Compendium JSON, homebrew entity maps, or an exported Homebrew Bundle JSON package.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          maxLines: 8,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            hintText: '{\n  "spell": [...],\n  "monster": [...]\n}',
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalysisPreview(ThemeData theme, ImportAnalysisResult analysis) {
    return SizedBox(
      height: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                label: '${analysis.novelCount} New',
                icon: Icons.add_circle_outline,
                color: Colors.greenAccent,
              ),
              if (analysis.srdDuplicateCount > 0)
                _buildMetricChip(
                  label: '${analysis.srdDuplicateCount} SRD Built-in (Excluded)',
                  icon: Icons.shield_outlined,
                  color: Colors.cyanAccent,
                ),
              _buildMetricChip(
                label: '${analysis.identicalCount} Already in Library',
                icon: Icons.check_circle_outline,
                color: Colors.grey,
              ),
              _buildMetricChip(
                label: '${analysis.collisionCount} Conflicts',
                icon: Icons.warning_amber_rounded,
                color: analysis.hasCollisions ? Colors.amberAccent : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Category List
          Expanded(
            child: ListView(
              children: [
                if (analysis.spells.isNotEmpty)
                  _buildCategorySection('Spells', analysis.spells),
                if (analysis.monsters.isNotEmpty)
                  _buildCategorySection('Monsters', analysis.monsters),
                if (analysis.items.isNotEmpty)
                  _buildCategorySection('Equipment & Magic Items', analysis.items),
                if (analysis.classes.isNotEmpty)
                  _buildCategorySection('Classes', analysis.classes),
                if (analysis.subclasses.isNotEmpty)
                  _buildCategorySection('Subclasses', analysis.subclasses),
                if (analysis.races.isNotEmpty)
                  _buildCategorySection('Races & Species', analysis.races),
                if (analysis.feats.isNotEmpty)
                  _buildCategorySection('Feats', analysis.feats),
                if (analysis.backgrounds.isNotEmpty)
                  _buildCategorySection('Backgrounds', analysis.backgrounds),
                if (analysis.otherEntries.any((e) => e.incomingEntity.category.toLowerCase().contains('invocation')))
                  _buildCategorySection(
                    'Eldritch Invocations',
                    analysis.otherEntries.where((e) => e.incomingEntity.category.toLowerCase().contains('invocation')).toList(),
                  ),
                if (analysis.otherEntries.any((e) => !e.incomingEntity.category.toLowerCase().contains('invocation')))
                  _buildCategorySection(
                    'Rules & Tables',
                    analysis.otherEntries.where((e) => !e.incomingEntity.category.toLowerCase().contains('invocation')).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCategorySection<T extends DomainEntity>(
    String title,
    List<ImportAnalysisItem<T>> items,
  ) {
    final allSelected = items.every((i) => i.isSelected);

    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        '$title (${items.where((i) => i.isSelected).length}/${items.length})',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      trailing: TextButton(
        onPressed: () {
          setState(() {
            final nextState = !allSelected;
            for (final item in items) {
              item.isSelected = nextState;
            }
          });
        },
        child: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 12)),
      ),
      children: items.map((item) => _buildItemTile(item)).toList(),
    );
  }

  Widget _buildItemTile<T extends DomainEntity>(ImportAnalysisItem<T> item) {
    final isCollision = item.disposition == ImportDisposition.collision;
    final isIdentical = item.disposition == ImportDisposition.identical;
    final isSrd = item.isSrdCanon;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCollision
            ? Colors.amberAccent.withValues(alpha: 0.08)
            : isSrd
                ? Colors.cyanAccent.withValues(alpha: 0.04)
                : isIdentical
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCollision
              ? Colors.amberAccent.withValues(alpha: 0.3)
              : isSrd
                  ? Colors.cyanAccent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: (val) => setState(() => item.isSelected = val ?? false),
                activeColor: Colors.tealAccent,
                checkColor: Colors.black,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Text(
                  item.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isIdentical || isSrd ? Colors.white54 : Colors.white,
                  ),
                ),
              ),
              if (isSrd)
                _buildBadge('SRD BUILT-IN', Colors.cyanAccent)
              else if (item.disposition == ImportDisposition.novel)
                _buildBadge('NEW', Colors.greenAccent)
              else if (isIdentical)
                _buildBadge('IDENTICAL', Colors.grey)
              else
                _buildBadge('CONFLICT', Colors.amberAccent),
            ],
          ),
          if (isCollision) ...[
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4, bottom: 6),
              child: Text(
                item.diffSummary,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amberAccent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: SegmentedButton<CollisionResolution>(
                segments: const [
                  ButtonSegment(
                    value: CollisionResolution.overwrite,
                    label: Text('Overwrite', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: CollisionResolution.keepLocal,
                    label: Text('Keep Local', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: CollisionResolution.duplicateRename,
                    label: Text('Duplicate (Copy)', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {item.resolution},
                onSelectionChanged: (set) {
                  final chosen = set.first;
                  setState(() {
                    item.resolution = chosen;
                    if (_applyToRemainingCollisions && _analysisResult != null) {
                      _analysisResult!.applyResolutionToAllCollisions(chosen);
                    }
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _applyToRemainingCollisions = !_applyToRemainingCollisions;
                    if (_applyToRemainingCollisions && _analysisResult != null) {
                      _analysisResult!.applyResolutionToAllCollisions(item.resolution);
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        key: const Key('do_for_remaining_collisions_checkbox'),
                        value: _applyToRemainingCollisions,
                        onChanged: (val) {
                          setState(() {
                            _applyToRemainingCollisions = val ?? false;
                            if (_applyToRemainingCollisions && _analysisResult != null) {
                              _analysisResult!.applyResolutionToAllCollisions(item.resolution);
                            }
                          });
                        },
                        activeColor: Colors.tealAccent,
                        checkColor: Colors.black,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Do this for remaining collisions',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
