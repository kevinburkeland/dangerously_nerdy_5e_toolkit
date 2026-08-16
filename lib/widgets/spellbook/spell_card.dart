import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/spellbook_data.dart';
import '../interactive/pressable_card.dart';

/// Modular, interactive card presenting an individual SRD spell.
class SpellCard extends StatelessWidget {
  final SpellItem spell;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final void Function(String formula, String label)? onQuickRoll;

  const SpellCard({
    super.key,
    required this.spell,
    required this.edition,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
    this.onQuickRoll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = spell.getRules(edition);
    final schoolColor = spell.school.color;

    return PressableCard(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPinned ? Colors.purpleAccent.withValues(alpha: 0.8) : schoolColor.withValues(alpha: 0.35),
          width: isPinned ? 1.6 : 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title & School + Diff Badge + Pin Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: schoolColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(spell.school.icon, color: schoolColor, size: 20),
              ),
              const SizedBox(width: 8),
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
                      spell.fullTypeLabel,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 10),
                      SizedBox(width: 2),
                      Text(
                        '2024 Diff',
                        style: TextStyle(color: Colors.amber, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
              ],
              IconButton(
                icon: Icon(
                  isPinned ? Icons.bookmark : Icons.bookmark_border,
                  color: isPinned ? Colors.purpleAccent : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
                tooltip: isPinned ? 'Remove from Personal Spellbook' : 'Pin to Personal Spellbook',
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
              _buildBadge(Icons.timer_outlined, rules.castingTime, schoolColor),
              _buildBadge(Icons.my_location_outlined, rules.range, schoolColor),
              _buildBadge(Icons.hourglass_empty_outlined, rules.duration, schoolColor),
              if (rules.concentration)
                _buildTag('Conc', Colors.amberAccent),
              if (rules.ritual)
                _buildTag('Ritual', Colors.cyanAccent),
              if (rules.savingThrow != null)
                _buildTag('${rules.savingThrow} Save', Colors.orangeAccent),
              if (rules.damageOrHealType != null)
                _buildTag(rules.damageOrHealType!, schoolColor),
            ],
          ),
          const SizedBox(height: 8),

          // Spell preview text
          Text(
            rules.description.first,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),

          // Footer Row: Classes & Quick Roll Button
          Row(
            children: [
              Expanded(
                child: Text(
                  rules.classes.map((c) => c.label).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
              if (rules.rollFormula != null && onQuickRoll != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: InkWell(
                    onTap: () => onQuickRoll!(rules.rollFormula!, spell.name),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: schoolColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: schoolColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.casino_outlined, color: schoolColor, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            rules.rollFormula!,
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
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accentColor.withValues(alpha: 0.8)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
