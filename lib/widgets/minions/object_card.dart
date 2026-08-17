import 'package:flutter/material.dart';
import '../../models/animated_object.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../dialogs/creature_stat_block_dialog.dart';
import '../dialogs/set_object_hp_dialog.dart';
import '../dialogs/value_input_dialog.dart';
import '../glyphs/dnd_glyph.dart';

class ObjectCard extends StatelessWidget {
  final AnimatedObjectInstance object;
  final VoidCallback onDelete;
  final Function(int delta) onHpChanged;
  final Function(String name) onNameChanged;
  final Function(int currentHp, int tempHp)? onHpDataSet;

  const ObjectCard({
    super.key,
    required this.object,
    required this.onDelete,
    required this.onHpChanged,
    required this.onNameChanged,
    this.onHpDataSet,
  });

  Future<void> _showEditNameDialog(BuildContext context) async {
    HapticService.selectionTick(context);
    final newName = await ValueInputDialog.showRename(context, initialName: object.name);
    if (newName != null && newName.isNotEmpty) {
      onNameChanged(newName);
    }
  }

  Future<void> _showCustomHpDialog(BuildContext context) async {
    HapticService.selectionTick(context);
    final result = await SetObjectHpDialog.show(
      context,
      objectName: object.name,
      currentHp: object.currentHp,
      maxHp: object.maxHp,
      tempHp: object.tempHp,
    );
    if (result != null) {
      if (onHpDataSet != null) {
        onHpDataSet!(result.currentHp, result.tempHp);
      } else {
        object.tempHp = result.tempHp;
        onHpChanged(result.currentHp - object.currentHp);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customColors = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);
    final size = object.size;
    final isDead = object.isDead;
    final accentColor = object.accentColor;

    return Card(
      elevation: isDead ? 0 : 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDead ? customColors.fumbleRed.withValues(alpha: 0.5) : accentColor.withValues(alpha: 0.6),
          width: isDead ? 1 : 1.5,
        ),
      ),
      color: isDead
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : (theme.cardTheme.color ?? theme.colorScheme.surface),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DndGlyph.monster(
                  creatureType: object.statBlock.glyphCreatureType,
                  crTier: object.statBlock.glyphCrTier,
                  actionRings: object.statBlock.glyphActionRings,
                  size: 28,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor, width: 1.2),
                  ),
                  child: Text(
                    '${size.displayName.toUpperCase()} (${size.pointCost}pt)',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showEditNameDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              object.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDead ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: isDead ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, size: 20, color: accentColor.withValues(alpha: 0.85)),
                  tooltip: 'Full Creature Stat Block',
                  onPressed: () => CreatureStatBlockDialog.show(context, statBlock: object.statBlock),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  tooltip: 'Remove Minion',
                  onPressed: () {
                    HapticService.lightImpact(context);
                    onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.35) : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBlock(context, 'AC', '${object.ac}', isDark ? Colors.lightBlueAccent : const Color(0xFF0369A1), semanticName: 'Armor Class', isHero: true),
                  _buildDivider(context),
                  _buildStatBlock(context, 'TO HIT', '+${object.attackBonus}', isDark ? Colors.amberAccent : const Color(0xFFB45309), semanticName: 'Attack Bonus', isHero: true),
                  _buildDivider(context),
                  _buildStatBlock(context, 'DMG', object.damageFormula, isDark ? Colors.orangeAccent : const Color(0xFFC2410C), semanticName: 'Damage Formula', isHero: true),
                  _buildDivider(context),
                  _buildStatBlock(context, 'STR', '${size.strScore}', theme.colorScheme.onSurface, semanticName: 'Strength Score'),
                  _buildDivider(context),
                  _buildStatBlock(context, 'DEX', '${size.dexScore}', theme.colorScheme.onSurface, semanticName: 'Dexterity Score'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildHpButton(
                  context: context,
                  icon: Icons.remove,
                  color: Colors.redAccent,
                  enabled: !isDead,
                  tooltip: '-1 HP',
                  semanticLabel: 'Decrease 1 HP for ${object.name}',
                  onTap: () {
                    HapticService.selectionTick(context);
                    onHpChanged(-1);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: '${object.name} Hit Points: ${isDead ? "Destroyed" : "${object.currentHp} of ${object.maxHp}"}${object.tempHp > 0 ? ", plus ${object.tempHp} temporary HP" : ""}. ${(object.hpPercent * 100).toInt()} percent remaining. Tap to edit custom HP.',
                    button: true,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showCustomHpDialog(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isDead ? '💀 DESTROYED' : 'HP: ${object.currentHp} / ${object.maxHp}',
                                    style: TextStyle(
                                      color: isDead ? customColors.fumbleRed : theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (object.tempHp > 0 && !isDead) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: customColors.tempHpCyan.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: customColors.tempHpCyan, width: 1),
                                      ),
                                      child: Text(
                                        '+${object.tempHp} TEMP',
                                        style: TextStyle(
                                          color: customColors.tempHpCyan,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${(object.hpPercent * 100).toInt()}%',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                                if (object.tempHp > 0)
                                  FractionallySizedBox(
                                    widthFactor: ((object.currentHp + object.tempHp) / object.maxHp).clamp(0.0, 1.0),
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: customColors.tempHpCyan,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                FractionallySizedBox(
                                  widthFactor: (object.currentHp / object.maxHp).clamp(0.0, 1.0),
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: object.hpPercent > 0.5
                                          ? customColors.hitGreen
                                          : (object.hpPercent > 0.25 ? Colors.amber : customColors.fumbleRed),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildHpButton(
                  context: context,
                  icon: Icons.add,
                  color: customColors.hitGreen,
                  enabled: !isDead,
                  tooltip: '+1 HP',
                  semanticLabel: 'Increase 1 HP for ${object.name}',
                  onTap: () {
                    HapticService.selectionTick(context);
                    onHpChanged(1);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(BuildContext context, String label, String value, Color color, {required String semanticName, bool isHero = false}) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$semanticName: $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: isHero ? 10 : 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isHero ? 15 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 24,
      width: 1,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
    );
  }

  Widget _buildHpButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required bool enabled,
    required String tooltip,
    String? semanticLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: semanticLabel ?? tooltip,
          enabled: enabled,
          child: Material(
            color: enabled ? color.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: enabled ? color.withValues(alpha: 0.6) : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? onTap : null,
              child: Center(
                child: Icon(icon, color: enabled ? color : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
