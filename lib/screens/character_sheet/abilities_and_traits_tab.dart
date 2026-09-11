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
import '../../widgets/character_sheet/add_feat_dialog.dart';
import '../../widgets/common/formatted_markdown_text.dart';
import '../../widgets/glyphs/dnd_glyph.dart';
import '../../widgets/glyphs/glyph_tokens.dart';

@immutable
class _FeatureDefinition {
  final String name;
  final String category;
  final String descriptionMarkdown;
  final int? level;
  final bool isActive;
  final int defaultMaxCharges;

  const _FeatureDefinition({
    required this.name,
    required this.category,
    required this.descriptionMarkdown,
    this.level,
    this.isActive = false,
    this.defaultMaxCharges = 1,
  });
}

/// Dedicated Abilities & Traits Tab separating Active Features (with charge tracking),
/// Passive Traits & Lineage, and Feats into clear, accessible sections.
class AbilitiesAndTraitsTab extends StatelessWidget {
  final CharacterSheetController controller;

  const AbilitiesAndTraitsTab({
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
                FormattedMarkdownText(
                  descriptionMarkdown,
                  defaultColor: theme.colorScheme.onSurface,
                ),
                const SizedBox(height: 20),
                if (featSlugToRemove != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size(double.infinity, 48),
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

  static List<_FeatureDefinition> _extractFeaturesFromMarkdown(
    String markdown, {
    required String defaultCategory,
  }) {
    if (markdown.trim().isEmpty) return const [];
    final List<_FeatureDefinition> result = [];

    // Case 1: Markdown with headers "### Feature Name (Level X)"
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
          final isAct = _isFeatureActive(name, body);
          final maxCharges = _inferMaxCharges(name, body);
          result.add(_FeatureDefinition(
            name: name,
            category: defaultCategory,
            descriptionMarkdown: body.isNotEmpty ? body : trimmed,
            level: level,
            isActive: isAct,
            defaultMaxCharges: maxCharges,
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
          final isAct = _isFeatureActive(title, body);
          final maxCharges = _inferMaxCharges(title, body);
          result.add(_FeatureDefinition(
            name: title,
            category: defaultCategory,
            descriptionMarkdown: '**$title.** $body',
            level: level,
            isActive: isAct,
            defaultMaxCharges: maxCharges,
          ));
        }
      }
      if (result.isNotEmpty) return result;
    }

    return const [];
  }

  static bool _isFeatureActive(String name, String body) {
    final lowerName = name.toLowerCase();
    final lowerBody = body.toLowerCase();

    // Explicit known active features with charges
    if (lowerName.contains('action surge') ||
        lowerName.contains('second wind') ||
        lowerName.contains('indomitable') ||
        lowerName.contains('channel divinity') ||
        lowerName.contains('rage') ||
        lowerName.contains('wild shape') ||
        lowerName.contains('bardic inspiration') ||
        lowerName.contains('lay on hands') ||
        lowerName.contains('ki') ||
        lowerName.contains('sorcery points') ||
        lowerName.contains('cunning action') ||
        lowerName.contains('divine smite')) {
      return true;
    }

    if (lowerBody.contains('short rest') ||
        lowerBody.contains('long rest') ||
        lowerBody.contains('times per') ||
        lowerBody.contains('charges') ||
        lowerBody.contains('as an action') ||
        lowerBody.contains('as a bonus action') ||
        lowerBody.contains('as a reaction')) {
      return true;
    }

    return false;
  }

  static int _inferMaxCharges(String name, String body) {
    final lower = name.toLowerCase();
    if (lower.contains('action surge')) return 1;
    if (lower.contains('second wind')) return 1;
    if (lower.contains('indomitable')) return 1;
    if (lower.contains('channel divinity')) return 2;
    if (lower.contains('wild shape')) return 2;
    if (lower.contains('rage')) return 3;
    if (lower.contains('bardic inspiration')) return 3;

    final match = RegExp(r'(\d+)\s+(?:times|charges|uses)', caseSensitive: false).firstMatch(body);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  Widget _buildActiveFeatureCard(
    BuildContext context,
    _FeatureDefinition feat, {
    required Color color,
    Widget? glyphWidget,
  }) {
    final theme = Theme.of(context);
    final curCharges = controller.getResourceCharges(feat.name, defaultMax: feat.defaultMaxCharges);
    final maxCharges = controller.getResourceMax(feat.name, defaultMax: feat.defaultMaxCharges);

    return Semantics(
      label: '${feat.name}. $curCharges of $maxCharges charges remaining.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            // Clickable Header to view feature description
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                onTap: () => _showFeatureDetailModal(
                  context,
                  name: feat.name,
                  category: feat.category,
                  descriptionMarkdown: feat.descriptionMarkdown,
                  glyphWidget: glyphWidget,
                  accentColor: color,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            child: Icon(Icons.flash_on, color: color, size: 18),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feat.name,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${feat.category} • Tap for details',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Interactive Charge Tracking Pips & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Interactive Pips
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: List.generate(maxCharges, (i) {
                        final isFilled = i < curCharges;
                        return Semantics(
                          button: true,
                          label: isFilled
                              ? 'Slot ${i + 1} of $maxCharges ready. Tap to expend.'
                              : 'Slot ${i + 1} of $maxCharges expended. Tap to recover.',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              HapticService.selectionTick(context);
                              if (isFilled) {
                                await controller.updateResourceCharges(feat.name, i, max: maxCharges);
                              } else {
                                await controller.updateResourceCharges(feat.name, i + 1, max: maxCharges);
                              }
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              child: Center(
                                child: Icon(
                                  isFilled ? Icons.circle : Icons.circle_outlined,
                                  size: 20,
                                  color: isFilled ? color : theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Decrement Button (min 48x48dp)
                  Semantics(
                    button: true,
                    enabled: curCharges > 0,
                    label: 'Use ${feat.name} charge',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: curCharges > 0 ? Colors.redAccent : theme.colorScheme.outlineVariant,
                        onPressed: curCharges > 0
                            ? () async {
                                HapticService.heavyImpact(context);
                                await controller.expendResourceCharge(feat.name, defaultMax: maxCharges);
                              }
                            : null,
                      ),
                    ),
                  ),

                  // Count indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$curCharges / $maxCharges',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: curCharges > 0 ? color : Colors.redAccent,
                      ),
                    ),
                  ),

                  // Increment Button (min 48x48dp)
                  Semantics(
                    button: true,
                    enabled: curCharges < maxCharges,
                    label: 'Recover ${feat.name} charge',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: curCharges < maxCharges ? Colors.greenAccent : theme.colorScheme.outlineVariant,
                        onPressed: curCharges < maxCharges
                            ? () async {
                                HapticService.selectionTick(context);
                                await controller.recoverResourceCharge(feat.name, defaultMax: maxCharges);
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassiveTraitChip(
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final character = controller.character;
        final is2014 = character.rulesEdition == DmRulesEdition.v2014 ||
            character.id.ruleset == RulesetVersion.v2014;

        // 1. Resolve Species details
        final race = SrdSpeciesLibrary.findBySlug(character.speciesRef.slug);
        final speciesDesc = (is2014 && race?.id.slug == 'human')
            ? '**Ability Score Increase.** Your ability scores each increase by 1.\n\n**Languages.** You can speak, read, and write Common and one extra language of your choice.'
            : (race?.traitsMarkdown ??
                'Inherent physical, physiological, and biological traits granted by the ${character.speciesRef.displayName} species lineage.');

        // 2. Resolve Background details
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

        // 3. Collect Class & Subclass Features
        final activeFeatures = <_FeatureDefinition>[];
        final passiveFeatures = <_FeatureDefinition>[];

        for (final cls in character.progression.classes) {
          final srdClass = SrdClassesLibrary.findBySlug(cls.classRef.slug) ??
              SrdClassesLibrary.allClasses.where((c) =>
                  c.id.slug == cls.classRef.slug ||
                  c.name.toLowerCase() == cls.classRef.displayName.toLowerCase(),
              ).firstOrNull;

          final classDesc = srdClass?.featuresMarkdown ??
              'Core class features, weapon/armor proficiencies, and archetype specialization at level ${cls.level} of ${cls.classRef.displayName}.';

          final extractedClassFeatures = _extractFeaturesFromMarkdown(
            classDesc,
            defaultCategory: '${cls.classRef.displayName} Feature',
          );

          for (final feat in extractedClassFeatures) {
            if (feat.level == null || feat.level! <= cls.level) {
              if (feat.isActive) {
                activeFeatures.add(feat);
              } else {
                passiveFeatures.add(feat);
              }
            }
          }

          // If no subfeatures parsed from class markdown, add general class item
          if (extractedClassFeatures.isEmpty) {
            passiveFeatures.add(_FeatureDefinition(
              name: '${cls.classRef.displayName} Features (Lvl ${cls.level})',
              category: 'Class Feature',
              descriptionMarkdown: classDesc,
            ));
          }

          // Subclass
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
            final extractedSub = _extractFeaturesFromMarkdown(
              subFeaturesMarkdown,
              defaultCategory: '$subName Feature',
            );

            for (final feat in extractedSub) {
              if (feat.level == null || feat.level! <= cls.level) {
                if (feat.isActive) {
                  activeFeatures.add(feat);
                } else {
                  passiveFeatures.add(feat);
                }
              }
            }

            if (extractedSub.isEmpty && subFeaturesMarkdown.isNotEmpty) {
              passiveFeatures.add(_FeatureDefinition(
                name: '$subName (Lvl ${cls.level})',
                category: '${cls.classRef.displayName} Subclass',
                descriptionMarkdown: subFeaturesMarkdown,
              ));
            }
          }
        }

        // Selected options (Invocations, Fighting Styles, etc.)
        final allSelectedOptions = character.progression.getAllSelectedFeatureOptions();
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
            final displayCategory = decisionId.startsWith('feat-')
                ? 'FEAT: ${decisionId.substring(5).replaceAll('-', ' ').toUpperCase()}'
                : decisionId.replaceAll('-', ' ').toUpperCase();

            final isAct = _isFeatureActive(opt.name, opt.descriptionMarkdown);
            final featDef = _FeatureDefinition(
              name: opt.name,
              category: displayCategory,
              descriptionMarkdown: opt.descriptionMarkdown,
              isActive: isAct,
              defaultMaxCharges: _inferMaxCharges(opt.name, opt.descriptionMarkdown),
            );

            if (isAct) {
              activeFeatures.add(featDef);
            } else {
              passiveFeatures.add(featDef);
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ========================================================
            // SECTION 1: ACTIVE FEATURES & RESOURCE CHARGES
            // ========================================================
            Row(
              children: [
                const Icon(Icons.bolt, size: 18, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE FEATURES & CHARGES',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (activeFeatures.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No limited-use active features recorded for current level.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...activeFeatures.map((f) => _buildActiveFeatureCard(
                    context,
                    f,
                    color: Colors.amberAccent,
                  )),

            const SizedBox(height: 16),

            // ========================================================
            // SECTION 2: PASSIVE TRAITS & LINEAGE
            // ========================================================
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text(
                  'PASSIVE TRAITS & LINEAGE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.tealAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Species Traits Chip
            _buildPassiveTraitChip(
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
            _buildPassiveTraitChip(
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

            // Class & Subclass Passive Features
            ...passiveFeatures.map((f) => _buildPassiveTraitChip(
                  context,
                  name: f.name,
                  category: f.category,
                  descriptionMarkdown: f.descriptionMarkdown,
                  icon: Icons.workspace_premium,
                  color: Colors.cyanAccent,
                )),

            const SizedBox(height: 16),

            // ========================================================
            // SECTION 3: FEATS
            // ========================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech_outlined, size: 18, color: Colors.purpleAccent),
                    const SizedBox(width: 8),
                    Text(
                      'FEATS (${character.feats.length})',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
                Semantics(
                  button: true,
                  label: 'Add a new bonus feat',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: Colors.purpleAccent),
                      label: const Text(
                        'Add Feat',
                        style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => AddFeatDialog.show(context, controller),
                    ),
                  ),
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
                    color: Colors.purple.shade900.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.military_tech_outlined, size: 18, color: Colors.purpleAccent),
                      SizedBox(width: 8),
                      Text(
                        'No feats added yet. Tap to add a feat.',
                        style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.w600),
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

                return _buildPassiveTraitChip(
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
                  color: Colors.purpleAccent,
                );
              }),
          ],
        );
      },
    );
  }
}

