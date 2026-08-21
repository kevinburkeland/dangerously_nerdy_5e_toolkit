import 'package:flutter/material.dart';
import '../../models/magic_items/magic_item_data.dart';
import '../glyphs/dnd_glyph.dart';

/// Modal dialog showing full magic item details, properties, action traits, and attunement rules.
class ItemDetailDialog extends StatelessWidget {
  final MagicItem item;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const ItemDetailDialog({
    super.key,
    required this.item,
    this.edition = DmRulesEdition.v2024,
    required this.isPinned,
    required this.onTogglePin,
  });

  static void show(
    BuildContext context, {
    required MagicItem item,
    DmRulesEdition edition = DmRulesEdition.v2024,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ItemDetailDialog(
        item: item,
        edition: edition,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rules = item.getRules(edition);
    final rarityColor = item.rarity.getLegibleColor(isDark);
    final categoryColor = item.category.getLegibleColor(isDark);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: rarityColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DndGlyph.item(
            category: item.category,
            rarity: item.rarity,
            requiresAttunement: item.requiresAttunement,
            damageAccent: item.getGlyphPrimaryDamageAccent(edition),
            actionRings: item.getGlyphActionRings(edition),
            glyphColor: item.effectiveGlyphColor,
            size: 64,
            isDarkMode: isDark,
            isActive: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.getName(edition),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.category.displayName} • ${item.rarity.displayName}'
                  '${item.requiresAttunement ? " (${item.getAttunementLabel()})" : ""}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: rarityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Category', item.category.displayName, color: categoryColor),
            _buildDetailRow('Rarity', item.rarity.displayName, color: rarityColor),
            _buildDetailRow(
              'Attunement',
              item.getAttunementLabel(),
              color: item.requiresAttunement
                  ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                  : null,
            ),
            if (rules.activation != null)
              _buildDetailRow('Activation', rules.activation!),
            if (rules.charges != null)
              _buildDetailRow('Charges', rules.charges!),
            if (rules.savingThrowDc != null)
              _buildDetailRow('Save DC', rules.savingThrowDc!),
            if (rules.masteryProperties != null)
              _buildDetailRow('Weapon Mastery', rules.masteryProperties!),
            if (item.damageAccent != null)
              _buildDetailRow(
                'Damage / Element',
                item.damageAccent!.displayName,
                color: item.damageAccent!.color,
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              rules.description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (item.actionRings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Action Traits & Enchantments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...item.actionRings.map((ring) {
                final ringColor = ring.getEffectiveColor(rarityColor);
                final label = ring.label ??
                    (ring.damageLegend.isNotEmpty
                        ? '${ring.ringType.displayName} (${ring.damageLegend})'
                        : ring.ringType.displayName);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ringColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ring.ringType.displayName}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: ringColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            onTogglePin();
            Navigator.of(context).pop();
          },
          icon: Icon(
            isPinned ? Icons.bookmark_remove : Icons.bookmark_add,
            size: 18,
            color: isPinned ? pinColor : null,
          ),
          label: Text(
            isPinned ? 'Remove from Reliquary' : 'Pin to Reliquary',
            style: TextStyle(color: isPinned ? pinColor : null),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
