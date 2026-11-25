import 'package:material_ui/material_ui.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_equipment_library.dart';
import '../../../presentation/visual/visual_ui.dart';
import '../../../services/haptic_service.dart';

class BuilderEquipmentStep extends StatelessWidget {
  final String? selectedClass;
  final RulesetVersion selectedRuleset;
  final String? selectedStartingEquipmentPreset;
  final int stepNumber;
  final ValueChanged<String> onSelectEquipmentPreset;

  const BuilderEquipmentStep({
    super.key,
    required this.selectedClass,
    required this.selectedRuleset,
    required this.selectedStartingEquipmentPreset,
    required this.stepNumber,
    required this.onSelectEquipmentPreset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curClass = selectedClass != null
        ? SrdClassesLibrary.findBySlug(selectedClass!,
            ruleset: selectedRuleset)
        : null;
    final packages = curClass != null
        ? SrdEquipmentLibrary.getPackagesForClass(curClass.id.slug)
        : <SrdEquipmentPackage>[];
    

    final effectivePresetId = (packages.isNotEmpty &&
            !packages.any((p) => p.id == selectedStartingEquipmentPreset))
        ? packages.first.id
        : selectedStartingEquipmentPreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $stepNumber: Starting Equipment & Inventory (SRD)',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          curClass != null
              ? 'Choose an official 5e SRD starting inventory package or starting wealth for your ${curClass.name}.'
              : 'Choose an official 5e SRD starting inventory package or starting wealth.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        if (packages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Please select a starting class to view available equipment packages.',
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          ...packages.map((pkg) {
            return _buildEquipmentPresetOption(context, effectivePresetId, 
              id: pkg.id,
              title: pkg.name,
              subtitle: pkg.subtitle,
              icon: pkg.icon,
              gold: pkg.startingGold,
            );
          }),
      ],
    );
  }

  Widget _buildEquipmentPresetOption(BuildContext context, String? effectivePresetId, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    int? gold,
  }) {
    final isSelected = effectivePresetId == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.cyan.shade900.withValues(alpha: 0.3)
            : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.cyanAccent : Colors.white12,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.cyanAccent.withValues(alpha: 0.2)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isSelected ? Colors.cyanAccent : Colors.white70,
                size: 22),
          ),
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
              : (gold != null && gold > 0
                  ? Chip(
                      label: Text('$gold GP',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent)),
                      backgroundColor:
                          Colors.amber.shade900.withValues(alpha: 0.25),
                      side: BorderSide(
                          color: Colors.amber.withValues(alpha: 0.5)),
                      padding: EdgeInsets.zero,
                    )
                  : null),
          onTap: () {
            HapticService.selectionTick(context);
            onSelectEquipmentPreset(id);
          },
        ),
      ),
    );
  }
}
