import 'package:flutter/material.dart';
import '../../models/custom_preset.dart';
import '../../services/preset_service.dart';
import '../../theme/app_theme.dart';

class RollPresetsSection extends StatelessWidget {
  final List<CustomPreset> userPresets;
  final ValueChanged<CustomPreset> onApplyPreset;
  final ValueChanged<CustomPreset> onDeletePreset;
  final VoidCallback onSaveCurrentPreset;
  final VoidCallback onExportPresets;
  final VoidCallback onImportPresets;

  const RollPresetsSection({
    super.key,
    required this.userPresets,
    required this.onApplyPreset,
    required this.onDeletePreset,
    required this.onSaveCurrentPreset,
    required this.onExportPresets,
    required this.onImportPresets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER ROW: Presets title + actions
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Presets',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.download,
                      size: 18, color: primary),
                  tooltip: 'Export Presets (JSON)',
                  onPressed: onExportPresets,
                ),
                IconButton(
                  icon: Icon(Icons.upload,
                      size: 18, color: primary),
                  tooltip: 'Import Presets (JSON)',
                  onPressed: onImportPresets,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    backgroundColor: primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.bookmark_add,
                      size: 16, color: primary),
                  label: Text(
                    'Save Current',
                    style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: onSaveCurrentPreset,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. MY SAVED PRESETS SECTION
        Text(
          'MY SAVED PRESETS',
          style: TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        if (userPresets.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: userPresets
                  .map((preset) => _buildCustomPresetChip(context, preset))
                  .toList(),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF28243D) : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark_border, color: primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No custom presets yet. Adjust dice & tap "Save Current" to create one!',
                    style: TextStyle(color: primary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // 3. BUILT-IN QUICK PRESETS SECTION
        Text(
          'QUICK PRESETS',
          style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PresetService.defaultPresets
                .map((preset) => _buildBuiltInPresetChip(context, preset))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPresetChip(BuildContext context, CustomPreset preset) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2744) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onApplyPreset(preset),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 14, color: primary),
              const SizedBox(width: 6),
              Text(
                '${preset.name} (${preset.formulaString})',
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onDeletePreset(preset),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuiltInPresetChip(BuildContext context, CustomPreset preset) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: tabletop.cardBackground,
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        label: Text('${preset.name} (${preset.formulaString})',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12)),
        onPressed: () => onApplyPreset(preset),
      ),
    );
  }
}
