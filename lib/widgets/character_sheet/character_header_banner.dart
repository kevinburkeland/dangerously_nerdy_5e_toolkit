import 'package:flutter/material.dart';
import '../../providers/character_sheet_controller.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';

/// Header banner displaying character identity, classes, species, level, background,
/// and interactive Inspiration toggle.
class CharacterHeaderBanner extends StatelessWidget {
  final CharacterSheetController controller;

  const CharacterHeaderBanner({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final character = controller.character;
    final stats = controller.stats;
    final hasInspiration = controller.hasInspiration;

    final classSummary = character.progression.classes
        .map((c) => '${c.classRef.displayName} ${c.level}')
        .join(' / ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Character Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasInspiration
                        ? (customColors?.critGold ?? Colors.amber)
                        : theme.colorScheme.primaryContainer,
                    width: 2,
                  ),
                  boxShadow: hasInspiration
                      ? [
                          BoxShadow(
                            color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    character.name.isNotEmpty ? character.name.substring(0, 1).toUpperCase() : '?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and Class Level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            character.name.isEmpty ? 'Unnamed Hero' : character.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Total Level Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'Level ${character.totalLevel}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classSummary.isEmpty ? 'Level 1 Adventurer' : classSummary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Metadata & Inspiration row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Species Chip
              _buildMetaChip(
                context,
                icon: Icons.person_outline,
                label: character.speciesRef.displayName.isEmpty
                    ? 'Species'
                    : character.speciesRef.displayName,
              ),
              // Background Chip
              if (character.backgroundRef != null)
                _buildMetaChip(
                  context,
                  icon: Icons.history_edu,
                  label: character.backgroundRef!.displayName,
                ),
              // Proficiency Bonus Chip
              _buildMetaChip(
                context,
                icon: Icons.military_tech_outlined,
                label: 'PB +${stats.proficiencyBonus}',
              ),
              // Interactive Inspiration Toggle
              InkWell(
                onTap: () {
                  HapticService.selectionTick(context);
                  controller.toggleInspiration();
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasInspiration
                        ? (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasInspiration
                          ? (customColors?.critGold ?? Colors.amber)
                          : theme.colorScheme.outlineVariant,
                      width: hasInspiration ? 2 : 1,
                    ),
                    boxShadow: hasInspiration
                        ? [
                            BoxShadow(
                              color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasInspiration ? Icons.star : Icons.star_border,
                        size: 16,
                        color: hasInspiration
                            ? (customColors?.critGold ?? Colors.amber)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Inspiration',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: hasInspiration
                              ? (customColors?.critGold ?? Colors.amber)
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: hasInspiration ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
