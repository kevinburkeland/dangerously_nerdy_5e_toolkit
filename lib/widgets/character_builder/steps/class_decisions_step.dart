import 'package:material_ui/material_ui.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../services/haptic_service.dart';
import '../../common/formatted_markdown_text.dart';

class BuilderClassDecisionsStep extends StatelessWidget {
  final CharacterClass curClass;
  final List<ClassFeatureDecision> decisions;
  final Map<String, List<String>> wizardSelectedFeatureOptions;
  final Set<String> selectedPacts;
  final Set<String> knownSpellSlugs;
  final ValueChanged<VoidCallback> onMutateState;

  const BuilderClassDecisionsStep({
    super.key,
    required this.curClass,
    required this.decisions,
    required this.wizardSelectedFeatureOptions,
    required this.selectedPacts,
    required this.knownSpellSlugs,
    required this.onMutateState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${curClass.name} Decisions & Specializations',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          'Customize your ${curClass.name} feature options at 1st level.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        ...decisions.map((decision) {
          final selected = wizardSelectedFeatureOptions[decision.id] ??= [
            if (decision.availableOptions.isNotEmpty)
              (decision.availableOptions.firstWhere(
                (o) => o.prerequisite
                    .evaluate(
                      classLevel: 1,
                      selectedPacts: selectedPacts,
                      knownSpellSlugs: knownSpellSlugs,
                    )
                    .isMet,
                orElse: () => decision.availableOptions.first,
              )).id,
          ];

          return Card(
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.white24),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          decision.type.displayName,
                          style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          decision.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(decision.prompt,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  ...decision.availableOptions.map((opt) {
                    final isOptSelected = selected.contains(opt.id);
                    final eval = opt.prerequisite.evaluate(
                      classLevel: 1,
                      selectedPacts: selectedPacts,
                      knownSpellSlugs: knownSpellSlugs,
                    );
                    final isGated = !eval.isMet && !isOptSelected;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isOptSelected
                            ? Colors.cyan.shade900.withValues(alpha: 0.3)
                            : (isGated ? Colors.black45 : Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOptSelected
                              ? Colors.cyanAccent.withValues(alpha: 0.7)
                              : (isGated
                                  ? Colors.orangeAccent.withValues(alpha: 0.3)
                                  : Colors.white12),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (isGated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Cannot select ${opt.name}: ${eval.summary}'),
                                backgroundColor: Colors.red.shade900,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            return;
                          }
                          HapticService.selectionTick(context);
                          onMutateState(() {
                            if (decision.maxSelections == 1) {
                              wizardSelectedFeatureOptions[decision.id] = [
                                opt.id
                              ];
                            } else {
                              final list = List<String>.from(
                                  wizardSelectedFeatureOptions[decision.id] ??
                                      []);
                              if (list.contains(opt.id)) {
                                if (list.length > decision.minSelections) {
                                  list.remove(opt.id);
                                }
                              } else {
                                if (list.length < decision.maxSelections) {
                                  list.add(opt.id);
                                }
                              }
                              wizardSelectedFeatureOptions[decision.id] = list;
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isGated
                                        ? Icons.lock_outline
                                        : (decision.maxSelections == 1
                                            ? (isOptSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off)
                                            : (isOptSelected
                                                ? Icons.check_box
                                                : Icons
                                                    .check_box_outline_blank)),
                                    color: isOptSelected
                                        ? Colors.cyanAccent
                                        : (isGated
                                            ? Colors.orangeAccent
                                                .withValues(alpha: 0.7)
                                            : Colors.white38),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      opt.name,
                                      style: TextStyle(
                                        color: isOptSelected
                                            ? Colors.cyanAccent
                                            : (isGated
                                                ? Colors.white38
                                                : Colors.white),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  if (isGated)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade900
                                            .withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.orangeAccent
                                                .withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        eval.summary,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (opt.descriptionMarkdown.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 26),
                                  child: FormattedMarkdownText(
                                    opt.descriptionMarkdown,
                                    defaultColor: isGated
                                        ? Colors.white38
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

}
