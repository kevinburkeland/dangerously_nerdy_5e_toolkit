import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/dpr/dpr_models.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/dpr_calculator_engine.dart';

/// Interactive Damage & DPR evaluation view for damaging, scaling, and AoE spells.
class SpellDprView extends StatefulWidget {
  final SpellItem spell;
  final DmRulesEdition edition;

  const SpellDprView({
    super.key,
    required this.spell,
    required this.edition,
  });

  @override
  State<SpellDprView> createState() => _SpellDprViewState();
}

class _SpellDprViewState extends State<SpellDprView> {
  late int _castLevel;
  late int _cantripCharLevel;
  late int _casterAbilityMod;
  late int _casterProfBonus;
  late int _targetSaveBonus;
  late int _targetAc;
  late int _targetCount;
  late AdvantageType _advantage;

  @override
  void initState() {
    super.initState();
    final spell = widget.spell;
    _castLevel = math.max(1, spell.level);
    _cantripCharLevel = 5; // Default Level 5 (Tier 2) for cantrips
    _casterAbilityMod = 4; // Default +4 primary casting stat (18 INT/WIS/CHA)
    _casterProfBonus = 3;  // Default +3 proficiency bonus (Level 5)
    _targetSaveBonus = 2;  // Default +2 average monster save
    _targetAc = 15;        // Default AC 15
    _advantage = AdvantageType.normal;

    // Detect if AoE spell
    final rules = spell.getRules(widget.edition);
    final desc = rules.description.join(' ').toLowerCase();
    final isAoe = desc.contains('cone') ||
        desc.contains('sphere') ||
        desc.contains('line') ||
        desc.contains('cube') ||
        desc.contains('radius') ||
        desc.contains('each creature') ||
        desc.contains('all creatures') ||
        rules.range.toLowerCase().contains('radius') ||
        rules.range.toLowerCase().contains('cone') ||
        rules.range.toLowerCase().contains('sphere');

    _targetCount = isAoe ? 2 : 1;
  }

  int get _saveDc => 8 + _casterProfBonus + _casterAbilityMod;
  int get _spellAttackBonus => _casterProfBonus + _casterAbilityMod;

  void _updateCastLevel(int delta) {
    HapticService.selectionTick(context);
    setState(() {
      final minLvl = math.max(1, widget.spell.level);
      _castLevel = (_castLevel + delta).clamp(minLvl, 9);
    });
  }

  void _updateTargetCount(int delta) {
    HapticService.selectionTick(context);
    setState(() {
      _targetCount = (_targetCount + delta).clamp(1, 12);
    });
  }

  void _setTargetSaveBonus(int bonus) {
    HapticService.selectionTick(context);
    setState(() => _targetSaveBonus = bonus);
  }

  void _setTargetAc(int ac) {
    HapticService.selectionTick(context);
    setState(() => _targetAc = ac.clamp(5, 30));
  }

  /// Resolves the active dice count, sides, and bonus for this spell at the current cast level.
  ({int diceCount, int diceSides, int flatBonus, String formulaStr}) _resolveSpellFormula() {
    final spell = widget.spell;
    final rules = spell.getRules(widget.edition);

    if (spell.level == 0) {
      // Cantrip scaling by character level (1-4: 1x, 5-10: 2x, 11-16: 3x, 17-20: 4x)
      final cantripMult = _cantripCharLevel >= 17 ? 4 : (_cantripCharLevel >= 11 ? 3 : (_cantripCharLevel >= 5 ? 2 : 1));
      final formula = rules.rollFormula ?? '1d10';
      final match = RegExp(r'(\d+)?d(\d+)').firstMatch(formula);
      final baseCount = int.tryParse(match?.group(1) ?? '1') ?? 1;
      final sides = int.tryParse(match?.group(2) ?? '10') ?? 10;
      final totalCount = baseCount * cantripMult;
      return (
        diceCount: totalCount,
        diceSides: sides,
        flatBonus: 0,
        formulaStr: '${totalCount}d$sides',
      );
    }

    if (rules.scalingFormula != null) {
      final sf = rules.scalingFormula!;
      final formulaStr = sf.getFormulaForSlot(spell.level, _castLevel);
      final match = RegExp(r'(\d+)d(\d+)').firstMatch(formulaStr);
      final dCount = int.tryParse(match?.group(1) ?? '${sf.baseDiceCount}') ?? sf.baseDiceCount;
      final dSides = int.tryParse(match?.group(2) ?? '${sf.diceSides}') ?? sf.diceSides;
      final bonus = sf.addsAbilityMod ? _casterAbilityMod : sf.staticBonus;
      return (
        diceCount: dCount,
        diceSides: dSides,
        flatBonus: bonus,
        formulaStr: formulaStr.replaceAll('mod', '$_casterAbilityMod'),
      );
    }

    // Standard upcast extraction (+1 die per slot level over base)
    final formula = rules.rollFormula ?? '1d8';
    final match = RegExp(r'(\d+)d(\d+)').firstMatch(formula);
    if (match != null) {
      final baseCount = int.tryParse(match.group(1) ?? '1') ?? 1;
      final sides = int.tryParse(match.group(2) ?? '8') ?? 8;
      final extraSlots = _castLevel - spell.level;
      final totalCount = (baseCount + math.max(0, extraSlots)).toInt();
      return (
        diceCount: totalCount,
        diceSides: sides,
        flatBonus: 0,
        formulaStr: '${totalCount}d$sides',
      );
    }

    return (
      diceCount: 1,
      diceSides: 8,
      flatBonus: 0,
      formulaStr: '1d8',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spell = widget.spell;
    final rules = spell.getRules(widget.edition);
    final schoolColor = spell.school.getLegibleColor(isDark);

    final isSavingThrow = rules.savingThrow != null && rules.savingThrow!.isNotEmpty;
    final formulaInfo = _resolveSpellFormula();

    // Calculate expected damage per target and total damage
    final avgDieValue = (formulaInfo.diceSides + 1) / 2.0;
    final fullDamage = (formulaInfo.diceCount * avgDieValue) + formulaInfo.flatBonus;

    double successRate = 0.0; // Fail rate for save, Hit rate for attack
    double critRate = 0.0;
    double expectedPerTarget = 0.0;

    if (isSavingThrow) {
      final failProb = DprCalculatorEngine.calculateSaveFailureProbability(
        saveDc: _saveDc,
        targetSaveBonus: _targetSaveBonus,
        targetHasAdvantage: _advantage == AdvantageType.disadvantage,
        targetHasDisadvantage: _advantage == AdvantageType.advantage,
      );
      final passProb = 1.0 - failProb;
      successRate = failProb;
      // Spells with save for half
      expectedPerTarget = (fullDamage * failProb) + ((fullDamage * 0.5) * passProb);
    } else {
      final hitProb = DprCalculatorEngine.calculateHitProbability(
        _spellAttackBonus.toDouble(),
        _targetAc,
        _advantage,
      );
      final critProb = DprCalculatorEngine.calculateCritProbability(_advantage);
      successRate = hitProb;
      critRate = critProb;
      final critDamage = (formulaInfo.diceCount * 2 * avgDieValue) + formulaInfo.flatBonus;
      expectedPerTarget = (hitProb * fullDamage) + (critProb * critDamage);
    }

    final totalDpr = expectedPerTarget * _targetCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Damage Summary Card
          _buildHeroCard(
            context,
            totalDpr: totalDpr,
            expectedPerTarget: expectedPerTarget,
            fullDamage: fullDamage,
            formulaStr: formulaInfo.formulaStr,
            isSavingThrow: isSavingThrow,
            successRate: successRate,
            critRate: critRate,
            schoolColor: schoolColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 2. Spell Level / Upcast Slot Control
          if (spell.level > 0) ...[
            _buildUpcastSlotCard(
              context,
              schoolColor: schoolColor,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ] else ...[
            _buildCantripTierCard(
              context,
              schoolColor: schoolColor,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ],

          // 3. Caster Stats & Target Parameters
          _buildCasterAndTargetCard(
            context,
            isSavingThrow: isSavingThrow,
            schoolColor: schoolColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 4. AoE Target Multiplier Control
          _buildTargetCountCard(
            context,
            schoolColor: schoolColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required double totalDpr,
    required double expectedPerTarget,
    required double fullDamage,
    required String formulaStr,
    required bool isSavingThrow,
    required double successRate,
    required double critRate,
    required Color schoolColor,
    required bool isDark,
  }) {
    final damageType = widget.spell.getRules(widget.edition).damageOrHealType ?? 'Damage';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF2A2242),
                  const Color(0xFF1E1730),
                ]
              : [
                  schoolColor.withValues(alpha: 0.12),
                  schoolColor.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: schoolColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPECTED OUTPUT (${widget.spell.level == 0 ? "CANTRIP" : "SLOT LVL $_castLevel"})',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalDpr.toStringAsFixed(1),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFFD54F) : schoolColor,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AVG DMG',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$formulaStr $damageType',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fullDamage.toStringAsFixed(1)} max on fail',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSavingThrow
                    ? 'DC $_saveDc • ${(successRate * 100).toStringAsFixed(0)}% fail rate (${(expectedPerTarget).toStringAsFixed(1)} / target)'
                    : '+$_spellAttackBonus to hit • ${(successRate * 100).toStringAsFixed(0)}% hit (${(expectedPerTarget).toStringAsFixed(1)} / target)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (_targetCount > 1)
                Text(
                  '× $_targetCount targets',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcastSlotCard(
    BuildContext context, {
    required Color schoolColor,
    required bool isDark,
  }) {
    final baseLvl = widget.spell.level;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upgrade, size: 18, color: Color(0xFF60A5FA)),
              const SizedBox(width: 6),
              Text(
                'Casting Spell Slot Level: ',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Level $_castLevel',
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: 'Lower slot level',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _updateCastLevel(-1),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Higher slot level',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _updateCastLevel(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int lvl = baseLvl; lvl <= 9; lvl++)
                ChoiceChip(
                  label: Text('Level $lvl${lvl == baseLvl ? " (Base)" : ""}'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _castLevel == lvl
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selected: _castLevel == lvl,
                  selectedColor: schoolColor.withValues(alpha: 0.35),
                  onSelected: (sel) {
                    if (sel) {
                      HapticService.selectionTick(context);
                      setState(() => _castLevel = lvl);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCantripTierCard(
    BuildContext context, {
    required Color schoolColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: Colors.purpleAccent),
              const SizedBox(width: 6),
              Text(
                'Character Tier Scaling: ',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tier in [(lvl: 1, label: 'Lvl 1-4 (1 die)'), (lvl: 5, label: 'Lvl 5-10 (2 dice)'), (lvl: 11, label: 'Lvl 11-16 (3 dice)'), (lvl: 17, label: 'Lvl 17+ (4 dice)')])
                ChoiceChip(
                  label: Text(tier.label),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _cantripCharLevel == tier.lvl
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selected: _cantripCharLevel == tier.lvl,
                  selectedColor: schoolColor.withValues(alpha: 0.35),
                  onSelected: (sel) {
                    if (sel) {
                      HapticService.selectionTick(context);
                      setState(() => _cantripCharLevel = tier.lvl);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCasterAndTargetCard(
    BuildContext context, {
    required bool isSavingThrow,
    required Color schoolColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSavingThrow ? Icons.sports_kabaddi_outlined : Icons.shield_outlined,
                size: 18,
                color: const Color(0xFFA78BFA),
              ),
              const SizedBox(width: 6),
              Text(
                isSavingThrow
                    ? 'Target Saving Throw Mod (+$_targetSaveBonus):'
                    : 'Target Armor Class (AC $_targetAc):',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSavingThrow) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final bonus in [-1, 0, 2, 4, 6, 8])
                  ChoiceChip(
                    label: Text('+${bonus >= 0 ? bonus : bonus}${bonus == 2 ? " (Avg)" : ""}'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _targetSaveBonus == bonus
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    selected: _targetSaveBonus == bonus,
                    selectedColor: schoolColor.withValues(alpha: 0.35),
                    onSelected: (sel) {
                      if (sel) _setTargetSaveBonus(bonus);
                    },
                  ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ac in [10, 12, 15, 18, 20])
                  ChoiceChip(
                    label: Text('AC $ac${ac == 15 ? " (Avg)" : ""}'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _targetAc == ac
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    selected: _targetAc == ac,
                    selectedColor: schoolColor.withValues(alpha: 0.35),
                    onSelected: (sel) {
                      if (sel) _setTargetAc(ac);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetCountCard(
    BuildContext context, {
    required Color schoolColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, size: 18, color: Colors.orangeAccent),
          const SizedBox(width: 6),
          Text(
            'Creatures Affected: ',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$_targetCount target${_targetCount == 1 ? "" : "s"}',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _updateTargetCount(-1),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _updateTargetCount(1),
          ),
        ],
      ),
    );
  }
}
