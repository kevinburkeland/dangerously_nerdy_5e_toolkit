import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

/// Interactive VTT Combat Spell Tile allowing one-tap attack/damage roll execution
/// and modal bottom sheet reference inspection.
class InteractiveSpellTile extends StatelessWidget {
  final Spell spell;
  final CharacterSheetController controller;
  final bool isPrepared;
  final bool isCantrip;
  final VoidCallback? onTogglePrepared;
  final Widget? trailingExtra;

  const InteractiveSpellTile({
    super.key,
    required this.spell,
    required this.controller,
    this.isPrepared = false,
    this.isCantrip = false,
    this.onTogglePrepared,
    this.trailingExtra,
  });

  bool get hasSpellAttack {
    final desc = spell.descriptionMarkdown.toLowerCase();
    return spell.customProperties['isSpellAttack'] == true ||
        spell.customProperties['hasAttackRoll'] == true ||
        desc.contains('spell attack');
  }

  bool get dealsDamage {
    final desc = spell.descriptionMarkdown.toLowerCase();
    return spell.damageMath.isNotEmpty ||
        spell.customProperties['rollFormula'] != null ||
        desc.contains('damage');
  }

  SpellSchool _resolveSchool(String schoolStr) {
    return SpellSchool.values.firstWhere(
      (s) => s.name.toLowerCase() == schoolStr.toLowerCase() || s.displayName.toLowerCase() == schoolStr.toLowerCase(),
      orElse: () => SpellSchool.evocation,
    );
  }

  void _executeSpellAction(BuildContext context) {
    HapticService.heavyImpact(context);

    if (hasSpellAttack && dealsDamage) {
      final atk = controller.rollSpellAttack(spell);
      final dmg = controller.rollSpellDamage(spell);

      final critStr = atk.isCrit ? ' (CRIT!)' : (atk.isFumble ? ' (FUMBLE!)' : '');
      final summary = '${spell.name}: Attack ${atk.total}$critStr | Damage ${dmg.total} (${dmg.formulaString})';

      A11yService.announce(summary);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary, style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (hasSpellAttack) {
      final atk = controller.rollSpellAttack(spell);
      final critStr = atk.isCrit ? ' (CRIT!)' : (atk.isFumble ? ' (FUMBLE!)' : '');
      final summary = '${spell.name}: Attack ${atk.total}$critStr (1d20+${controller.stats.spellAttackBonus})';

      A11yService.announceRoll(atk);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary, style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (dealsDamage) {
      final dmg = controller.rollSpellDamage(spell);
      final summary = '${spell.name}: Damage ${dmg.total} (${dmg.formulaString})';

      A11yService.announce(summary);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary, style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Utility / Buff / Debuff spell execution
      final summary = 'Cast ${spell.name} (${spell.level == 0 ? "Cantrip" : "Level ${spell.level}"})';
      A11yService.announce(summary);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSpellReferenceModal(BuildContext context) {
    HapticService.selectionTick(context);
    final theme = Theme.of(context);
    final levelLabel = spell.level == 0 ? 'Cantrip' : 'Level ${spell.level} Spell';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header with Accessibility Semantics
                Semantics(
                  header: true,
                  label: 'Spell Details: ${spell.name}',
                  child: Row(
                    children: [
                      DndGlyph.spell(
                        school: _resolveSchool(spell.school),
                        level: spell.level,
                        actionRings: spell.getGlyphActionRings(controller.character.rulesEdition),
                        size: 40,
                        isDarkMode: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spell.name,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$levelLabel • ${spell.school.toUpperCase()}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.purpleAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close spell details',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Spell metadata chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildMetaBadge(theme, Icons.timer_outlined, spell.castingTime.triggerCondition ?? '1 Action'),
                    _buildMetaBadge(theme, Icons.straighten, spell.range),
                    _buildMetaBadge(theme, Icons.hourglass_empty, spell.duration.rawText ?? (spell.duration.requiresConcentration ? 'Concentration' : 'Instantaneous')),
                    if (spell.duration.requiresConcentration)
                      _buildPill(Colors.amber.shade900, 'Concentration'),
                    if (spell.customProperties['ritual'] == true)
                      _buildPill(Colors.teal.shade900, 'Ritual'),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                Text(
                  'DESCRIPTION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                FormattedMarkdownText(
                  spell.descriptionMarkdown,
                  defaultColor: theme.colorScheme.onSurface,
                ),

                if (spell.higherLevelsMarkdown != null && spell.higherLevelsMarkdown!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'AT HIGHER LEVELS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FormattedMarkdownText(
                    spell.higherLevelsMarkdown!,
                    defaultColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
                const SizedBox(height: 16),

                // Action to cast / roll
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.purpleAccent.shade700,
                    ),
                    icon: const Icon(Icons.casino, size: 20),
                    label: Text(hasSpellAttack || dealsDamage ? 'Roll ${spell.name}' : 'Cast ${spell.name}'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _executeSpellAction(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaBadge(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(Color bgColor, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attackStr = hasSpellAttack ? '+${controller.stats.spellAttackBonus} Atk' : null;

    String? damageStr;
    if (dealsDamage) {
      if (spell.damageMath.isNotEmpty) {
        damageStr = spell.damageMath.first.diceFormula;
      } else if (spell.customProperties['rollFormula'] != null) {
        damageStr = spell.customProperties['rollFormula'].toString();
      }
      final slug = spell.id.slug.toLowerCase().replaceAll('_', '-');
      if (slug == 'eldritch-blast' && controller.hasCapabilityFlag('eldritchBlastChaDamage')) {
        final chaMod = controller.character.effectiveAbilityScores.getModifier(AbilityType.charisma);
        damageStr = '$damageStr + $chaMod';
      }
    }

    final tags = <String>[
      if (attackStr != null) attackStr,
      if (damageStr != null) damageStr,
      spell.range,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isPrepared ? Colors.purpleAccent.withValues(alpha: 0.6) : Colors.white12,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _executeSpellAction(context),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: isCantrip
                ? DndGlyph.spell(
                    school: _resolveSchool(spell.school),
                    level: 0,
                    size: 26,
                    isDarkMode: true,
                  )
                : (onTogglePrepared != null
                    ? Semantics(
                        button: true,
                        label: isPrepared ? 'Prepared spell' : 'Unprepared spell',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: IconButton(
                            icon: Icon(
                              isPrepared ? Icons.bookmark : Icons.bookmark_border,
                              color: isPrepared ? Colors.purpleAccent : Colors.white38,
                            ),
                            tooltip: isPrepared ? 'Prepared' : 'Unprepared',
                            onPressed: onTogglePrepared,
                          ),
                        ),
                      )
                    : DndGlyph.spell(
                        school: _resolveSchool(spell.school),
                        level: spell.level,
                        size: 26,
                        isDarkMode: true,
                      )),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    spell.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (spell.duration.requiresConcentration)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.shade900, borderRadius: BorderRadius.circular(4)),
                    child: const Text('C', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text(
              tags,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSpellAttack || dealsDamage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ROLL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: 'Spell Details: ${spell.name}',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      color: theme.colorScheme.primary,
                      tooltip: 'Spell Details',
                      onPressed: () => _showSpellReferenceModal(context),
                    ),
                  ),
                ),
                if (trailingExtra != null) trailingExtra!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
