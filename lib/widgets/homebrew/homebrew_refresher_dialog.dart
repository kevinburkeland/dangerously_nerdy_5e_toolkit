import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../services/haptic_service.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog allowing users to run the JSON Refresher & AST Upgrade engine
/// across all persisted homebrew entities and inspect the results.
class HomebrewRefresherDialog extends StatefulWidget {
  const HomebrewRefresherDialog({super.key});

  @override
  State<HomebrewRefresherDialog> createState() => _HomebrewRefresherDialogState();
}

class _HomebrewRefresherDialogState extends State<HomebrewRefresherDialog> {
  final _persistence = HomebrewPersistenceService();
  bool _isLoadingCounts = true;
  bool _isRunning = false;
  ReparseResult? _result;
  int _totalEntities = 0;
  int _totalRawPayloads = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    int total = 0;
    int rawTotal = 0;

    for (final type in [
      EntityType.spell,
      EntityType.monster,
      EntityType.equipment,
      EntityType.classDefinition,
      EntityType.subclass,
      EntityType.species,
      EntityType.feat,
      EntityType.background,
      EntityType.custom,
    ]) {
      final rawCount = await _persistence.rawPayloadCount(type);
      rawTotal += rawCount;
      final entities = switch (type) {
        EntityType.spell => (await _persistence.loadCustomSpells()).length,
        EntityType.monster => (await _persistence.loadCustomMonsters()).length,
        EntityType.equipment => (await _persistence.loadCustomItems()).length,
        EntityType.classDefinition => (await _persistence.loadCustomClasses()).length,
        EntityType.subclass => (await _persistence.loadCustomSubclasses()).length,
        EntityType.species => (await _persistence.loadCustomRaces()).length,
        EntityType.feat => (await _persistence.loadCustomFeats()).length,
        EntityType.background => (await _persistence.loadCustomBackgrounds()).length,
        EntityType.custom => (await _persistence.loadCustomOtherEntries()).length,
        _ => 0,
      };
      total += entities;
    }

    if (mounted) {
      setState(() {
        _totalEntities = total;
        _totalRawPayloads = rawTotal;
        _isLoadingCounts = false;
      });
    }
  }

  Future<void> _runRefresher() async {
    HapticService.selectionTick(context);
    setState(() => _isRunning = true);

    try {
      final res = await _persistence.reparseAllHomebrew();
      if (mounted) {
        setState(() {
          _result = res;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running JSON refresher: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialogFrame(
      icon: Icons.auto_fix_high,
      iconColor: Colors.cyanAccent,
      title: 'JSON Refresher & AST Upgrade',
      maxWidth: 480,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Re-evaluates all stored homebrew payloads using the latest AST anti-corruption transformers. '
              'This upgrades legacy entries with declarative feature grants, rollable damage/attack math bindings, '
              'and automatically removes duplicate SRD content.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingCounts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_isRunning)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Re-parsing AST nodes and validating SRD deduplication...',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (_result != null)
              _buildResultView(theme, _result!)
            else
              _buildPreRunView(theme),
          ],
        ),
      ),
      actions: [
        if (_result == null && !_isRunning) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _totalEntities > 0 ? _runRefresher : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Run Refresher'),
          ),
        ] else if (_result != null) ...[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('Done'),
          ),
        ],
      ],
    );
  }

  Widget _buildPreRunView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Storage Overview',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            'Total Custom Entities:',
            '$_totalEntities items',
            theme,
          ),
          const SizedBox(height: 6),
          _buildStatRow(
            'Stored Raw JSON Payloads:',
            '$_totalRawPayloads / $_totalEntities',
            theme,
          ),
          if (_totalEntities == 0) ...[
            const SizedBox(height: 12),
            Text(
              'No custom homebrew entities found in storage.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ] else if (_totalRawPayloads < _totalEntities) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_totalEntities - _totalRawPayloads} legacy items were created or imported without raw JSON. '
                      'They will be safely retained as-is.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultView(ThemeData theme, ReparseResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text(
                'Refresher Report',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildReportItem(
            icon: Icons.sync,
            iconColor: Colors.cyanAccent,
            title: '${result.updatedCount} Entities Upgraded',
            subtitle: 'Re-parsed through AST node pipeline with grants and math formulas.',
            theme: theme,
          ),
          const SizedBox(height: 10),
          _buildReportItem(
            icon: Icons.remove_circle_outline,
            iconColor: result.srdRemovedCount > 0 ? Colors.orangeAccent : Colors.grey,
            title: '${result.srdRemovedCount} SRD Duplicates Pruned',
            subtitle: result.srdRemovedCount > 0
                ? 'Exact canonical SRD matches removed to prevent compendium clutter.'
                : 'No duplicate SRD entities found.',
            theme: theme,
          ),
          if (result.noPayloadCount > 0) ...[
            const SizedBox(height: 10),
            _buildReportItem(
              icon: Icons.shield_outlined,
              iconColor: Colors.amberAccent,
              title: '${result.noPayloadCount} Legacy Entities Kept',
              subtitle: 'Entities without raw JSON were safely retained without modification.',
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildReportItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
