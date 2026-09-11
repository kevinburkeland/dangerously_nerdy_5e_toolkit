import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/spellbook_data.dart';
import '../../providers/character_sheet_controller.dart';
import '../common/edition_diff_badge.dart';
import '../glyphs/dnd_glyph.dart';
import '../interactive/pressable_card.dart';
import 'spell_upcast_sheet.dart';

/// Modular, interactive card presenting an individual SRD spell.
class SpellCard extends StatelessWidget {
  final SpellItem spell;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final void Function(String formula, String label)? onQuickRoll;
  final VoidCallback? onOpenQuickRoll;
  final CharacterSheetController? controller;
  final void Function(int castLevel)? onCast;

  const SpellCard({
    super.key,
    required this.spell,
    required this.edition,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
    this.onQuickRoll,
    this.onOpenQuickRoll,
    this.controller,
    this.onCast,
  });

  Spell _buildDomainSpell() {
    final rules = spell.getRules(edition);
    return Spell(
      id: EntityId(
        slug: spell.id,
        ruleset: edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014,
      ),
      name: spell.getName(edition),
      level: spell.level,
      school: (rules.schoolOverride ?? spell.school).name,
      castingTime: CastingTime(
        cost: 1,
        actionType: ActionType.action,
        triggerCondition: rules.castingTime,
      ),
      duration: SpellDuration(
        type: rules.concentration ? DurationType.special : DurationType.instantaneous,
        requiresConcentration: rules.concentration,
        rawText: rules.duration,
      ),
      range: rules.range,
      components: SpellComponents(
        v: rules.components.contains('V'),
        s: rules.components.contains('S'),
        m: rules.components.contains('M'),
        materialDescription: rules.materialDetails?.description,
      ),
      descriptionMarkdown: rules.description.join('\n\n'),
      higherLevelsMarkdown: rules.higherLevels,
      damageMath: (rules.rollFormula != null &&
              rules.rollFormula!.trim().isNotEmpty &&
              rules.rollFormula!.trim().toLowerCase() != 'none')
          ? [
              EvaluationMath(
                diceFormula: rules.rollFormula!,
                damageType: DamageType.values.firstWhere(
                  (d) => d.name.toLowerCase() == (rules.damageOrHealType ?? '').toLowerCase(),
                  orElse: () => DamageType.untyped,
                ),
                scalingFormula: rules.scalingFormula != null
                    ? '+${rules.scalingFormula!.dicePerSlotLevel}d${rules.scalingFormula!.diceSides}'
                    : null,
              )
            ]
          : const [],
      customProperties: {
        if (rules.rollFormula != null) 'rollFormula': rules.rollFormula,
        if (rules.scalingFormula != null)
          'scalingFormula': '+${rules.scalingFormula!.dicePerSlotLevel}d${rules.scalingFormula!.diceSides}',
      },
    );
  }

  Future<void> _handleCast(BuildContext context) async {
    final spellName = spell.getName(edition);
    if (spell.level == 0) {
      // Cantrips roll immediately without prompting bottom sheet
      if (onCast != null) {
        onCast!(0);
      } else if (controller != null) {
        final domainSpell = _buildDomainSpell();
        await controller!.castSpell(domainSpell, castLevel: 0);
      }
      return;
    }

    final resources = controller?.character.resources ?? const CharacterResourcePool();
    final pool = resources.spellSlots;
    final hasRegularSlots = pool.maxSlots.entries.any((e) => e.key >= spell.level && e.value > 0);
    final hasPactSlots = pool.pactMagicMax > 0 && pool.pactMagicSlotLevel >= spell.level;

    if (!hasRegularSlots && !hasPactSlots) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pool.pactMagicMax > 0
                  ? 'Spell level (${spell.level}) exceeds Pact Magic slot level (${pool.pactMagicSlotLevel}).'
                  : 'No spell slots available for Level ${spell.level}+ spells.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    int chosenSlot;
    bool isPactMagic = false;

    // If character ONLY has Pact Magic for this spell (pure Warlock):
    // Auto upcast to the Warlock's spell level without prompting!
    if (!hasRegularSlots && hasPactSlots) {
      if (pool.pactMagicCurrent <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No Pact Magic slots remaining for $spellName (recharges on a Short or Long Rest).',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      chosenSlot = pool.pactMagicSlotLevel;
      isPactMagic = true;
    } else {
      final selection = await SpellUpcastSheet.show(
        context,
        spellName: spellName,
        spellLevel: spell.level,
        resources: resources,
      );

      if (selection == null) {
        // Dismissed without selection
        return;
      }
      chosenSlot = selection.slotLevel;
      isPactMagic = selection.isPactMagic;
    }

    if (onCast != null) {
      onCast!(chosenSlot);
    } else if (controller != null) {
      final domainSpell = _buildDomainSpell();
      await controller!.castSpell(
        domainSpell,
        castLevel: chosenSlot,
        isPactMagic: isPactMagic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rules = spell.getRules(edition);
    final effectiveSchool = spell.getSchool(edition);
    final schoolColor = effectiveSchool.getLegibleColor(isDark);
    final glyphRings = spell.getGlyphActionRings(edition);
    final visibleGlyphRings = glyphRings
        .where((ring) => !(rules.concentration &&
            ring.ringType == ActionRingType.concentration))
        .toList(growable: false);
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final cardBorderColor = isPinned
        ? pinColor.withValues(alpha: 0.85)
        : schoolColor.withValues(alpha: 0.35);

    // Format casting time cleanly for reactions
    final castingTimeDisplay = rules.castingTime.startsWith('1 Reaction')
        ? '1 Reaction'
        : (rules.castingTime.startsWith('1 Bonus Action')
            ? '1 Bonus Action'
            : (rules.castingTime.startsWith('1 Action')
                ? '1 Action'
                : rules.castingTime));

    return PressableCard(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cardBorderColor,
          width: isPinned ? 1.6 : 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: DndGlyph HUD + Title & School + Diff Badge + Pin Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DndGlyph.spell(
                school: effectiveSchool,
                level: spell.level,
                actionRings: glyphRings,
                size: 38,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spell.getName(edition),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      spell.getFullTypeLabel(edition),
                      style: TextStyle(
                        color: schoolColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (spell.isChangedIn2024) ...[
                const EditionDiffBadge(),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(
                  isPinned ? Icons.bookmark : Icons.bookmark_border,
                  color:
                      isPinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: isPinned
                    ? 'Remove from Personal Spellbook'
                    : 'Pin to Personal Spellbook',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onTogglePin,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Metadata badges row (Casting time, Range, Duration, Concentration, Ritual)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildBadge(context, Icons.timer_outlined, castingTimeDisplay,
                  schoolColor),
              _buildBadge(context, Icons.my_location_outlined, rules.range,
                  schoolColor),
              _buildBadge(context, Icons.hourglass_empty_outlined,
                  rules.duration, schoolColor),
              if (rules.concentration)
                _buildTag('Concentration',
                    isDark ? Colors.amberAccent : const Color(0xFFB45309)),
              if (rules.ritual)
                _buildTag('Ritual',
                    isDark ? Colors.cyanAccent : const Color(0xFF0E7490)),
              if (rules.materialDetails?.hasCost == true)
                _buildTag(
                    '💰 ${rules.materialDetails!.costInGp} gp', diffColor),
              if (rules.savingThrow != null)
                _buildTag('${rules.savingThrow} Save',
                    isDark ? Colors.orangeAccent : const Color(0xFFC2410C)),
              if (rules.damageOrHealType != null)
                _buildTag(rules.damageOrHealType!, schoolColor),
            ],
          ),
          const SizedBox(height: 8),

          if (visibleGlyphRings.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: visibleGlyphRings.map((r) {
                final ringLabel = r.damageLegend.isNotEmpty
                    ? '${r.ringType.displayName} • ${r.damageLegend}'
                    : r.ringType.displayName;
                final ringColor =
                    r.getEffectiveColor(schoolColor, isDarkMode: isDark);
                return _buildTag(ringLabel, ringColor);
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // Reaction trigger note if applicable
          if (rules.reactionTrigger != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? Colors.blueAccent : const Color(0xFF1D4ED8))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color:
                        (isDark ? Colors.blueAccent : const Color(0xFF1D4ED8))
                            .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on,
                      size: 12,
                      color:
                          isDark ? Colors.blueAccent : const Color(0xFF1D4ED8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Trigger: ${rules.reactionTrigger!}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF90CAF9)
                            : const Color(0xFF1E40AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description snippet
          Text(
            rules.description.first,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Bar: Class Tags + Quick Roll button + Compare button
          Row(
            children: [
              // Classes list
              Expanded(
                child: Text(
                  rules.classes.map((c) => c.label).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Cast Action Button
              if (onCast != null || controller != null) ...[
                Semantics(
                  button: true,
                  label: 'Cast ${spell.getName(edition)}',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _handleCast(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12),
                          SizedBox(width: 4),
                          Text('Cast', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Quick Roll Action Button (if formula exists)
              if (rules.rollFormula != null &&
                  rules.rollFormula!.trim().isNotEmpty &&
                  rules.rollFormula!.trim().toLowerCase() != 'none' &&
                  onOpenQuickRoll != null) ...[
                InkWell(
                  onTap: onOpenQuickRoll,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: schoolColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: schoolColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.casino, size: 12, color: schoolColor),
                        const SizedBox(width: 4),
                        Text(
                          rules.rollFormula ?? 'Roll',
                          style: TextStyle(
                            color: schoolColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // 2014 vs 2024 Compare hint
              if (spell.isChangedIn2024) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Diff',
                      style: TextStyle(
                        color: diffColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.compare_arrows, color: diffColor, size: 13),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
      BuildContext context, IconData icon, String text, Color accentColor) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accentColor.withValues(alpha: 0.9)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
