import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';
import '../common/edition_diff_badge.dart';
import '../interactive/pressable_card.dart';

/// Card component for rendering 5e Species & Races in the Species Codex grid.
class RaceCard extends StatelessWidget {
  final Race race;
  final bool isPinned;
  final DmRulesEdition? edition;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;

  const RaceCard({
    super.key,
    required this.race,
    required this.isPinned,
    this.edition,
    required this.onTogglePin,
    required this.onTap,
  });

  Color _getSpeciesColor(String slug) {
    switch (slug.toLowerCase()) {
      case 'human':
      case 'human-variant':
      case 'custom-lineage':
        return const Color(0xFF38BDF8); // Cerulean Blue
      case 'elf':
      case 'high-elf':
      case 'wood-elf':
      case 'drow':
        return const Color(0xFF10B981); // Emerald
      case 'dwarf':
      case 'hill-dwarf':
      case 'mountain-dwarf':
        return const Color(0xFFF59E0B); // Amber Bronze
      case 'halfling':
      case 'lightfoot-halfling':
      case 'stout-halfling':
        return const Color(0xFF84CC16); // Lime
      case 'dragonborn':
        return const Color(0xFFEF4444); // Crimson
      case 'gnome':
      case 'forest-gnome':
      case 'rock-gnome':
        return const Color(0xFF06B6D4); // Cyan
      case 'tiefling':
        return const Color(0xFFA855F7); // Purple
      case 'aasimar':
        return const Color(0xFFFACC15); // Celestial Gold
      case 'goliath':
      case 'orc':
      case 'half-orc':
        return const Color(0xFFFB923C); // Warm Orange
      default:
        return const Color(0xFF10B981); // Emerald Default
    }
  }

  IconData _getSpeciesIcon(String slug) {
    switch (slug.toLowerCase()) {
      case 'human':
      case 'human-variant':
      case 'custom-lineage':
        return Icons.person;
      case 'elf':
        return Icons.nature_people;
      case 'dwarf':
        return Icons.shield;
      case 'halfling':
      case 'gnome':
        return Icons.child_care;
      case 'dragonborn':
        return Icons.local_fire_department;
      case 'tiefling':
        return Icons.whatshot;
      case 'aasimar':
        return Icons.auto_awesome;
      case 'goliath':
      case 'orc':
      case 'half-orc':
        return Icons.fitness_center;
      default:
        return Icons.people_alt;
    }
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
    final slug = race.id.slug.toLowerCase();
    final speciesColor = _getSpeciesColor(slug);
    final speciesIcon = _getSpeciesIcon(slug);
    final resolvedEdition = edition ?? SettingsScope.maybeOf(context)?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final resolvedSpeed = race.getSpeedForEdition(resolvedEdition);
    final is2024Mode = resolvedEdition == DmRulesEdition.v2024;
    final isHomebrew = race.id.ruleset == RulesetVersion.homebrew;

    final hasDarkvision = race.customProperties['hasDarkvision'] == true ||
        race.traitsMarkdown.toLowerCase().contains('darkvision');
    final darkvisionFeet = race.customProperties['darkvisionFeet'] ?? 60;

    // Clean plain-text preview of traits
    final cleanTraits = race.traitsMarkdown
        .replaceAll(RegExp(r'\*\*|__|\*|_|#|`'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();

    return PressableCard(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPinned ? speciesColor : speciesColor.withValues(alpha: 0.25),
          width: isPinned ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Species Icon + Name + Edition Badge + Pin Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: speciesColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: speciesColor.withValues(alpha: 0.55)),
                ),
                child: Icon(speciesIcon, color: speciesColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      race.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${race.size} • $resolvedSpeed • ${is2024Mode ? "2024 Species" : (isHomebrew ? "Homebrew" : "2014 Race")}',
                      style: TextStyle(
                        color: speciesColor,
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
                  color: isPinned ? speciesColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: 20,
                ),
                tooltip: isPinned ? 'Remove bookmark' : 'Bookmark species',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  HapticService.selectionTick(context);
                  onTogglePin();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Attributes & Trait Badges
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              _buildTag('Size: ${race.size}', speciesColor),
              _buildTag('Speed: $resolvedSpeed', isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
              if (hasDarkvision)
                _buildTag(
                  'Darkvision $darkvisionFeet ft.',
                  isDark ? const Color(0xFFFACC15) : const Color(0xFFCA8A04),
                ),
              if (race.subraces.isNotEmpty)
                _buildTag(
                  '${race.subraces.length} Lineages',
                  isDark ? const Color(0xFFA855F7) : const Color(0xFF7E22CE),
                ),
              if (race.bonusFeatCount > 0)
                _buildTag(
                  '+${race.bonusFeatCount} Bonus Feat',
                  isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Traits Snippet Preview
          Text(
            cleanTraits,
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
                  'Tap for full lineage & species traits',
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
