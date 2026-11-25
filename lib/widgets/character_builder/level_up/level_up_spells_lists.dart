import 'package:material_ui/material_ui.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/spellbook_data.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_theme.dart';
import '../../glyphs/dnd_glyph.dart';
import '../../spellbook/spell_comparison_dialog.dart';
import 'level_up_wizard_controller.dart';

class LevelUpSpellsLists extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;
  final DmRulesEdition edition;
  final SpellAllocationLimits limits;
  final bool isDark;
  final bool isMagicalSecretsActive;
  final bool isMysticArcanumActive;
  final int maxLvl;
  final int curCantripsCount;
  final int maxAllowedNewCantrips;
  final int maxAllowedNewSpells;
  final List<SpellItem> availableCantrips;
  final List<SpellItem> availableLeveled;

  const LevelUpSpellsLists({
    super.key,
    required this.controller,
    required this.customColors,
    required this.edition,
    required this.limits,
    required this.isDark,
    required this.isMagicalSecretsActive,
    required this.isMysticArcanumActive,
    required this.maxLvl,
    required this.curCantripsCount,
    required this.maxAllowedNewCantrips,
    required this.maxAllowedNewSpells,
    required this.availableCantrips,
    required this.availableLeveled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Spells Summary Chips
        if (controller.newCantrips.isNotEmpty ||
            controller.newSpells.isNotEmpty ||
            controller.selectedMysticArcanumSpellId != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected for this Level Up:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.purpleAccent)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (controller.selectedMysticArcanumSpellId != null)
                      () {
                        final spell = SpellbookLibrary.getSpellById(
                            controller.selectedMysticArcanumSpellId!);
                        return InputChip(
                          avatar: spell != null
                              ? DndGlyph.spell(
                                  school: spell.school,
                                  level: spell.level,
                                  size: 16,
                                  isDarkMode: true,
                                )
                              : null,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  'Mystic Arcanum: ${spell?.getName(edition) ?? controller.selectedMysticArcanumSpellId}'),
                              if (spell != null) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.info_outline,
                                    size: 12, color: Colors.amberAccent),
                              ],
                            ],
                          ),
                          backgroundColor:
                              Colors.deepPurple.shade800.withValues(alpha: 0.6),
                          onDeleted: () => controller.mutate(
                              () => controller.selectedMysticArcanumSpellId = null),
                          onPressed: spell != null
                              ? () {
                                  HapticService.selectionTick(context);
                                  SpellComparisonDialog.show(
                                    context,
                                    spell: spell,
                                    edition: edition,
                                    isPinned: false,
                                    onTogglePin: () {},
                                  );
                                }
                              : null,
                        );
                      }(),
                    ...controller.newCantrips.map((c) {
                      final spell = SpellbookLibrary.getSpellById(c);
                      return InputChip(
                        avatar: spell != null
                            ? DndGlyph.spell(
                                school: spell.school,
                                level: 0,
                                size: 16,
                                isDarkMode: true,
                              )
                            : null,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Cantrip: ${spell?.getName(edition) ?? c}'),
                            if (spell != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.info_outline,
                                  size: 12, color: Colors.purpleAccent),
                            ],
                          ],
                        ),
                        backgroundColor:
                            Colors.purple.shade800.withValues(alpha: 0.5),
                        onDeleted: () => controller.mutate(() => controller.newCantrips.remove(c)),
                        onPressed: spell != null
                            ? () {
                                HapticService.selectionTick(context);
                                SpellComparisonDialog.show(
                                  context,
                                  spell: spell,
                                  edition: edition,
                                  isPinned: false,
                                  onTogglePin: () {},
                                );
                              }
                            : null,
                      );
                    }),
                    ...controller.newSpells.map((s) {
                      final spell = SpellbookLibrary.getSpellById(s);
                      return InputChip(
                        avatar: spell != null
                            ? DndGlyph.spell(
                                school: spell.school,
                                level: spell.level,
                                size: 16,
                                isDarkMode: true,
                              )
                            : null,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '${spell?.levelLabel ?? "Spell"}: ${spell?.getName(edition) ?? s}'),
                            if (spell != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.info_outline,
                                  size: 12, color: Colors.cyanAccent),
                            ],
                          ],
                        ),
                        backgroundColor:
                            Colors.cyan.shade800.withValues(alpha: 0.5),
                        onDeleted: () => controller.mutate(() => controller.newSpells.remove(s)),
                        onPressed: spell != null
                            ? () {
                                HapticService.selectionTick(context);
                                SpellComparisonDialog.show(
                                  context,
                                  spell: spell,
                                  edition: edition,
                                  isPinned: false,
                                  onTogglePin: () {},
                                );
                              }
                            : null,
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Search Bar
        TextField(
          decoration: InputDecoration(
            labelText: 'Search Available Class Spells',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: controller.spellSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => controller.mutate(() => controller.spellSearchQuery = ''),
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => controller.mutate(() => controller.spellSearchQuery = v.trim()),
        ),
        const SizedBox(height: 12),

        // Available Cantrips Grid
        if (availableCantrips.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Available Cantrips (${availableCantrips.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.purpleAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: maxAllowedNewCantrips > 0
                        ? Colors.purpleAccent.withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: maxAllowedNewCantrips > 0
                          ? Colors.purpleAccent
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    maxAllowedNewCantrips > 0
                        ? '${controller.newCantrips.length}/$maxAllowedNewCantrips Selected'
                        : '0 New Allowed ($curCantripsCount/${limits.maxCantrips} known)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: maxAllowedNewCantrips > 0
                          ? Colors.purpleAccent
                          : Colors.white60,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableCantrips.map((c) {
              final isChosen = controller.newCantrips.contains(c.id);
              return _buildSpellSelectionChip(
                context: context,
                spell: c,
                isSelected: isChosen,
                accentColor: Colors.purpleAccent,
                edition: edition,
                onSelected: (selected) {
                  if (selected) {
                    if (controller.newCantrips.length >= maxAllowedNewCantrips) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            maxAllowedNewCantrips == 0
                                ? 'No new cantrips granted at Level ${controller.targetClassNewLevel} (already at maximum $curCantripsCount/${limits.maxCantrips}).'
                                : 'Cannot select more than $maxAllowedNewCantrips new cantrip(s) at Level ${controller.targetClassNewLevel}.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    controller.mutate(() => controller.newCantrips.add(c.id));
                  } else {
                    controller.mutate(() => controller.newCantrips.remove(c.id));
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Available Leveled Spells Grid (Grouped by Level)
        if (availableLeveled.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available Leveled Spells (Up to Level $maxLvl)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.cyanAccent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${controller.newSpells.length}/$maxAllowedNewSpells Selected',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(() {
            final spellsByLevel = <int, List<SpellItem>>{};
            for (final s in availableLeveled) {
              (spellsByLevel[s.level] ??= []).add(s);
            }
            final sortedLevels = spellsByLevel.keys.toList()..sort();

            return sortedLevels.map((lvl) {
              final levelSpells = spellsByLevel[lvl]!;
              final levelLabel = switch (lvl) {
                1 => '1st-Level Spells',
                2 => '2nd-Level Spells',
                3 => '3rd-Level Spells',
                _ => '${lvl}th-Level Spells',
              };
              final selectedAtThisLevel =
                  levelSpells.where((s) => controller.newSpells.contains(s.id)).length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedAtThisLevel > 0
                        ? Colors.cyanAccent.withValues(alpha: 0.4)
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedAtThisLevel > 0
                            ? Colors.cyan.shade900.withValues(alpha: 0.3)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'LEVEL $lvl',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              levelLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedAtThisLevel > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$selectedAtThisLevel selected',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${levelSpells.length} spells',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Spells in this Level
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: levelSpells.map((s) {
                          final isChosen = controller.newSpells.contains(s.id);
                          return _buildSpellSelectionChip(
                            context: context,
                            spell: s,
                            isSelected: isChosen,
                            accentColor: Colors.cyanAccent,
                            edition: edition,
                            onSelected: (selected) {
                              if (selected) {
                                if (controller.newSpells.length >= maxAllowedNewSpells) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        maxAllowedNewSpells == 0
                                            ? 'No new leveled spells granted at Level ${controller.targetClassNewLevel}.'
                                            : 'Cannot select more than $maxAllowedNewSpells new spell(s) at Level ${controller.targetClassNewLevel}.',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                controller.mutate(() => controller.newSpells.add(s.id));
                              } else {
                                controller.mutate(() => controller.newSpells.remove(s.id));
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            });
          })(),
          const SizedBox(height: 12),
        ],

        if (availableCantrips.isEmpty &&
            availableLeveled.isEmpty &&
            controller.spellSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No spells found matching "${controller.spellSearchQuery}"',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),

        // Custom Spell Entry Option
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.customSpellController,
                decoration: const InputDecoration(
                  labelText: 'Add Custom Spell / Cantrip',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              tooltip: 'Add Custom Spell',
              onPressed: () {
                final txt = controller.customSpellController.text.trim();
                if (txt.isNotEmpty) {
                  if (controller.newSpells.length >= maxAllowedNewSpells) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          maxAllowedNewSpells == 0
                              ? 'No new leveled spells granted at Level ${controller.targetClassNewLevel}.'
                              : 'Cannot select more than $maxAllowedNewSpells new spell(s) at Level ${controller.targetClassNewLevel}.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  HapticService.selectionTick(context);
                  controller.mutate(() {
                    controller.newSpells.add(txt);
                    controller.customSpellController.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpellSelectionChip({
    required BuildContext context,
    required SpellItem spell,
    required bool isSelected,
    required Color accentColor,
    required DmRulesEdition edition,
    required ValueChanged<bool> onSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = spell.level == 0
        ? spell.getName(edition)
        : '${spell.getName(edition)} (L${spell.level})';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.22)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white24 : Colors.black26),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(8)),
              onTap: () {
                HapticService.selectionTick(context);
                onSelected(!isSelected);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DndGlyph.spell(
                      school: spell.school,
                      level: spell.level,
                      size: 16,
                      isDarkMode: isDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? accentColor
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check, size: 14, color: accentColor),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 18,
              color: isSelected
                  ? accentColor.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
            Tooltip(
              message: 'Spell info: ${spell.getName(edition)}',
              child: InkWell(
                key: Key('spell_info_btn_${spell.id}'),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(8)),
                onTap: () {
                  HapticService.selectionTick(context);
                  SpellComparisonDialog.show(
                    context,
                    spell: spell,
                    edition: edition,
                    isPinned: false,
                    onTogglePin: () {},
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: isSelected
                        ? accentColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 6: SUMMARY & CONFIRMATION
}
