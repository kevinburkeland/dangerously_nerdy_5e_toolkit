import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/spellbook_data.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../glyphs/dnd_glyph.dart';

/// Interactive modal for quick-rolling spells with dynamic upcast slots,
/// cantrip character-level tiers, and ability modifier resolution.
class SpellQuickRollDialog extends StatefulWidget {
  final SpellItem spell;
  final DmRulesEdition edition;
  final void Function(SpellRollResult result, String spellName, int castLevel)? onRollCompleted;

  const SpellQuickRollDialog({
    super.key,
    required this.spell,
    required this.edition,
    this.onRollCompleted,
  });

  static Future<SpellRollResult?> show(
    BuildContext context, {
    required SpellItem spell,
    required DmRulesEdition edition,
    void Function(SpellRollResult result, String spellName, int castLevel)? onRollCompleted,
  }) {
    HapticService.selectionTick(context);
    return showDialog<SpellRollResult>(
      context: context,
      builder: (ctx) => SpellQuickRollDialog(
        spell: spell,
        edition: edition,
        onRollCompleted: onRollCompleted,
      ),
    );
  }

  @override
  State<SpellQuickRollDialog> createState() => _SpellQuickRollDialogState();
}

class _SpellQuickRollDialogState extends State<SpellQuickRollDialog> {
  late int _selectedSlotLevel;
  int _selectedCantripTier = 1; // 1: Lvl 1-4, 2: Lvl 5-10, 3: Lvl 11-16, 4: Lvl 17-20
  int _selectedAbilityMod = 3;

  SpellRollResult? _latestResult;

  @override
  void initState() {
    super.initState();
    _selectedSlotLevel = widget.spell.level == 0 ? 0 : widget.spell.level;
  }

  String get _currentFormula {
    final rules = widget.spell.getRules(widget.edition);
    final baseFormula = rules.rollFormula ?? '1d20';

    if (widget.spell.level == 0) {
      // Cantrip scaling
      final charLevel = switch (_selectedCantripTier) {
        2 => 5,
        3 => 11,
        4 => 17,
        _ => 1,
      };
      return CantripScalingEngine.scaleCantripFormula(baseFormula, charLevel);
    } else {
      // Leveled spell upcasting
      if (rules.scalingFormula != null) {
        return rules.scalingFormula!.getFormulaForSlot(widget.spell.level, _selectedSlotLevel);
      }
      return baseFormula;
    }
  }

  bool get _hasAbilityMod {
    final rules = widget.spell.getRules(widget.edition);
    final formula = rules.rollFormula ?? '';
    return formula.contains('+ mod') || formula.contains('- mod') || (rules.scalingFormula?.addsAbilityMod ?? false);
  }

  void _executeRoll() {
    HapticService.heavyImpact(context);
    final formula = _currentFormula;
    final result = SpellRollEngine.roll(
      formula: formula,
      abilityModifier: _selectedAbilityMod,
    );

    final spellName = widget.spell.getName(widget.edition);
    final levelLabel = widget.spell.level == 0
        ? 'Cantrip (Tier $_selectedCantripTier)'
        : 'Level $_selectedSlotLevel Slot';
    final announceText = '$spellName ($levelLabel): ${result.total} [Dice: ${result.individualDice.join(", ")}${result.modifier != 0 ? " + Mod ${result.modifier}" : ""}]';
    A11yService.announce(announceText);

    setState(() {
      _latestResult = result;
    });

    widget.onRollCompleted?.call(result, spellName, _selectedSlotLevel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ?? TabletopColors.dark;
    final rules = widget.spell.getRules(widget.edition);
    final effectiveSchool = widget.spell.getSchool(widget.edition);
    final schoolColor = effectiveSchool.getLegibleColor(isDark);

    final isCantrip = widget.spell.level == 0;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: DndGlyph + Spell Name & Type
            Row(
              children: [
                DndGlyph.spell(
                  school: effectiveSchool,
                  level: widget.spell.level,
                  actionRings: widget.spell.getGlyphActionRings(widget.edition),
                  size: 40,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.spell.getName(widget.edition),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.spell.getFullTypeLabel(widget.edition),
                        style: TextStyle(
                          color: schoolColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(_latestResult),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 14),

            // Cantrip Tier Selector OR Leveled Spell Slot Picker
            if (isCantrip) ...[
              Text(
                'Character Level Scaling Tier',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTierChip(1, 'Lvl 1–4 (1x)'),
                    const SizedBox(width: 6),
                    _buildTierChip(2, 'Lvl 5–10 (2x)'),
                    const SizedBox(width: 6),
                    _buildTierChip(3, 'Lvl 11–16 (3x)'),
                    const SizedBox(width: 6),
                    _buildTierChip(4, 'Lvl 17–20 (4x)'),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Cast Spell Slot Level',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(10 - widget.spell.level, (i) {
                    final slotLvl = widget.spell.level + i;
                    final isSelected = _selectedSlotLevel == slotLvl;
                    final isBase = slotLvl == widget.spell.level;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          isBase ? 'Slot $slotLvl (Base)' : 'Slot $slotLvl',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selectedColor: schoolColor.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          if (selected) {
                            HapticService.selectionTick(context);
                            setState(() => _selectedSlotLevel = slotLvl);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],

            // Ability Modifier Selector (if spell adds modifier)
            if (_hasAbilityMod) ...[
              const SizedBox(height: 14),
              Text(
                'Spellcasting Ability Modifier',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(11, (i) {
                    final modVal = i;
                    final isSelected = _selectedAbilityMod == modVal;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          '+$modVal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selectedColor: schoolColor.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          if (selected) {
                            HapticService.selectionTick(context);
                            setState(() => _selectedAbilityMod = modVal);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Active Formula Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tabletop.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tabletop.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.casino, color: schoolColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Formula',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _hasAbilityMod
                              ? _currentFormula.replaceAll('+ mod', '+ $_selectedAbilityMod')
                              : _currentFormula,
                          style: TextStyle(
                            color: schoolColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rules.damageOrHealType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: schoolColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rules.damageOrHealType!,
                        style: TextStyle(color: schoolColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Latest Roll Result Banner
            if (_latestResult != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.greenAccent : const Color(0xFF15803D)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (isDark ? Colors.greenAccent : const Color(0xFF15803D)).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: isDark ? Colors.greenAccent : const Color(0xFF15803D), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Roll Total: ${_latestResult!.total}',
                            style: TextStyle(
                              color: isDark ? Colors.greenAccent : const Color(0xFF15803D),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Dice: [${_latestResult!.individualDice.join(", ")}]${_latestResult!.modifier != 0 ? " | Mod: ${_latestResult!.modifier > 0 ? "+" : ""}${_latestResult!.modifier}" : ""}',
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons: Roll & Done
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _executeRoll,
                    style: FilledButton.styleFrom(
                      backgroundColor: schoolColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.casino, size: 18),
                    label: Text(
                      _latestResult == null ? 'ROLL SPELL' : 'RE-ROLL',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierChip(int tier, String label) {
    final isSelected = _selectedCantripTier == tier;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selectedColor: Colors.amber.withValues(alpha: 0.25),
      onSelected: (selected) {
        if (selected) {
          HapticService.selectionTick(context);
          setState(() => _selectedCantripTier = tier);
        }
      },
    );
  }
}
