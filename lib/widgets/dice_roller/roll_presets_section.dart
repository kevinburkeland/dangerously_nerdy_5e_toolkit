import 'package:flutter/material.dart';
import '../../models/custom_preset.dart';
import '../../services/preset_service.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PRESETS HEADER & ACTIONS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Presets',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.download,
                      size: 18, color: Colors.cyanAccent),
                  tooltip: 'Export Presets (JSON)',
                  onPressed: onExportPresets,
                ),
                IconButton(
                  icon: const Icon(Icons.upload,
                      size: 18, color: Colors.cyanAccent),
                  tooltip: 'Import Presets (JSON)',
                  onPressed: onImportPresets,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.bookmark_add,
                      size: 16, color: Colors.amber),
                  label: const Text(
                    'Save Current',
                    style: TextStyle(
                        color: Colors.amber,
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
        const Text(
          'MY SAVED PRESETS',
          style: TextStyle(
              color: Colors.amber,
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
                  .map((preset) => _buildCustomPresetChip(preset))
                  .toList(),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF28243D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.bookmark_border, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No custom presets yet. Adjust dice & tap "Save Current" to create one!',
                    style: TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // 3. BUILT-IN QUICK PRESETS SECTION
        const Text(
          'QUICK PRESETS',
          style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PresetService.defaultPresets
                .map((preset) => _buildBuiltInPresetChip(preset))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPresetChip(CustomPreset preset) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2744),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onApplyPreset(preset),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                '${preset.name} (${preset.formulaString})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onDeletePreset(preset),
                child: const Padding(
                  padding: EdgeInsets.all(3.0),
                  child: Icon(Icons.close, size: 14, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuiltInPresetChip(CustomPreset preset) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: const Color(0xFF28243D),
        side: const BorderSide(color: Colors.white12),
        label: Text('${preset.name} (${preset.formulaString})',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onPressed: () => onApplyPreset(preset),
      ),
    );
  }
}
