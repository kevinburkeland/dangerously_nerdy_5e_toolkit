import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../../models/characters/subclass_spells_library.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/spellbook_data.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_theme.dart';
import '../../glyphs/dnd_glyph.dart';
import '../../spellbook/spell_comparison_dialog.dart';
import 'level_up_spells_lists.dart';
import 'level_up_wizard_controller.dart';

class LevelUpSpellsStep extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;

  const LevelUpSpellsStep({
    super.key,
    required this.controller,
    required this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStep5Spells(context, Theme.of(context), customColors);
  }

  Widget _buildStep5Spells(BuildContext context, ThemeData theme, TabletopColors? customColors) {
    if (!controller.isSpellcaster) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_outlined,
                size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'No Spellcasting Advancement at Level ${controller.targetClassNewLevel}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.selectedClassSlug} does not learn or prepare spells at this level.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final edition = controller.character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final defaultSpellClass = controller.targetSpellClass;
    final maxLvl = controller.maxAccessibleSpellLevel;
    final castingMod = controller.getCastingModifier(controller.selectedClassSlug);
    final isDark = theme.brightness == Brightness.dark;

    final limits = SpellAllocationValidator.getLimitsForClass(
      classSlug: controller.selectedClassSlug,
      classLevel: controller.targetClassNewLevel,
      abilityModifier: castingMod,
      subclassSlug: controller.effectiveSubclassSlug,
      edition: edition,
    );

    final bool isMagicalSecretsActive;
    if (edition == DmRulesEdition.v2014) {
      final isLore =
          controller.effectiveSubclassSlug?.toLowerCase().contains('lore') == true;
      final isLore6 = isLore && controller.targetClassNewLevel == 6;
      final isStandardSecrets = controller.selectedClassSlug.toLowerCase() == 'bard' &&
          (controller.targetClassNewLevel == 10 ||
              controller.targetClassNewLevel == 14 ||
              controller.targetClassNewLevel == 18);
      isMagicalSecretsActive = isLore6 || isStandardSecrets;
    } else {
      isMagicalSecretsActive = limits.magicalSecretsCount > 0 ||
          limits.allowedMagicalSecretClasses.isNotEmpty;
    }
    final isMysticArcanumActive = limits.mysticArcanumLevel > 0;
    final alwaysPreparedSpells =
        SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: controller.selectedClassSlug,
      subclassSlug: controller.effectiveSubclassSlug,
      classLevel: controller.targetClassNewLevel,
      edition: edition,
    );

    // Filter spells based on class list, active Magical Secrets, or specific cross-list browsing
    final allClassSpells = SpellbookLibrary.allSpells.where((s) {
      if (s.level > maxLvl) return false;

      if (controller.showAllSpellListsForSecrets) {
        return true;
      }

      final activeClassFilter = controller.selectedSpellListSource ?? defaultSpellClass;
      if (activeClassFilter == null) return s.level <= maxLvl;

      final rules = s.getRules(edition);
      final isClassSpell = rules.classes.contains(activeClassFilter);
      final isExpanded = SubclassSpellsLibrary.isExpandedSpell(
          controller.selectedClassSlug, controller.effectiveSubclassSlug, s, edition);
      return isClassSpell || isExpanded;
    }).toList();

    final filtered = allClassSpells.where((s) {
      if (controller.spellSearchQuery.isEmpty) return true;
      final q = controller.spellSearchQuery.toLowerCase();
      return s.getName(edition).toLowerCase().contains(q) ||
          s.id.slug.toLowerCase().contains(q);
    }).toList();

    final existingCantripSlugs = <String>{};
    for (final c in controller.character.cantrips) {
      existingCantripSlugs.add(c.slug.toLowerCase().trim());
      existingCantripSlugs.add(c.displayName.toLowerCase().trim());
    }
    final availableCantrips = filtered.where((s) {
      if (s.level != 0) return false;
      final id = s.id.slug.toLowerCase().trim();
      final name = s.getName(edition).toLowerCase().trim();
      return !existingCantripSlugs.contains(id) &&
          !existingCantripSlugs.contains(name);
    }).toList();

    final existingKnownOrPrepared = <String>{};
    for (final s in controller.character.spellsKnown) {
      if (controller.replacedSpellId != null &&
          (controller.replacedSpellId == s.slug || controller.replacedSpellId == s.displayName)) {
        continue;
      }
      existingKnownOrPrepared.add(s.slug.toLowerCase().trim());
      existingKnownOrPrepared.add(s.displayName.toLowerCase().trim());
    }
    for (final s in controller.character.spellsPrepared) {
      if (controller.replacedSpellId != null &&
          (controller.replacedSpellId == s.slug || controller.replacedSpellId == s.displayName)) {
        continue;
      }
      existingKnownOrPrepared.add(s.slug.toLowerCase().trim());
      existingKnownOrPrepared.add(s.displayName.toLowerCase().trim());
    }
    for (final s in alwaysPreparedSpells) {
      existingKnownOrPrepared.add(s.id.slug.toLowerCase().trim());
      existingKnownOrPrepared.add(s.getName(edition).toLowerCase().trim());
    }

    final availableLeveled = filtered.where((s) {
      if (s.level <= 0) return false;
      final id = s.id.slug.toLowerCase().trim();
      final name = s.getName(edition).toLowerCase().trim();
      return !existingKnownOrPrepared.contains(id) &&
          !existingKnownOrPrepared.contains(name);
    }).toList();

    final previousClassLevel = math.max(0, controller.targetClassNewLevel - 1);
    final previousLimits = previousClassLevel > 0
        ? SpellAllocationValidator.getLimitsForClass(
            classSlug: controller.selectedClassSlug,
            classLevel: previousClassLevel,
            abilityModifier: castingMod,
            subclassSlug: controller.effectiveSubclassSlug,
            edition: edition,
          )
        : const SpellAllocationLimits.nonCaster();

    final isMysticArcanumMilestone =
        controller.selectedClassSlug.toLowerCase() == 'warlock' &&
            limits.mysticArcanumLevel > previousLimits.mysticArcanumLevel;

    final availableMysticArcanumSpells = isMysticArcanumMilestone
        ? SpellbookLibrary.allSpells.where((s) {
            if (s.level != limits.mysticArcanumLevel) return false;
            final id = s.id.slug.toLowerCase().trim();
            final name = s.getName(edition).toLowerCase().trim();
            if (existingKnownOrPrepared.contains(id) ||
                existingKnownOrPrepared.contains(name)) {
              return false;
            }
            final rules = s.getRules(edition);
            final isWarlock = rules.classes.contains(SpellClass.warlock);
            final isExpanded = SubclassSpellsLibrary.isExpandedSpell(
              controller.selectedClassSlug,
              controller.effectiveSubclassSlug,
              s,
              edition,
            );
            return isWarlock || isExpanded;
          }).toList()
        : <Spell>[];

    final filteredMysticArcanumSpells = availableMysticArcanumSpells.where((s) {
      if (controller.spellSearchQuery.isEmpty) return true;
      final q = controller.spellSearchQuery.toLowerCase();
      return s.getName(edition).toLowerCase().contains(q) ||
          s.id.slug.toLowerCase().contains(q);
    }).toList();

    final gainedCantripsProgression =
        math.max(0, limits.maxCantrips - previousLimits.maxCantrips);
    final gainedSpellsProgression =
        math.max(0, limits.maxSpellsKnown - previousLimits.maxSpellsKnown);

    final curCantripsCount = controller.character.cantrips.length;
    final maxAllowedNewCantrips = math.max(
        gainedCantripsProgression, limits.maxCantrips - curCantripsCount);

    final isWizard = controller.selectedClassSlug.toLowerCase() == 'wizard';
    final isSpontaneous =
        limits.maxSpellsKnown > 0 && limits.maxSpellsPrepared == 0;

    int maxAllowedNewSpells;
    if (isWizard) {
      maxAllowedNewSpells = controller.targetClassNewLevel == 1
          ? limits.maxSpellbookInitialScribe // 6
          : limits.maxSpellbookLevelUpScribe; // 2
    } else if (isSpontaneous) {
      final isReplacing = controller.replacedSpellId != null;
      final curKnownCount = controller.character.spellsKnown.length;
      final catchUpDelta = math.max(0, limits.maxSpellsKnown - curKnownCount);
      final baseNewSpells = math.max(gainedSpellsProgression, catchUpDelta);
      maxAllowedNewSpells = baseNewSpells + (isReplacing ? 1 : 0);
    } else {
      // Prepared casters
      final curPrepCount = controller.character.spellsPrepared.length;
      final delta = math.max(0, limits.maxSpellsPrepared - curPrepCount);
      maxAllowedNewSpells =
          math.max(1, delta + (controller.replacedSpellId != null ? 1 : 0));
    }

    final targetClassKey = 'class-${controller.selectedClassSlug}-spells';
    final classAllocated = controller.character.allocatedSpells[targetClassKey];
    final List<EntityReference<Spell>> baseReplaceable;
    if (classAllocated != null && classAllocated.isNotEmpty) {
      baseReplaceable = classAllocated;
    } else if (controller.character.spellsKnown.isNotEmpty) {
      baseReplaceable = controller.character.spellsKnown;
    } else {
      baseReplaceable = controller.character.spellsPrepared;
    }
    // Exclude Mystic Arcanum or spells above max level tier
    final replaceableSpells = baseReplaceable.where((s) {
      final spellItem = SpellbookLibrary.getSpellById(s.slug) ??
          SpellbookLibrary.findSpell(s.displayName);
      if (spellItem != null &&
          controller.selectedClassSlug.toLowerCase() == 'warlock' &&
          spellItem.level >= 6) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Spells & Cantrips Advancement',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.purpleAccent),
              ),
            ),
            if (isMagicalSecretsActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 12, color: Colors.amberAccent),
                    SizedBox(width: 4),
                    Text(
                      'MAGICAL SECRETS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select newly learned, prepared, or subclass spells for ${controller.selectedClassSlug} (Max Spell Level: $maxLvl).',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Quota for Level ${controller.targetClassNewLevel}: ${controller.newSpells.length}/$maxAllowedNewSpells New Leveled Spell(s)${maxAllowedNewCantrips > 0 ? ", ${controller.newCantrips.length}/$maxAllowedNewCantrips New Cantrip(s)" : ", 0 New Cantrips allowed ($curCantripsCount/${limits.maxCantrips} already known)"}${isMysticArcanumMilestone ? " + 1 Mystic Arcanum (Level ${limits.mysticArcanumLevel})" : ""}.',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent),
        ),
        const SizedBox(height: 12),

        // Subclass Always-Prepared Spells Alert Card
        if (alwaysPreparedSpells.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified,
                        size: 14, color: Colors.tealAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Subclass Granted Spells (Always Prepared, Free Quota):',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: alwaysPreparedSpells.map((s) {
                    return ActionChip(
                      avatar: DndGlyph.spell(
                          school: s.resolvedSchool,
                          level: s.level,
                          size: 14,
                          isDarkMode: true),
                      visualDensity: VisualDensity.compact,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${s.getName(edition)} (L${s.level})',
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline,
                              size: 12, color: Colors.tealAccent),
                        ],
                      ),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        SpellComparisonDialog.show(
                          context,
                          spell: s,
                          edition: edition,
                          isPinned: false,
                          onTogglePin: () {},
                        );
                      },
                      backgroundColor:
                          Colors.teal.shade800.withValues(alpha: 0.4),
                      side: BorderSide(
                          color: Colors.tealAccent.withValues(alpha: 0.3)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Spell Replacement (Spell Swapping) Section for Spontaneous / Known Casters
        if (isSpontaneous && replaceableSpells.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz,
                        size: 16, color: Colors.amberAccent),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Replace a Known Spell (Optional - 1 per level-up):',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent),
                      ),
                    ),
                    if (controller.replacedSpellId != null)
                      TextButton(
                        onPressed: () =>
                            controller.mutate(() => controller.replacedSpellId = null),
                        child: const Text('Cancel Swap',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amberAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  controller.replacedSpellId == null
                      ? 'You may swap one existing spell you know for a new one from your spell list.'
                      : 'Selected spell will be forgotten and replaced with your new selection below.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: replaceableSpells.map((s) {
                    final isReplaced = controller.replacedSpellId == s.slug;
                    final spellItem = SpellbookLibrary.getSpellById(s.slug) ??
                        SpellbookLibrary.findSpell(s.displayName);
                    return Container(
                      decoration: BoxDecoration(
                        color: isReplaced
                            ? Colors.redAccent.withValues(alpha: 0.25)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isReplaced
                              ? Colors.redAccent
                              : Colors.amberAccent.withValues(alpha: 0.4),
                          width: isReplaced ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(8),
                              right: Radius.circular(spellItem != null ? 0 : 8),
                            ),
                            onTap: () {
                              HapticService.selectionTick(context);
                              controller.mutate(() {
                                controller.replacedSpellId = isReplaced ? null : s.slug;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isReplaced)
                                    const Icon(Icons.close,
                                        size: 13, color: Colors.redAccent)
                                  else
                                    const Icon(Icons.swap_horiz,
                                        size: 13, color: Colors.amberAccent),
                                  const SizedBox(width: 5),
                                  Text(
                                    isReplaced
                                        ? 'Replacing: ${s.displayName}'
                                        : s.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isReplaced
                                          ? Colors.redAccent
                                          : Colors.white,
                                      decoration: isReplaced
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (spellItem != null) ...[
                            Container(
                              width: 1,
                              height: 16,
                              color: Colors.amberAccent.withValues(alpha: 0.3),
                            ),
                            Tooltip(
                              message: 'Spell info: ${s.displayName}',
                              child: InkWell(
                                key: Key('replaceable_spell_info_${s.slug}'),
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(8)),
                                onTap: () {
                                  HapticService.selectionTick(context);
                                  SpellComparisonDialog.show(
                                    context,
                                    spell: spellItem,
                                    edition: edition,
                                    isPinned: false,
                                    onTogglePin: () {},
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 5),
                                  child: Icon(Icons.info_outline,
                                      size: 13, color: Colors.amberAccent),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Mystic Arcanum Milestone Callout & Selection
        if (isMysticArcanumActive) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade900.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.deepPurpleAccent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.deepPurpleAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mystic Arcanum Milestone (Level ${limits.mysticArcanumLevel} Spell)',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.deepPurpleAccent),
                          ),
                          Text(
                            'Choose one Level ${limits.mysticArcanumLevel} Warlock spell. You can cast it once per long rest without expending a spell slot. This does NOT consume your normal spell known quota.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isMysticArcanumMilestone) ...[
                  const SizedBox(height: 10),
                  const Divider(color: Colors.deepPurpleAccent, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Mystic Arcanum Spell:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        controller.selectedMysticArcanumSpellId != null
                            ? '1/1 Arcanum Selected'
                            : '0/1 Arcanum Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: controller.selectedMysticArcanumSpellId != null
                              ? Colors.amberAccent
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (filteredMysticArcanumSpells.isEmpty)
                    Text(
                      'No matching level ${limits.mysticArcanumLevel} Warlock spells found.',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          fontStyle: FontStyle.italic),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredMysticArcanumSpells.map((s) {
                        final isSelected =
                            controller.selectedMysticArcanumSpellId == s.id.slug;
                        return ChoiceChip(
                          avatar: DndGlyph.spell(
                            school: s.resolvedSchool,
                            level: s.level,
                            size: 16,
                            isDarkMode: true,
                          ),
                          label: Text(s.getName(edition)),
                          selected: isSelected,
                          selectedColor: Colors.deepPurpleAccent.shade700,
                          onSelected: (selected) {
                            controller.mutate(() {
                              controller.selectedMysticArcanumSpellId =
                                  selected ? s.id.slug : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Magical Secrets List Switcher Bar
        if (isMagicalSecretsActive) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Spell List: ',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ChoiceChip(
                  label: const Text('Bard List'),
                  selected: controller.selectedSpellListSource == null &&
                      !controller.showAllSpellListsForSecrets,
                  onSelected: (selected) {
                    controller.mutate(() {
                      controller.selectedSpellListSource = null;
                      controller.showAllSpellListsForSecrets = false;
                    });
                  },
                ),
                for (final sc in const [
                  SpellClass.wizard,
                  SpellClass.cleric,
                  SpellClass.druid,
                ])
                  if (limits.allowedMagicalSecretClasses.contains(sc)) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(sc.label),
                      selected: controller.selectedSpellListSource == sc,
                      onSelected: (selected) {
                        controller.mutate(() {
                          controller.selectedSpellListSource = selected ? sc : null;
                          controller.showAllSpellListsForSecrets = false;
                        });
                      },
                    ),
                  ],
                const SizedBox(width: 6),
                if (limits.allowedMagicalSecretClasses.length > 4 ||
                    edition == DmRulesEdition.v2014)
                  ChoiceChip(
                    label: const Text('All Spell Lists ✨'),
                    selected: controller.showAllSpellListsForSecrets,
                    onSelected: (selected) {
                      controller.mutate(() {
                        controller.showAllSpellListsForSecrets = selected;
                        controller.selectedSpellListSource = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        LevelUpSpellsLists(
          controller: controller,
          customColors: customColors,
          edition: edition,
          limits: limits,
          isDark: isDark,
          isMagicalSecretsActive: isMagicalSecretsActive,
          isMysticArcanumActive: isMysticArcanumActive,
          maxLvl: maxLvl,
          curCantripsCount: curCantripsCount,
          maxAllowedNewCantrips: maxAllowedNewCantrips,
          maxAllowedNewSpells: maxAllowedNewSpells,
          availableCantrips: availableCantrips,
          availableLeveled: availableLeveled,
        ),
      ],
    );
  }
}
