import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';
import '../glyphs/glyph_tokens.dart';

/// Interactive spell row item for character sheet spell lists with deep reference inspection modals.
class SpellListItem extends StatelessWidget {
  final Spell spell;
  final DmRulesEdition edition;
  final bool isPrepared;
  final VoidCallback? onTogglePrepared;
  final VoidCallback? onCast;

  const SpellListItem({
    super.key,
    required this.spell,
    this.edition = DmRulesEdition.v2024,
    this.isPrepared = false,
    this.onTogglePrepared,
    this.onCast,
  });

  SpellSchool _resolveSchool(String schoolStr) {
    return SpellSchool.values.firstWhere(
      (s) => s.name.toLowerCase() == schoolStr.toLowerCase() || s.displayName.toLowerCase() == schoolStr.toLowerCase(),
      orElse: () => SpellSchool.evocation,
    );
  }

  String _formatCastingTime(CastingTime ct) {
    if (ct.triggerCondition != null && ct.triggerCondition!.isNotEmpty) {
      return '${ct.cost} ${ct.actionType.name} (${ct.triggerCondition})';
    }
    return '${ct.cost} ${ct.actionType.name}';
  }

  String _formatComponents(SpellComponents comp) {
    final parts = <String>[];
    if (comp.v) parts.add('V');
    if (comp.s) parts.add('S');
    if (comp.m) {
      if (comp.materialDescription != null && comp.materialDescription!.isNotEmpty) {
        parts.add('M (${comp.materialDescription})');
      } else {
        parts.add('M');
      }
    }
    return parts.isNotEmpty ? parts.join(', ') : 'None';
  }

  String _formatDuration(SpellDuration dur) {
    String res = dur.rawText ?? dur.type.name;
    if (dur.requiresConcentration) {
      res += ' (Concentration)';
    }
    return res;
  }

  void _showSpellDetailsModal(BuildContext context) {
    HapticService.lightImpact(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final school = _resolveSchool(spell.school);
    final schoolColor = school.getLegibleColor(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Semantics node
                  Semantics(
                    header: true,
                    label: 'Spell Details: ${spell.name}',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: schoolColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: schoolColor.withValues(alpha: 0.5)),
                          ),
                          child: Icon(school.icon, color: schoolColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spell.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${spell.level == 0 ? "Cantrip" : "Level ${spell.level}"} • ${school.displayName}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: schoolColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Spell Stat Grid: Casting Time, Range, Components, Duration
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildMetaPill(context, 'CASTING TIME', _formatCastingTime(spell.castingTime))),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMetaPill(context, 'RANGE', spell.range)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildMetaPill(context, 'COMPONENTS', _formatComponents(spell.components))),
                            const SizedBox(width: 10),
                            Expanded(child: _buildMetaPill(context, 'DURATION', _formatDuration(spell.duration))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Spell Description
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: spell.descriptionMarkdown.trim().isNotEmpty
                          ? FormattedMarkdownText(
                              spell.descriptionMarkdown,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                              fontSize: 14,
                              defaultColor: theme.colorScheme.onSurface,
                              boldColor: schoolColor,
                            )
                          : Text(
                              'No description available.',
                              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetaPill(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '—',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final school = _resolveSchool(spell.school);
    final schoolColor = school.getLegibleColor(isDark);
    final requiresConc = spell.duration.requiresConcentration;

    return Semantics(
      button: true,
      label: 'Spell: ${spell.name}, ${spell.level == 0 ? "Cantrip" : "Level ${spell.level}"}. Tap for details.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSpellDetailsModal(context),
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  // Prepared toggle (if not cantrip)
                  if (spell.level > 0 && onTogglePrepared != null) ...[
                    Semantics(
                      button: true,
                      label: '${isPrepared ? "Unprepare" : "Prepare"} ${spell.name}',
                      child: InkWell(
                        onTap: onTogglePrepared,
                        borderRadius: BorderRadius.circular(6),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          child: Icon(
                            isPrepared ? Icons.bookmark : Icons.bookmark_border,
                            size: 20,
                            color: isPrepared ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // School Icon
                  Icon(school.icon, size: 16, color: schoolColor),
                  const SizedBox(width: 8),
                  // Name and tags
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spell.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isPrepared ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              spell.level == 0 ? 'Cantrip' : 'Lvl ${spell.level}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: schoolColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (requiresConc) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CONC',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Cast / Roll button or Details icon
                  if (onCast != null)
                    Semantics(
                      button: true,
                      label: 'Cast ${spell.name}',
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onCast,
                        child: const Text('Cast', style: TextStyle(fontSize: 11)),
                      ),
                    )
                  else
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
