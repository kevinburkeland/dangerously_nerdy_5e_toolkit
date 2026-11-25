import 'package:material_ui/material_ui.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../services/haptic_service.dart';
import '../../common/formatted_markdown_text.dart';

class BuilderSubclassStep extends StatelessWidget {
  final CharacterClass curClass;
  final RulesetVersion selectedRuleset;
  final String? wizardSelectedSubclass;
  final ValueChanged<String> onSelectSubclass;

  const BuilderSubclassStep({
    super.key,
    required this.curClass,
    required this.selectedRuleset,
    required this.wizardSelectedSubclass,
    required this.onSelectSubclass,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (curClass.subclasses.isEmpty) {
      return const Text('No subclasses available for this class.');
    }
    final selectedSlug = wizardSelectedSubclass ?? curClass.subclasses.first.id.slug;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose ${curClass.name} Subclass / Archetype',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          'Under the selected ruleset (${selectedRuleset == RulesetVersion.v2024 ? '2024' : '2014'}), ${curClass.name} chooses an archetype at 1st level.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        ...curClass.subclasses.map((sub) {
          final isSelected = sub.id.slug == selectedSlug;
          return Card(
            color: isSelected
                ? Colors.cyan.shade900.withValues(alpha: 0.4)
                : const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticService.selectionTick(context);
                onSelectSubclass(sub.id.slug);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color:
                              isSelected ? Colors.cyanAccent : Colors.white54,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sub.name,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.cyanAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sub.featuresMarkdown.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FormattedMarkdownText(
                        sub.featuresMarkdown,
                        defaultColor: Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

}
