import 'dart:math' as math;
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/dm_screen_data.dart' show DmRulesEdition;
import 'package:material_ui/material_ui.dart';
import '../../../services/haptic_service.dart';
import 'builder_step_order.dart';

class BuilderBasicsStep extends StatelessWidget {
  final TextEditingController nameController;
  final RulesetVersion selectedRuleset;
  final ValueChanged<String> onRandomNameSelected;
  final ValueChanged<DmRulesEdition> onRulesEditionChanged;

  const BuilderBasicsStep({
    super.key,
    required this.nameController,
    required this.selectedRuleset,
    required this.onRandomNameSelected,
    required this.onRulesEditionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 1: Character Identity & Edition',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text(
            'Enter your character\'s name and pick the 5e rules standard.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Character Name',
                  hintText: 'e.g. Valeros Ironclad',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.casino),
              tooltip: 'Random Name Suggestion',
              onPressed: () {
                HapticService.selectionTick(context);
                onRandomNameSelected(
                  kBuilderSuggestedNames[
                      math.Random().nextInt(kBuilderSuggestedNames.length)],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Ruleset Standard:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<RulesetVersion>(
          segments: const [
            ButtonSegment(
              value: RulesetVersion.v2024,
              label: Text('2024 SRD (5.2 Revised)'),
              icon: Icon(Icons.auto_awesome),
            ),
            ButtonSegment(
              value: RulesetVersion.v2014,
              label: Text('2014 SRD (5.1 Classic)'),
              icon: Icon(Icons.history_edu),
            ),
          ],
          selected: {selectedRuleset},
          onSelectionChanged: (set) {
            final targetRuleset = set.first;
            final targetEdition = targetRuleset == RulesetVersion.v2024
                ? DmRulesEdition.v2024
                : DmRulesEdition.v2014;
            onRulesEditionChanged(targetEdition);
          },
        ),
      ],
    );
  }
}
