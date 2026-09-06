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
import 'add_feat_dialog.dart';

@immutable
class _ExtractedFeature {
  final String name;
  final int? level;
  final String descriptionMarkdown;

  const _ExtractedFeature({
    required this.name,
    this.level,
    required this.descriptionMarkdown,
  });
}

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
    String? featSlugToRemove,
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
                if (featSlugToRemove != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      label: const Text('Remove Feat', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final reasonCtrl = TextEditingController();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text('Remove $name?'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Are you sure you want to remove "$name" from ${controller.character.name}?'),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: reasonCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Reason / Campaign Log Note (Optional)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Remove Feat'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await controller.removeFeat(
                            featSlugToRemove,
                            reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
    String? featSlug,
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
            featSlugToRemove: featSlug,
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

  static List<_ExtractedFeature> _extractFeaturesFromMarkdown(String markdown) {
    if (markdown.trim().isEmpty) return const [];

    final List<_ExtractedFeature> result = [];

    // Case 1: Markdown with headers "### Feature Name (Level X)" or "### Feature Name"
    if (markdown.contains(RegExp(r'(?:^|\n)###\s+'))) {
      final blocks = markdown.split(RegExp(r'(?=(?:^|\n)###\s+)'));
      for (final block in blocks) {
        final trimmed = block.trim();
        if (trimmed.isEmpty) continue;
        final lines = trimmed.split('\n');
        final headerLine = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
        final levelMatch = RegExp(r'^(.*?)(?:\s*\(Level\s+(\d+)\))?$').firstMatch(headerLine);
        final name = levelMatch?.group(1)?.trim() ?? headerLine;
        final level = levelMatch?.group(2) != null ? int.tryParse(levelMatch!.group(2)!) : null;
        final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

        if (name.isNotEmpty && !result.any((r) => r.name.toLowerCase() == name.toLowerCase())) {
          result.add(_ExtractedFeature(
            name: name,
            level: level,
            descriptionMarkdown: body.isNotEmpty ? body : trimmed,
          ));
        }
      }
      if (result.isNotEmpty) return result;
    }

    // Case 2: Markdown with bold bullet / section markers "**Feature Name.** Description..."
    final boldRegex = RegExp(r'\*\*([^*]+?)\.\*\*\s*([\s\S]*?)(?=(?:\n\s*\*\*[^*]+?\.\*)|$)');
    final matches = boldRegex.allMatches(markdown).toList();
    if (matches.isNotEmpty) {
      for (final match in matches) {
        final title = match.group(1)?.trim() ?? '';
        final body = match.group(2)?.trim() ?? '';
        if (title.isNotEmpty && !result.any((r) => r.name.toLowerCase() == title.toLowerCase())) {
          int? level;
          final lvlMatch = RegExp(r'(?:starting at|beginning at|at)\s+(\d+)(?:st|nd|rd|th)\s+level', caseSensitive: false).firstMatch(body);
          if (lvlMatch != null) {
            level = int.tryParse(lvlMatch.group(1)!);
          }
          result.add(_ExtractedFeature(
            name: title,
            level: level,
            descriptionMarkdown: '**$title.** $body',
          ));
        }
      }
      if (result.isNotEmpty) return result;
    }

    return const [];
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

        // Class & Subclass features
        ...character.progression.classes.expand((cls) {
          final widgets = <Widget>[];

          // 1. Resolve Class
          final srdClass = SrdClassesLibrary.findBySlug(cls.classRef.slug) ??
              SrdClassesLibrary.allClasses.where((c) =>
                  c.id.slug == cls.classRef.slug ||
                  c.name.toLowerCase() == cls.classRef.displayName.toLowerCase(),
              ).firstOrNull;

          final classDesc = srdClass?.featuresMarkdown ??
              'Core class features, weapon/armor proficiencies, and archetype specialization at level ${cls.level} of ${cls.classRef.displayName}.';
          final clsType = DndClassType.tryParse(cls.classRef.slug) ??
              DndClassType.tryParse(cls.classRef.displayName) ??
              DndClassType.fighter;

          widgets.add(_buildFeatureChip(
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
          ));

          // 2. Resolve Subclass (if selected)
          if (cls.subclassRef != null) {
            final subSlug = cls.subclassRef!.slug.toLowerCase().trim();
            final subDisplayName = cls.subclassRef!.displayName.trim();
            final subNameLower = subDisplayName.toLowerCase();

            final resolvedSubclass = SrdClassesLibrary.allSubclasses.where((s) =>
                s.id.slug.toLowerCase().trim() == subSlug ||
                s.name.toLowerCase().trim() == subNameLower ||
                s.shortName.toLowerCase().trim() == subNameLower,
            ).firstOrNull;

            final subName = resolvedSubclass?.name ?? subDisplayName;
            final subFeaturesMarkdown = resolvedSubclass?.featuresMarkdown ?? '';

            final extractedSubFeatures = _extractFeaturesFromMarkdown(subFeaturesMarkdown);
            final eligibleSubFeatures = extractedSubFeatures
                .where((f) => f.level == null || f.level! <= cls.level)
                .toList();

            if (eligibleSubFeatures.isNotEmpty) {
              for (final feat in eligibleSubFeatures) {
                widgets.add(_buildFeatureChip(
                  context,
                  name: feat.name,
                  category:
                      '$subName Feature${feat.level != null ? ' (Lvl ${feat.level})' : ''}',
                  descriptionMarkdown: feat.descriptionMarkdown,
                  glyphWidget: DndGlyph.classFeature(
                    classType: clsType,
                    size: 24,
                    isDarkMode: true,
                  ),
                  icon: Icons.workspace_premium,
                  color: Colors.cyanAccent,
                ));
              }
            } else if (subFeaturesMarkdown.isNotEmpty) {
              widgets.add(_buildFeatureChip(
                context,
                name: '$subName (Lvl ${cls.level})',
                category: '${cls.classRef.displayName} Subclass',
                descriptionMarkdown: subFeaturesMarkdown,
                glyphWidget: DndGlyph.classFeature(
                  classType: clsType,
                  size: 24,
                  isDarkMode: true,
                ),
                icon: Icons.workspace_premium,
                color: Colors.cyanAccent,
              ));
            } else {
              widgets.add(_buildFeatureChip(
                context,
                name: subName,
                category: '${cls.classRef.displayName} Subclass',
                descriptionMarkdown: 'Archetype and specialization chosen for ${cls.classRef.displayName}.',
                glyphWidget: DndGlyph.classFeature(
                  classType: clsType,
                  size: 24,
                  isDarkMode: true,
                ),
                icon: Icons.workspace_premium,
                color: Colors.cyanAccent,
              ));
            }
          }

          return widgets;
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'FEATS (${character.feats.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.amberAccent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: Colors.amberAccent),
              label: const Text(
                'Add Feat',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => AddFeatDialog.show(context, controller),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (character.feats.isEmpty)
          InkWell(
            onTap: () => AddFeatDialog.show(context, controller),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech_outlined, size: 18, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text(
                    'No feats added yet. Tap to add a bonus feat.',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else
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
              featSlug: feat.slug,
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
    );
  }
}
