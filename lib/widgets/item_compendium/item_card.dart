import 'package:flutter/material.dart';
import '../../models/magic_items/magic_item_data.dart';
import '../common/edition_diff_badge.dart';
import '../glyphs/dnd_glyph.dart';
import '../interactive/pressable_card.dart';

/// Modular, interactive card presenting an individual SRD magic item with edition diff support.
class ItemCard extends StatelessWidget {
  final MagicItem item;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final VoidCallback? onCompare;

  const ItemCard({
    super.key,
    required this.item,
    this.edition = DmRulesEdition.v2024,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
    this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rules = item.getRules(edition);
    final rarityColor = item.rarity.getLegibleColor(isDark);
    final categoryColor = item.category.getLegibleColor(isDark);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final cardBorderColor = isPinned
        ? pinColor.withValues(alpha: 0.85)
        : rarityColor.withValues(alpha: 0.35);

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
          // Header Row: DndGlyph HUD + Title & Category + Rarity Badge + Diff Badge + Pin Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DndGlyph.item(
                category: item.category,
                rarity: item.rarity,
                requiresAttunement: item.requiresAttunement,
                damageAccent: item.damageAccent,
                actionRings: item.actionRings,
                size: 38,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.getName(edition),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.category.displayName,
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.45)),
                ),
                child: Text(
                  item.rarity.displayName.toUpperCase(),
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item.isChangedIn2024) ...[
                const SizedBox(width: 4),
                EditionDiffBadge(
                  onTap: onCompare,
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.bookmark : Icons.bookmark_border,
                  color: isPinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: isPinned
                    ? 'Remove from Personal Reliquary'
                    : 'Pin to Personal Reliquary',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onTogglePin,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Metadata Badges (Category, Rarity, Attunement, Damage, Activation)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildBadge(context, Icons.category_outlined, item.category.displayName, categoryColor),
              _buildBadge(context, Icons.diamond_outlined, item.rarity.displayName, rarityColor),
              if (item.requiresAttunement)
                _buildTag(
                  item.attunementRequirement != null
                      ? 'Attunement (${item.attunementRequirement})'
                      : 'Requires Attunement',
                  isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  icon: Icons.link,
                ),
              if (rules.activation != null && rules.activation != 'Passive')
                _buildTag(
                  rules.activation!,
                  theme.colorScheme.primary,
                  icon: Icons.bolt,
                ),
              if (item.damageAccent != null)
                _buildTag(
                  item.damageAccent!.displayName,
                  item.damageAccent!.color,
                  icon: Icons.local_fire_department_outlined,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Summary description preview
          Text(
            rules.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),

          // Action Trait Rings Preview
          if (item.actionRings.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: item.actionRings.map((ring) {
                  final ringColor = ring.getEffectiveColor(rarityColor);
                  final label = ring.label ??
                      (ring.damageLegend.isNotEmpty
                          ? '${ring.ringType.displayName} (${ring.damageLegend})'
                          : ring.ringType.displayName);
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ringColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: ringColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ringColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ringColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(
      BuildContext context, IconData icon, String text, Color accent) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, {IconData? icon}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2.5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
