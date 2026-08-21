import 'package:flutter/material.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../services/haptic_service.dart';
import '../../utils/dice_formatters.dart';
import '../glyphs/dnd_glyph.dart';
import '../monster_codex/creature_dpr_view.dart';

class CreatureStatBlockDialog extends StatefulWidget {
  final MinionStatBlock statBlock;
  final VoidCallback? onAddToSquad;

  const CreatureStatBlockDialog({
    super.key,
    required this.statBlock,
    this.onAddToSquad,
  });

  static Future<void> show(
    BuildContext context, {
    required MinionStatBlock statBlock,
    VoidCallback? onAddToSquad,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => CreatureStatBlockDialog(
        statBlock: statBlock,
        onAddToSquad: onAddToSquad,
      ),
    );
  }

  @override
  State<CreatureStatBlockDialog> createState() => _CreatureStatBlockDialogState();
}

class _CreatureStatBlockDialogState extends State<CreatureStatBlockDialog> {
  bool _isGlyphActive = true;
  int _selectedTabIndex = 0;

  void _toggleGlyphAnimation() {
    HapticService.selectionTick(context);
    setState(() => _isGlyphActive = !_isGlyphActive);
  }

  @override
  Widget build(BuildContext context) {
    final sb = widget.statBlock;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sb.accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: sb.accentColor.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: sb.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '5E SRD CREATURE STAT BLOCK',
                      style: TextStyle(
                        color: sb.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                      tooltip: 'Close stat block',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Navigation Tabs: Stat Block & DPR Calculator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHeaderTabButton(
                        index: 0,
                        label: 'Stat Block',
                        icon: Icons.menu_book,
                        accent: sb.accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeaderTabButton(
                        index: 1,
                        label: 'Damage / DPR',
                        icon: Icons.calculate_outlined,
                        accent: sb.accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Body: Stat Block or DPR View
              Flexible(
                child: _selectedTabIndex == 1
                    ? CreatureDprView(statBlock: sb)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Creature Glyph, Name & Type / Alignment
                            InkWell(
                              onTap: _toggleGlyphAnimation,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                              DndGlyph.monster(
                                creatureType: sb.glyphCreatureType,
                                crTier: sb.glyphCrTier,
                                actionRings: sb.glyphActionRings,
                                size: 64,
                                isDarkMode: true,
                                isActive: _isGlyphActive,
                                onTap: _toggleGlyphAnimation,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sb.name,
                                      style: const TextStyle(
                                        color: Color(0xFFFFD54F), // 5e Monster Manual Gold
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        fontFamily: 'serif',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${sb.sizeDisplay} ${sb.typeDisplay.toLowerCase()}, ${sb.alignment}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      _buildTaperedDivider(sb.accentColor),
                      const SizedBox(height: 10),

                      // 2. AC, HP, Speed
                      _buildKeyValLine(
                        'Armor Class',
                        '${sb.ac}${sb.armorType != null ? " (${sb.armorType})" : ""}',
                      ),
                      _buildKeyValLine(
                        'Hit Points',
                        '${sb.maxHp}${sb.hitDice != null ? " (${sb.hitDice})" : ""}',
                      ),
                      _buildKeyValLine('Speed', sb.speed),

                      const SizedBox(height: 10),
                      _buildTaperedDivider(sb.accentColor),
                      const SizedBox(height: 12),

                      // 3. Ability Scores Grid (STR, DEX, CON, INT, WIS, CHA)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildAbilityScoreBox('STR', sb.strScore, sb.strMod),
                            _buildVerticalDivider(),
                            _buildAbilityScoreBox('DEX', sb.dexScore, sb.dexMod),
                            _buildVerticalDivider(),
                            _buildAbilityScoreBox('CON', sb.conScore, sb.conMod),
                            _buildVerticalDivider(),
                            _buildAbilityScoreBox('INT', sb.intScore, sb.intMod),
                            _buildVerticalDivider(),
                            _buildAbilityScoreBox('WIS', sb.wisScore, sb.wisMod),
                            _buildVerticalDivider(),
                            _buildAbilityScoreBox('CHA', sb.chaScore, sb.chaMod),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      _buildTaperedDivider(sb.accentColor),
                      const SizedBox(height: 10),

                      // 4. Defenses, Senses, Languages, Challenge
                      if (sb.savingThrows != null && sb.savingThrows!.isNotEmpty)
                        _buildKeyValLine('Saving Throws', sb.savingThrows!),
                      if (sb.skills != null && sb.skills!.isNotEmpty)
                        _buildKeyValLine('Skills', sb.skills!),
                      if (sb.damageVulnerabilities != null && sb.damageVulnerabilities!.isNotEmpty)
                        _buildKeyValLine('Damage Vulnerabilities', sb.damageVulnerabilities!),
                      if (sb.damageResistances != null && sb.damageResistances!.isNotEmpty)
                        _buildKeyValLine('Damage Resistances', sb.damageResistances!),
                      if (sb.damageImmunities != null && sb.damageImmunities!.isNotEmpty)
                        _buildKeyValLine('Damage Immunities', sb.damageImmunities!),
                      if (sb.conditionImmunities != null && sb.conditionImmunities!.isNotEmpty)
                        _buildKeyValLine('Condition Immunities', sb.conditionImmunities!),
                      _buildKeyValLine('Senses', sb.senses),
                      _buildKeyValLine('Languages', sb.languages),
                      _buildKeyValLine(
                        'Challenge',
                        '${sb.crDisplay.replaceAll("CR ", "")}${sb.xp != null ? " (${sb.xp} XP)" : ""}',
                      ),

                      // 5. Special Traits
                      if (sb.traits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTaperedDivider(sb.accentColor),
                        const SizedBox(height: 10),
                        for (final trait in sb.traits) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${trait.name}. ',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text: trait.description,
                                    style: const TextStyle(
                                      color: Color(0xE6FFFFFF),
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],

                      // 6. Actions Section
                      if (sb.actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTaperedDivider(sb.accentColor),
                        const SizedBox(height: 8),
                        const Text(
                          'ACTIONS',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final action in sb.actions) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${action.name}. ',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: action.description,
                                        style: const TextStyle(
                                          color: Color(0xE6FFFFFF),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      // 7. Reactions Section
                      if (sb.reactions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTaperedDivider(sb.accentColor),
                        const SizedBox(height: 8),
                        const Text(
                          'REACTIONS',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final reaction in sb.reactions) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${reaction.name}. ',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: reaction.description,
                                        style: const TextStyle(
                                          color: Color(0xE6FFFFFF),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      // 8. Legendary Actions Section
                      if (sb.legendaryActions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTaperedDivider(sb.accentColor),
                        const SizedBox(height: 8),
                        const Text(
                          'LEGENDARY ACTIONS',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The ${sb.name.toLowerCase()} can take 3 legendary actions, choosing from the options below. Only one legendary action option can be used at a time and only at the end of another creature\'s turn. The ${sb.name.toLowerCase()} regains spent legendary actions at the start of its turn.',
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final legAction in sb.legendaryActions) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${legAction.name}. ',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: legAction.description,
                                        style: const TextStyle(
                                          color: Color(0xE6FFFFFF),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CLOSE', style: TextStyle(color: Colors.white70)),
                    ),
                    if (widget.onAddToSquad != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('ADD TO SQUAD'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sb.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          HapticService.mediumImpact(context);
                          Navigator.of(context).pop();
                          widget.onAddToSquad!();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyValLine(String key, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$key ',
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: val,
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _expandAbilityName(String abbr) {
    switch (abbr.toUpperCase()) {
      case 'STR':
        return 'Strength';
      case 'DEX':
        return 'Dexterity';
      case 'CON':
        return 'Constitution';
      case 'INT':
        return 'Intelligence';
      case 'WIS':
        return 'Wisdom';
      case 'CHA':
        return 'Charisma';
      default:
        return abbr;
    }
  }

  Widget _buildAbilityScoreBox(String name, int score, int mod) {
    final modStr = DiceFormatters.formatBonus(mod, includeZero: true);
    final fullName = _expandAbilityName(name);
    final semanticLabel = '$fullName: $score, modifier ${mod >= 0 ? "plus $mod" : "$mod"}';

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$score ($modStr)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildTaperedDivider(Color accent) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            accent.withValues(alpha: 0.8),
            const Color(0xFFFFD54F),
            accent.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTabButton({
    required int index,
    required String label,
    required IconData icon,
    required Color accent,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        HapticService.selectionTick(context);
        setState(() => _selectedTabIndex = index);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFFFFD54F) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFFFD54F) : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

