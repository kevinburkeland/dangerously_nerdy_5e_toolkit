import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/settings_provider.dart';
import '../common/edition_diff_badge.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';
import '../interactive/pressable_card.dart';

/// Interactive card presenting a 5e Character Class with Hit Die indicator,
/// Primary Ability, Saving Throws, Proficiencies, and Subclass counts.
class ClassCard extends StatelessWidget {
  final CharacterClass characterClass;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final DmRulesEdition? edition;

  const ClassCard({
    super.key,
    required this.characterClass,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
    this.edition,
  });

  IconData _getClassIcon(String slug) {
    switch (slug.toLowerCase()) {
      case 'barbarian':
        return Icons.sports_kabaddi;
      case 'bard':
        return Icons.music_note;
      case 'cleric':
        return Icons.auto_awesome;
      case 'druid':
        return Icons.eco;
      case 'fighter':
        return Icons.shield;
      case 'monk':
        return Icons.sports_martial_arts;
      case 'paladin':
        return Icons.health_and_safety;
      case 'ranger':
        return Icons.nature_people;
      case 'rogue':
        return Icons.visibility_off;
      case 'sorcerer':
        return Icons.local_fire_department;
      case 'warlock':
        return Icons.dark_mode;
      case 'wizard':
        return Icons.auto_stories;
      case 'artificer':
        return Icons.build;
      default:
        return Icons.person;
    }
  }

  Color _getClassColor(String slug, bool isDark) {
    switch (slug.toLowerCase()) {
      case 'barbarian':
        return isDark ? const Color(0xFFFF5252) : const Color(0xFFC62828);
      case 'bard':
        return isDark ? const Color(0xFFFF4081) : const Color(0xFFC2185B);
      case 'cleric':
        return isDark ? const Color(0xFFFFD700) : const Color(0xFFF57F17);
      case 'druid':
        return isDark ? const Color(0xFF69F0AE) : const Color(0xFF2E7D32);
      case 'fighter':
        return isDark ? const Color(0xFFFF7043) : const Color(0xFFD84315);
      case 'monk':
        return isDark ? const Color(0xFF40C4FF) : const Color(0xFF0277BD);
      case 'paladin':
        return isDark ? const Color(0xFFFFAB40) : const Color(0xFFE65100);
      case 'ranger':
        return isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C);
      case 'rogue':
        return isDark ? const Color(0xFFB0BEC5) : const Color(0xFF455A64);
      case 'sorcerer':
        return isDark ? const Color(0xFFFF1744) : const Color(0xFFD50000);
      case 'warlock':
        return isDark ? const Color(0xFFBA68C8) : const Color(0xFF6A1B9A);
      case 'wizard':
        return isDark ? const Color(0xFF448AFF) : const Color(0xFF1565C0);
      case 'artificer':
        return isDark ? const Color(0xFF26A69A) : const Color(0xFF00695C);
      default:
        return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2);
    }
  }

  Color _getHitDieColor(String hitDie, bool isDark) {
    switch (hitDie.toLowerCase()) {
      case 'd12':
        return isDark ? const Color(0xFFFF5252) : const Color(0xFFC62828);
      case 'd10':
        return isDark ? const Color(0xFFFF7043) : const Color(0xFFD84315);
      case 'd8':
        return isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309);
      case 'd6':
        return isDark ? const Color(0xFF40C4FF) : const Color(0xFF0277BD);
      default:
        return isDark ? Colors.amber : Colors.orange;
    }
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
    final slug = characterClass.id.slug;
    final classColor = _getClassColor(slug, isDark);
    final classIcon = _getClassIcon(slug);
    final resolvedClassType = DndClassType.tryParse(slug) ?? DndClassType.tryParse(characterClass.name);
    final hitDieColor = _getHitDieColor(characterClass.hitDie, isDark);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

    final resolvedEdition =
        edition ?? SettingsScope.maybeOf(context)?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final is2024Mode = resolvedEdition == DmRulesEdition.v2024;
    final isHomebrew = characterClass.id.ruleset == RulesetVersion.homebrew;

    final cardBorderColor = isPinned
        ? pinColor.withValues(alpha: 0.85)
        : classColor.withValues(alpha: 0.35);

    // Clean description preview
    final cleanDesc = characterClass.featuresMarkdown
        .replaceAll(RegExp(r'\*\*|\*|#+'), '')
        .trim();

    final isSpellcaster = characterClass.spellcastingAbility != null;

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
          // Header: Class Glyph + Name + Hit Die Pill + Pin Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resolvedClassType != null)
                DndGlyph.classFeature(
                  classType: resolvedClassType,
                  size: 40,
                  isDarkMode: isDark,
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: classColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: classColor.withValues(alpha: 0.55)),
                  ),
                  child: Icon(classIcon, color: classColor, size: 22),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      characterClass.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${characterClass.primaryAbility ?? "Custom"} • ${is2024Mode ? "2024 Revision" : (isHomebrew ? "Homebrew" : "2014 Classic")}',
                      style: TextStyle(
                        color: classColor,
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

          // Metadata Badges Row (Hit Die, Saves, Spellcasting, Subclasses)
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              _buildTag('Hit Die: ${characterClass.hitDie}', hitDieColor),
              if (characterClass.savingThrows.isNotEmpty)
                _buildTag(
                  'Saves: ${characterClass.savingThrows.join(", ")}',
                  isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                ),
              if (isSpellcaster)
                _buildTag(
                  'Spellcasting: ${characterClass.spellcastingAbility}',
                  isDark ? const Color(0xFFBA68C8) : const Color(0xFF7E22CE),
                ),
              if (characterClass.subclasses.isNotEmpty)
                _buildTag(
                  '${characterClass.subclasses.length} Subclasses',
                  classColor,
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

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tap for class details & subclasses',
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
