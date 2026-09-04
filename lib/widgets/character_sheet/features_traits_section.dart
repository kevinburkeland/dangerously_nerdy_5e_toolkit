import 'package:flutter/material.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../models/domain/core_types.dart' show RulesetVersion;
import '../../models/domain/homebrew_extended_entities.dart' show FeatureOption;
import '../../providers/character_sheet_controller.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

/// Aggregated Identity, Traits, Feats, and Class Features Section with
/// accessible 48x48dp touch targets and modal bottom sheet reference viewers.
class FeaturesTraitsSection extends StatelessWidget {
  final CharacterSheetController controller;

  const FeaturesTraitsSection({
    super.key,
    required this.controller,
  });

  void _showFeatureDetailModal(
    BuildContext context, {
    required String name,
    required String category,
    required String descriptionMarkdown,
    IconData icon = Icons.auto_awesome,
    Widget? glyphWidget,
    Color? accentColor,
  }) {
    HapticService.selectionTick(context);
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header with Accessibility Semantics
                Semantics(
                  header: true,
                  label: 'Feature Details: $name',
                  child: Row(
                    children: [
                      if (glyphWidget != null)
                        SizedBox(width: 40, height: 40, child: glyphWidget)
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close feature details',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Markdown Description
                FormattedMarkdownText(
                  descriptionMarkdown,
                  defaultColor: theme.colorScheme.onSurface,
                ),

                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(
    BuildContext context, {
    required String name,
    required String category,
    required String descriptionMarkdown,
    IconData icon = Icons.auto_awesome,
    Widget? glyphWidget,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$name ($category). Tap to view details.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFeatureDetailModal(
            context,
            name: name,
            category: category,
            descriptionMarkdown: descriptionMarkdown,
            icon: icon,
            glyphWidget: glyphWidget,
            accentColor: color,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  if (glyphWidget != null)
                    SizedBox(width: 24, height: 24, child: glyphWidget)
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = controller.character;
    final is2014 = character.rulesEdition == DmRulesEdition.v2014 ||
        character.id.ruleset == RulesetVersion.v2014;

    // Resolve species details
    final race = SrdSpeciesLibrary.findBySlug(character.speciesRef.slug);
    final speciesDesc = (is2014 && race?.id.slug == 'human')
        ? '**Ability Score Increase.** Your ability scores each increase by 1.\n\n**Languages.** You can speak, read, and write Common and one extra language of your choice.'
        : (race?.traitsMarkdown ??
            'Inherent physical, physiological, and biological traits granted by the ${character.speciesRef.displayName} species lineage.');

    // Resolve background details
    final bgSlug = character.backgroundRef?.slug ?? '';
    final bg = bgSlug.isNotEmpty ? SrdBackgroundsLibrary.findBySlug(bgSlug) : null;
    final bgName = character.backgroundRef?.displayName ?? (bg?.name ?? 'Background');
    final bgDesc = bg != null
        ? SrdBackgroundsLibrary.getDescriptionForBackground(
            bg,
            ruleset: is2014 ? RulesetVersion.v2014 : RulesetVersion.v2024,
          )
        : (is2014
            ? 'Narrative background, starting proficiencies, and personal history.'
            : 'Narrative background, origin identity, starting proficiencies, and personal history.');

    // Aggregate class feature options
    final allSelectedOptions = character.progression.getAllSelectedFeatureOptions();
    final optionItems = <Map<String, String>>[];
    for (final entry in allSelectedOptions.entries) {
      final decisionId = entry.key;
      for (final optId in entry.value) {
        final opt = SrdFeatureOptions.allOptions.firstWhere(
          (o) => o.id == optId || o.id == optId.replaceAll('-', '_'),
          orElse: () => SrdFeatureOptions.allOptions.firstWhere(
            (o) => o.name.toLowerCase() == optId.toLowerCase(),
            orElse: () => FeatureOption(
              id: optId,
              name: optId.replaceAll('_', ' ').replaceAll('-', ' '),
              descriptionMarkdown: 'Selected character customization option for ${decisionId.replaceAll('-', ' ')}.',
            ),
          ),
        );
        optionItems.add({
          'name': opt.name,
          'category': decisionId.replaceAll('-', ' ').toUpperCase(),
          'description': opt.descriptionMarkdown,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IDENTITY & LINEAGE',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 8),

        // Species Chip
        _buildFeatureChip(
          context,
          name: '${character.speciesRef.displayName} Traits',
          category: 'Species Lineage',
          descriptionMarkdown: speciesDesc,
          glyphWidget: DndGlyph.species(
            speciesType: SpeciesType.tryParse(character.speciesRef.slug) ??
                SpeciesType.tryParse(character.speciesRef.displayName) ??
                SpeciesType.human,
            size: 24,
            isDarkMode: true,
          ),
          icon: Icons.fingerprint,
          color: Colors.tealAccent,
        ),

        // Background Chip
        _buildFeatureChip(
          context,
          name: bgName,
          category: 'Background',
          descriptionMarkdown: bgDesc,
          glyphWidget: DndGlyph.genericUi(
            uiType: GenericUiGlyphType.d20,
            size: 24,
            isDarkMode: true,
          ),
          icon: Icons.history_edu,
          color: Colors.orangeAccent,
        ),

        const SizedBox(height: 12),
        Text(
          'CLASS FEATURES & SPECIALIZATIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        // Core Class features
        ...character.progression.classes.map((cls) {
          final srdClass = SrdClassesLibrary.findBySlug(cls.classRef.slug);
          final classDesc = srdClass?.featuresMarkdown ??
              'Core class features, weapon/armor proficiencies, and archetype specialization at level ${cls.level} of ${cls.classRef.displayName}.';
          final clsType = DndClassType.tryParse(cls.classRef.slug) ??
              DndClassType.tryParse(cls.classRef.displayName) ??
              DndClassType.fighter;

          return _buildFeatureChip(
            context,
            name: '${cls.classRef.displayName} Features (Lvl ${cls.level})',
            category: 'Class Feature',
            descriptionMarkdown: classDesc,
            glyphWidget: DndGlyph.classFeature(
              classType: clsType,
              size: 24,
              isDarkMode: true,
            ),
            icon: Icons.shield,
            color: theme.colorScheme.primary,
          );
        }),

        // Selected options (Invocations, Fighting Styles, etc.)
        ...optionItems.map((item) {
          return _buildFeatureChip(
            context,
            name: item['name']!,
            category: item['category']!,
            descriptionMarkdown: item['description']!,
            glyphWidget: DndGlyph.genericUi(
              uiType: GenericUiGlyphType.advantage,
              size: 24,
              isDarkMode: true,
            ),
            icon: Icons.auto_awesome,
            color: Colors.cyanAccent,
          );
        }),

        // Feats Section
        if (character.feats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'FEATS (${character.feats.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 8),
          ...character.feats.map((feat) {
            final srdFeat = SrdFeatsLibrary.findBySlug(feat.slug);
            final rawCategory = srdFeat?.category ?? 'Feat';
            final category = (is2014 && rawCategory.toLowerCase() == 'origin')
                ? 'Feat'
                : (srdFeat != null ? '${srdFeat.category} Feat' : 'Feat');
            final featCat = FeatCategory.parse(category);
            final desc = srdFeat?.descriptionMarkdown ?? 'Feat granting specialized combat or exploration prowess.';

            return _buildFeatureChip(
              context,
              name: feat.displayName,
              category: category,
              descriptionMarkdown: desc,
              glyphWidget: DndGlyph.feat(
                category: featCat,
                featId: feat.slug,
                displayName: feat.displayName,
                size: 24,
                isDarkMode: true,
              ),
              icon: Icons.military_tech,
              color: Colors.amberAccent,
            );
          }),
        ],
      ],
    );
  }
}
