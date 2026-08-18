import 'package:flutter/material.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../theme/app_theme.dart';
import 'dialogs/creature_stat_block_dialog.dart';
import 'glyphs/dnd_glyph.dart';

class SpellReferenceWidget extends StatefulWidget {
  final SummonPreset? initialPreset;

  const SpellReferenceWidget({super.key, this.initialPreset});

  @override
  State<SpellReferenceWidget> createState() => _SpellReferenceWidgetState();
}

class _SpellReferenceWidgetState extends State<SpellReferenceWidget> {
  late SummonPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset =
        widget.initialPreset ?? SrdSummonsLibrary.allPresets.first;
  }

  @override
  void didUpdateWidget(covariant SpellReferenceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPreset != null &&
        widget.initialPreset != oldWidget.initialPreset) {
      setState(() {
        _selectedPreset = widget.initialPreset!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _selectedPreset;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F2B96), Color(0xFFA8C0FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DndGlyph.spell(
                      school: p.glyphSchool,
                      level: p.glyphSpellLevel,
                      actionRings: p.glyphActionRings,
                      size: 48,
                      isDarkMode: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.levelDisplay} | ${p.castingTime}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Range: ${p.range} | Components: ${p.components} | Duration: ${p.duration}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Spell Description
          Text(
            'SPELL / ITEM DESCRIPTION',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            p.description,
            style: TextStyle(color: theme.colorScheme.onSurface, height: 1.4),
          ),
          const SizedBox(height: 12),

          Text(
            'UPCASTING & SCALING RULES',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            p.upcastRules,
            style: TextStyle(color: theme.colorScheme.onSurface, height: 1.4),
          ),
          const SizedBox(height: 20),

          // RAW Stat Blocks / Creature Profiles
          Text(
            '${p.name.toUpperCase()} CREATURE PROFILES',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.statBlocks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _buildCreatureProfileCard(p.statBlocks[i]),
          ),
          const SizedBox(height: 20),

          // Tactical Tips
          Text(
            '💡 TACTICAL TIPS & RAW CLARIFICATIONS',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildTipCard(
            'SRD 5.1 & SRD 5.2 Legal Notice',
            'All text, formulas, and creature stats above are strictly taken from the SRD 5.1 and SRD 5.2 under Creative Commons CC-BY-4.0 attribution.',
          ),
          _buildTipCard(
            'Action Economy & Squad Management',
            'Summoning multiple creatures allows you to split attacks, control space, absorb incoming damage, or trigger Pack Tactics for team advantage!',
          ),
        ],
      ),
    );
  }

  Widget _buildCreatureProfileCard(MinionStatBlock sb) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ??
        (isDark ? TabletopColors.dark : TabletopColors.light);
    final accentColor = sb.accentColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tabletop.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    DndGlyph.monster(
                      creatureType: sb.glyphCreatureType,
                      crTier: sb.glyphCrTier,
                      actionRings: sb.glyphActionRings,
                      size: 32,
                      isDarkMode: isDark,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        sb.name,
                        style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${sb.sizeDisplay} • ${sb.crDisplay}',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Semantics(
                      button: true,
                      label: 'View ${sb.name} Full Creature Stat Block',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => CreatureStatBlockDialog.show(context,
                            statBlock: sb),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: accentColor.withValues(alpha: 0.6),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book,
                                  size: 14, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                'STAT BLOCK',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stat Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCombatBadge('HP', '${sb.maxHp}',
                  isDark ? Colors.greenAccent : const Color(0xFF047857),
                  semanticName: 'Hit Points'),
              _buildCombatBadge('AC', '${sb.ac}',
                  isDark ? Colors.lightBlueAccent : const Color(0xFF0369A1),
                  semanticName: 'Armor Class'),
              _buildCombatBadge('ATK', '+${sb.attackBonus}',
                  isDark ? Colors.amberAccent : const Color(0xFFB45309),
                  semanticName: 'Attack Bonus'),
              _buildCombatBadge('DMG', sb.fullDamageFormula,
                  isDark ? Colors.orangeAccent : const Color(0xFFC2410C),
                  semanticName: 'Damage Formula'),
            ],
          ),
          if (sb.specialTrait != null || sb.hasPackTactics) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.purple.withValues(alpha: 0.15)
                    : theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: isDark
                        ? Colors.purpleAccent.withValues(alpha: 0.3)
                        : theme.colorScheme.secondary.withValues(alpha: 0.3)),
              ),
              child: Text(
                '⚡ ${sb.specialTrait ?? "Pack Tactics (Advantage when allies within 5ft)"}',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE1BEE7)
                        : theme.colorScheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCombatBadge(String label, String val, Color color,
      {required String semanticName}) {
    return Semantics(
      label: '$semanticName: $val',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: val,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(String title, String body) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ??
        (isDark ? TabletopColors.dark : TabletopColors.light);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tabletop.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tabletop.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(body,
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.3)),
        ],
      ),
    );
  }
}
