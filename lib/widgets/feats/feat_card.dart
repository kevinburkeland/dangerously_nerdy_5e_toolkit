import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/settings_provider.dart';
import '../common/edition_diff_badge.dart';
import '../interactive/pressable_card.dart';

/// Interactive card presenting an individual 5e Feat with category tagging,
/// prerequisite indicators, mechanic grant pills, and bookmarking.
class FeatCard extends StatelessWidget {
  final Feat feat;
  final bool isPinned;
  final DmRulesEdition? edition;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;

  const FeatCard({
    super.key,
    required this.feat,
    required this.isPinned,
    this.edition,
    required this.onTogglePin,
    required this.onTap,
  });

  Color _getCategoryColor(String category, bool isDark) {
    final cat = category.toLowerCase();
    if (cat.contains('origin')) {
      return isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309);
    }
    if (cat.contains('fighting')) {
      return isDark ? const Color(0xFF69F0AE) : const Color(0xFF047857);
    }
    if (cat.contains('boon') || cat.contains('epic')) {
      return isDark ? const Color(0xFFE040FB) : const Color(0xFF7E22CE);
    }
    // General / Default
    return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('origin')) return Icons.auto_awesome;
    if (cat.contains('fighting')) return Icons.sports_martial_arts;
    if (cat.contains('boon') || cat.contains('epic')) return Icons.stars;
    return Icons.military_tech;
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedEdition = edition ?? SettingsScope.maybeOf(context)?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final is2024Mode = resolvedEdition == DmRulesEdition.v2024;
    final categoryLabel = (!is2024Mode && feat.category.toLowerCase() == 'origin') ? 'General' : feat.category;
    final accentColor = _getCategoryColor(categoryLabel, isDark);
    final categoryIcon = _getCategoryIcon(categoryLabel);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

    final isHomebrew = feat.id.ruleset == RulesetVersion.homebrew;

    final cardBorderColor = isPinned
        ? pinColor.withValues(alpha: 0.85)
        : accentColor.withValues(alpha: 0.35);

    // Clean plain text preview of description
    final cleanDesc = feat.descriptionMarkdown
        .replaceAll(RegExp(r'\*\*|\*|#+'), '')
        .trim();

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
          // Header: Category Icon + Title + Badges + Pin button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Icon(categoryIcon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feat.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$categoryLabel Feat • ${is2024Mode ? "2024 Revision" : (isHomebrew ? "Homebrew" : "2014 Classic")}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (is2024Mode && !isHomebrew) ...[
                const EditionDiffBadge(),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(
                  isPinned ? Icons.bookmark : Icons.bookmark_border,
                  color: isPinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: isPinned ? 'Remove from Bookmarks' : 'Pin to Bookmarks',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onTogglePin,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Metadata Badges Row (Prerequisites, Repeatable, Grants count)
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              _buildTag('${feat.category} Feat', accentColor),
              if (feat.prerequisite != null && feat.prerequisite!.isNotEmpty)
                _buildTag(
                  'Req: ${feat.prerequisite}',
                  isDark ? Colors.amberAccent : const Color(0xFFB45309),
                ),
              if (feat.customProperties['repeatable'] == true)
                _buildTag(
                  'Repeatable',
                  isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                ),
              if (feat.grants.isNotEmpty)
                _buildTag(
                  '${feat.grants.length} Mechanic ${feat.grants.length == 1 ? "Grant" : "Grants"}',
                  isDark ? Colors.indigoAccent : const Color(0xFF4338CA),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Description Snippet
          Text(
            cleanDesc,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),

          // Footer info / tap prompt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tap for full feat details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
