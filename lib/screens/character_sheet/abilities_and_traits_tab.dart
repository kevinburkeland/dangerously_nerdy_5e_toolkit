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
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
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
                          constraints:
                              const BoxConstraints(minWidth: 48, minHeight: 48),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      label: const Text('Remove Feat',
                          style: TextStyle(color: Colors.redAccent)),
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
                                Text(
                                    'Are you sure you want to remove "$name" from ${controller.character.name}?'),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: reasonCtrl,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Reason / Campaign Log Note (Optional)',
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
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Remove Feat'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await controller.removeFeat(
                            featSlugToRemove,
                            reason: reasonCtrl.text.trim().isNotEmpty
                                ? reasonCtrl.text.trim()
                                : null,
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

  static final Map<String, String> _wellKnownClassFeatureDescriptions = {
    'helpful': 'You can take the Help action as a bonus action.',
    'cunning action':
        'You can take a bonus action on each of your turns in combat to take the Dash, Disengage, or Hide action.',
    'second wind':
        'You have a limited well of stamina that you can draw on to protect yourself from harm. On your turn, you can use a bonus action to regain hit points equal to 1d10 + your fighter level.',
    'action surge':
        'On your turn, you can take one additional action on top of your regular action and a possible bonus action.',
    'bardic inspiration':
        'You can inspire others through stirring words or music. Use a bonus action on your turn to choose one creature within 60 feet.',
    'rage':
        'In battle, you fight with primal ferocity. On your turn, you can enter a rage as a bonus action.',
    'flurry of blows':
        'Immediately after you take the Attack action on your turn, you can spend 1 ki point to make two unarmed strikes as a bonus action.',
    'patient defense':
        'You can spend 1 ki point to take the Dodge action as a bonus action on your turn.',
    'step of the wind':
        'You can spend 1 ki point to take the Disengage or Dash action as a bonus action on your turn.',
    'uncanny dodge':
        'When an attacker that you can see hits you with an attack, you can use your reaction to halve the attack\'s damage against you.',
    'deflect missiles':
        'You can use your reaction to deflect or catch the missile when you are hit by a ranged weapon attack.',
  };

  static List<_FeatureDefinition> _extractFeaturesFromMarkdown(
    String markdown, {
    required String defaultCategory,
    int defaultPb = 2,
  }) {
    if (markdown.trim().isEmpty) return const [];
    final List<_FeatureDefinition> result = [];

    const nonFeatureTitles = {
      'action',
      'bonus action',
      'reaction',
      'special',
      'at higher levels',
      'hit',
      'miss',
      'note',
      'saving throw',
      'damage',
    };

    void addOrUpdateFeature({
      required String name,
      required String category,
      required String descriptionMarkdown,
      int? level,
      bool? explicitIsActive,
      int? explicitMaxCharges,
    }) {
      final cleanName = name.trim();
      if (cleanName.isEmpty) return;
      if (nonFeatureTitles.contains(cleanName.toLowerCase())) return;

      final isAct =
          explicitIsActive ?? _isFeatureActive(cleanName, descriptionMarkdown);
      final maxCharges = explicitMaxCharges ??
          _inferMaxCharges(cleanName, descriptionMarkdown,
              defaultPb: defaultPb);

      final existingIndex = result
          .indexWhere((r) => r.name.toLowerCase() == cleanName.toLowerCase());
      if (existingIndex >= 0) {
        final existing = result[existingIndex];
        final existingIsStub =
            existing.descriptionMarkdown.contains('Granted at level') ||
                existing.descriptionMarkdown.length < 50;
        final newHasContent = descriptionMarkdown.trim().isNotEmpty &&
            !descriptionMarkdown.contains('Granted at level');

        if (existingIsStub && newHasContent) {
          result[existingIndex] = _FeatureDefinition(
            name: cleanName,
            category: category.isNotEmpty ? category : existing.category,
            descriptionMarkdown: descriptionMarkdown,
            level: level ?? existing.level,
            isActive: isAct,
            defaultMaxCharges: maxCharges,
          );
        }
      } else {
        result.add(_FeatureDefinition(
          name: cleanName,
          category: category.isNotEmpty ? category : defaultCategory,
          descriptionMarkdown: descriptionMarkdown,
          level: level,
          isActive: isAct,
          defaultMaxCharges: maxCharges,
        ));
      }
    }

    // Pass 1: Header blocks (# to ####) e.g. "### Feature Name (Level X)"
    if (markdown.contains(RegExp(r'(?:^|\n)#{1,4}\s+'))) {
      final blocks = markdown.split(RegExp(r'(?=(?:^|\n)#{1,4}\s+)'));
      for (final block in blocks) {
        final trimmed = block.trim();
        if (trimmed.isEmpty) continue;
        final lines = trimmed.split('\n');
        final headerLine = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();

        String name = headerLine;
        int? level;

        final trailingLevel = RegExp(
          r'^(.*?)(?:\s*[\(:-]\s*(?:(?:Level|Lvl)?\s*(\d+)(?:st|nd|rd|th)?(?:\s*Level)?|(\d+)(?:st|nd|rd|th)?\s*(?:-|–)?\s*(?:Level|lvl))\s*\)?)$',
          caseSensitive: false,
        ).firstMatch(headerLine);

        if (trailingLevel != null) {
          name = trailingLevel.group(1)?.trim() ?? headerLine;
          final lvlStr = trailingLevel.group(2) ?? trailingLevel.group(3);
          if (lvlStr != null) level = int.tryParse(lvlStr);
        } else {
          final leadingLevel = RegExp(
            r'^(?:(?:Level|Lvl)\s*(\d+)|(\d+)(?:st|nd|rd|th)\s*(?:-|–)?\s*(?:Level|lvl))\s*[:\-\)]\s*(.*)$',
            caseSensitive: false,
          ).firstMatch(headerLine);
          if (leadingLevel != null) {
            final lvlStr = leadingLevel.group(1) ?? leadingLevel.group(2);
            if (lvlStr != null) level = int.tryParse(lvlStr);
            name = leadingLevel.group(3)?.trim() ?? headerLine;
          }
        }

        final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

        if (level == null && body.isNotEmpty) {
          final sample = body.length > 300 ? body.substring(0, 300) : body;
          final bodyLvlMatch = RegExp(
            r'(?:starting at|beginning at|at)\s+(\d+)(?:st|nd|rd|th)\s+level',
            caseSensitive: false,
          ).firstMatch(sample);
          if (bodyLvlMatch != null) {
            level = int.tryParse(bodyLvlMatch.group(1)!);
          }
        }

        // Check if this header block contains bold sub-features
        final boldRegex = RegExp(
            r'(?:^|\n)\s*(?:[-*]\s*)?\*\*([^*]+?)(?:\.|\:)?\*\*\s*([\s\S]*?)(?=(?:\n\s*(?:[-*]\s*)?\*\*[^*]+?(?:\.|\:)?\*\*)|$)');
        final subMatches = boldRegex.allMatches(body).where((m) {
          final t = m.group(1)?.trim() ?? '';
          return t.isNotEmpty && !nonFeatureTitles.contains(t.toLowerCase());
        }).toList();

        if (subMatches.length >= 2) {
          for (final subM in subMatches) {
            final subTitle = subM.group(1)?.trim() ?? '';
            final subBody = subM.group(2)?.trim() ?? '';
            addOrUpdateFeature(
              name: subTitle,
              category: defaultCategory,
              descriptionMarkdown: '**$subTitle.** $subBody',
              level: level,
            );
          }
        } else {
          addOrUpdateFeature(
            name: name,
            category: defaultCategory,
            descriptionMarkdown: body.isNotEmpty ? body : trimmed,
            level: level,
          );
        }
      }
    }

    // Pass 2: Bold bullet / section markers "**Feature Name.** Description..."
    final boldRegex = RegExp(
        r'(?:^|\n)\s*(?:[-*]\s*)?\*\*([^*]+?)(?:\.|\:)?\*\*\s*([\s\S]*?)(?=(?:\n\s*(?:[-*]\s*)?\*\*[^*]+?(?:\.|\:)?\*\*)|$)');
    final matches = boldRegex.allMatches(markdown).toList();
    if (matches.isNotEmpty) {
      for (final match in matches) {
        var title = match.group(1)?.trim() ?? '';
        final body = match.group(2)?.trim() ?? '';
        if (title.isEmpty || nonFeatureTitles.contains(title.toLowerCase()))
          continue;

        int? level;
        final trailingLevel = RegExp(
          r'^(.*?)(?:\s*[\(:-]\s*(?:(?:Level|Lvl)?\s*(\d+)(?:st|nd|rd|th)?(?:\s*Level)?|(\d+)(?:st|nd|rd|th)?\s*(?:-|–)?\s*(?:Level|lvl))\s*\)?)$',
          caseSensitive: false,
        ).firstMatch(title);
        if (trailingLevel != null) {
          title = trailingLevel.group(1)?.trim() ?? title;
          final lvlStr = trailingLevel.group(2) ?? trailingLevel.group(3);
          if (lvlStr != null) level = int.tryParse(lvlStr);
        }
        if (level == null && body.isNotEmpty) {
          final sample = body.length > 300 ? body.substring(0, 300) : body;
          final lvlMatch = RegExp(
            r'(?:starting at|beginning at|at)\s+(\d+)(?:st|nd|rd|th)\s+level',
            caseSensitive: false,
          ).firstMatch(sample);
          if (lvlMatch != null) {
            level = int.tryParse(lvlMatch.group(1)!);
          }
        }
        addOrUpdateFeature(
          name: title,
          category: defaultCategory,
          descriptionMarkdown: '**$title.** $body',
          level: level,
        );
      }
    }

    // Pass 3: Pipe-delimited feature strings (fallback / stubs for unexpanded items)
    final pipeRegex6 = RegExp(
      r"(?:^|\n)\s*([A-Za-z0-9\s\(\)'-]+?)\|([A-Za-z0-9\s\(\)'-]*)\|([A-Za-z0-9\s\(\)'-]*)\|([A-Za-z0-9\s\(\)'-]*)\|([A-Za-z0-9\s\(\)'-]*)\|(\d+)",
      multiLine: true,
    );
    for (final match in pipeRegex6.allMatches(markdown)) {
      final featName = match.group(1)?.trim() ?? '';
      final subShort = match.group(4)?.trim() ?? '';
      final lvl = int.tryParse(match.group(6) ?? '1') ?? 1;
      if (featName.isNotEmpty) {
        final fallback =
            _wellKnownClassFeatureDescriptions[featName.toLowerCase()];
        final desc = fallback != null
            ? '**$featName**\n\n$fallback'
            : '**$featName**\n\n*Granted at level $lvl.*';
        addOrUpdateFeature(
          name: featName,
          category: subShort.isNotEmpty ? '$subShort Feature' : defaultCategory,
          descriptionMarkdown: desc,
          level: lvl,
        );
      }
    }

    final pipeRegex4 = RegExp(
      r"(?:^|\n)\s*([A-Za-z0-9\s\(\)'-]+?)\|([A-Za-z0-9\s\(\)'-]*)\|([A-Za-z0-9\s\(\)'-]*)\|(\d+)",
      multiLine: true,
    );
    for (final match in pipeRegex4.allMatches(markdown)) {
      final featName = match.group(1)?.trim() ?? '';
      final clsName = match.group(2)?.trim() ?? '';
      final src = match.group(3)?.trim() ?? '';
      final lvl = int.tryParse(match.group(4) ?? '1') ?? 1;
      if (featName.isNotEmpty) {
        final fallback =
            _wellKnownClassFeatureDescriptions[featName.toLowerCase()];
        final desc = fallback != null
            ? '**$featName**\n\n$fallback'
            : '**$featName**\n\n*Class Feature granted by $clsName ($src) at level $lvl.*';
        addOrUpdateFeature(
          name: featName,
          category: defaultCategory,
          descriptionMarkdown: desc,
          level: lvl,
        );
      }
    }

    return result;
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

    // Action requirement indicators
    if (RegExp(r'\b(?:bonus\s+action|reaction)\b', caseSensitive: false)
            .hasMatch(lowerBody) ||
        RegExp(r'\b(?:as\s+an\s+action|takes?\s+an\s+action|use\s+(?:your\s+)?action|using\s+(?:an|your)\s+action|\baction\s*:|\baction\s*\.|\b1\s+action\b)',
                caseSensitive: false)
            .hasMatch(lowerBody)) {
      return true;
    }

    // Limited use / charge / rest recovery indicators
    if (RegExp(
            r'\b(?:short\s+rest|long\s+rest|charges|times\s+per|uses?\s+per|regains?\s+all\s+expended\s+uses|regains?\s+expended\s+uses|number\s+of\s+times\s+equal\s+to|once\s+per\s+turn|once\s+on\s+each\s+of\s+your\s+turns|\b\d+\s*\/\s*(?:day|rest))\b',
            caseSensitive: false)
        .hasMatch(lowerBody)) {
      return true;
    }

    if (lowerName.contains('(action)') ||
        lowerName.contains('(bonus action)') ||
        lowerName.contains('(reaction)') ||
        lowerName.contains('(special)')) {
      return true;
    }

    return false;
  }

  static int _inferMaxCharges(String name, String body,
      {int defaultPb = 2, int defaultStatMod = 3}) {
    final lower = name.toLowerCase();
    if (lower.contains('action surge')) return 1;
    if (lower.contains('second wind')) return 1;
    if (lower.contains('indomitable')) return 1;
    if (lower.contains('channel divinity')) return 2;
    if (lower.contains('wild shape')) return 2;
    if (lower.contains('rage')) return 3;
    if (lower.contains('bardic inspiration')) return 3;

    final lowerBody = body.toLowerCase();

    // Check for proficiency bonus
    if (lowerBody.contains('proficiency bonus')) {
      return defaultPb;
    }

    // Check for ability modifier
    if (RegExp(
            r'(?:wisdom|charisma|intelligence|constitution|strength|dexterity)\s+modifier',
            caseSensitive: false)
        .hasMatch(lowerBody)) {
      return defaultStatMod;
    }

    // Check for "twice per" / "three times per" / "once per"
    if (RegExp(r'\btwice\b', caseSensitive: false).hasMatch(lowerBody)) {
      return 2;
    }
    if (RegExp(r'\bthree\s+times\b', caseSensitive: false)
        .hasMatch(lowerBody)) {
      return 3;
    }
    if (RegExp(r'\bfour\s+times\b', caseSensitive: false).hasMatch(lowerBody)) {
      return 4;
    }

    // Check for "X/day" or "X / day" or "X/long rest"
    final slashMatch = RegExp(
            r'\b(\d+)\s*\/\s*(?:day|long\s+rest|short\s+rest)\b',
            caseSensitive: false)
        .firstMatch(body);
    if (slashMatch != null) {
      return int.tryParse(slashMatch.group(1)!) ?? 1;
    }

    final match =
        RegExp(r'(\d+)\s+(?:times|charges|uses)', caseSensitive: false)
            .firstMatch(body);
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
    final curCharges = controller.getResourceCharges(feat.name,
        defaultMax: feat.defaultMaxCharges);
    final maxCharges = controller.getResourceMax(feat.name,
        defaultMax: feat.defaultMaxCharges);

    return Semantics(
      label: '${feat.name}. $curCharges of $maxCharges charges remaining.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            // Clickable Header to view feature description
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
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
                        Icon(Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant),
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
                                await controller.updateResourceCharges(
                                    feat.name, i,
                                    max: maxCharges);
                              } else {
                                await controller.updateResourceCharges(
                                    feat.name, i + 1,
                                    max: maxCharges);
                              }
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              child: Center(
                                child: Icon(
                                  isFilled
                                      ? Icons.circle
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: isFilled
                                      ? color
                                      : theme.colorScheme.outlineVariant,
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
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: curCharges > 0
                            ? Colors.redAccent
                            : theme.colorScheme.outlineVariant,
                        onPressed: curCharges > 0
                            ? () async {
                                HapticService.heavyImpact(context);
                                await controller.expendResourceCharge(feat.name,
                                    defaultMax: maxCharges);
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
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: curCharges < maxCharges
                            ? Colors.greenAccent
                            : theme.colorScheme.outlineVariant,
                        onPressed: curCharges < maxCharges
                            ? () async {
                                HapticService.selectionTick(context);
                                await controller.recoverResourceCharge(
                                    feat.name,
                                    defaultMax: maxCharges);
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
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.6)),
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
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
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
        final bg =
            bgSlug.isNotEmpty ? SrdBackgroundsLibrary.findBySlug(bgSlug) : null;
        final bgName =
            character.backgroundRef?.displayName ?? (bg?.name ?? 'Background');
        final bgFeatureName =
            character.customProperties['backgroundFeature']?.toString();
        final bgFeatureDesc = character
            .customProperties['backgroundFeatureDescription']
            ?.toString();
        var bgDesc = bg != null
            ? SrdBackgroundsLibrary.getDescriptionForBackground(
                bg,
                ruleset: is2014 ? RulesetVersion.v2014 : RulesetVersion.v2024,
              )
            : (is2014
                ? 'Narrative background, starting proficiencies, and personal history.'
                : 'Narrative background, origin identity, starting proficiencies, and personal history.');
        if (is2014 && bgFeatureName != null && bgFeatureName.isNotEmpty) {
          if (!bgDesc.toLowerCase().contains(bgFeatureName.toLowerCase())) {
            final featBlock =
                '**Feature: $bgFeatureName**\n${bgFeatureDesc ?? ''}';
            bgDesc =
                bgDesc.trim().isEmpty ? featBlock : '$bgDesc\n\n$featBlock';
          }
        }

        // 3. Collect Class & Subclass Features
        final activeFeatures = <_FeatureDefinition>[];
        final passiveFeatures = <_FeatureDefinition>[];

        for (final cls in character.progression.classes) {
          final srdClass = SrdClassesLibrary.findBySlug(cls.classRef.slug) ??
              SrdClassesLibrary.allClasses
                  .where(
                    (c) =>
                        c.id.slug == cls.classRef.slug ||
                        c.name.toLowerCase() ==
                            cls.classRef.displayName.toLowerCase(),
                  )
                  .firstOrNull;

          final classDesc = srdClass?.featuresMarkdown ??
              'Core class features, weapon/armor proficiencies, and archetype specialization at level ${cls.level} of ${cls.classRef.displayName}.';

          final extractedClassFeatures = _extractFeaturesFromMarkdown(
            classDesc,
            defaultCategory: '${cls.classRef.displayName} Feature',
            defaultPb: character.proficiencyBonus,
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

            final resolvedSubclass = SrdClassesLibrary.findSubclass(
              subSlug,
              classSlug: cls.classRef.slug,
              displayName: subDisplayName,
              ruleset: is2014 ? RulesetVersion.v2014 : RulesetVersion.v2024,
            );

            final subName = resolvedSubclass?.name ??
                (subDisplayName.isNotEmpty ? subDisplayName : 'Subclass');
            var subFeaturesMarkdown = (resolvedSubclass != null &&
                    resolvedSubclass.featuresMarkdown.isNotEmpty)
                ? resolvedSubclass.featuresMarkdown
                : (cls.subclassRef?.customProperties['featuresMarkdown']
                        ?.toString() ??
                    '');
            if (resolvedSubclass != null &&
                (subFeaturesMarkdown.isEmpty ||
                    subFeaturesMarkdown.contains('Granted at level'))) {
              final stitched =
                  SrdClassesLibrary.buildFeaturesMarkdownForSubclass(
                resolvedSubclass,
                ruleset: is2014 ? RulesetVersion.v2014 : RulesetVersion.v2024,
              );
              if (stitched.isNotEmpty) {
                subFeaturesMarkdown = stitched;
              }
            }
            final extractedSub = _extractFeaturesFromMarkdown(
              subFeaturesMarkdown,
              defaultCategory: '$subName Feature',
              defaultPb: character.proficiencyBonus,
            );

            final cleanClassSlug = cls.classRef.slug.toLowerCase().trim();
            final subclassMinLevel = srdClass?.getSubclassLevel(
                    is2014 ? RulesetVersion.v2014 : RulesetVersion.v2024) ??
                (is2014 &&
                        (cleanClassSlug.contains('warlock') ||
                            cleanClassSlug.contains('cleric') ||
                            cleanClassSlug.contains('sorcerer'))
                    ? 1
                    : is2014 &&
                            (cleanClassSlug.contains('druid') ||
                                cleanClassSlug.contains('wizard'))
                        ? 2
                        : 3);

            for (final feat in extractedSub) {
              final requiredLevel = feat.level ?? subclassMinLevel;
              if (requiredLevel <= cls.level) {
                if (feat.isActive) {
                  activeFeatures.add(feat);
                } else {
                  passiveFeatures.add(feat);
                }
              }
            }

            if (extractedSub.isEmpty) {
              if (cls.level >= subclassMinLevel) {
                passiveFeatures.add(_FeatureDefinition(
                  name: '$subName (Lvl ${cls.level})',
                  category: '${cls.classRef.displayName} Subclass',
                  descriptionMarkdown: subFeaturesMarkdown.isNotEmpty
                      ? subFeaturesMarkdown
                      : 'Specialization archetype chosen at level $subclassMinLevel.',
                ));
              }
            }
          }
        }

        // Selected options (Invocations, Fighting Styles, etc.)
        final allSelectedOptions =
            character.progression.getAllSelectedFeatureOptions();
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
                  descriptionMarkdown:
                      'Selected character customization option for ${decisionId.replaceAll('-', ' ')}.',
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
              defaultMaxCharges: _inferMaxCharges(
                  opt.name, opt.descriptionMarkdown,
                  defaultPb: character.proficiencyBonus),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
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
                const Icon(Icons.shield_outlined,
                    size: 18, color: Colors.tealAccent),
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

            // 2014 Background Feature Chip
            if (is2014 && bgFeatureName != null && bgFeatureName.isNotEmpty)
              _buildPassiveTraitChip(
                context,
                name: bgFeatureName,
                category: 'Background Feature',
                descriptionMarkdown: bgFeatureDesc?.isNotEmpty == true
                    ? bgFeatureDesc!
                    : 'Granted by the $bgName background.',
                glyphWidget: DndGlyph.genericUi(
                  uiType: GenericUiGlyphType.d20,
                  size: 24,
                  isDarkMode: true,
                ),
                icon: Icons.auto_stories,
                color: Colors.amberAccent,
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
                    const Icon(Icons.military_tech_outlined,
                        size: 18, color: Colors.purpleAccent),
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
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add,
                          size: 16, color: Colors.purpleAccent),
                      label: const Text(
                        'Add Feat',
                        style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.military_tech_outlined,
                          size: 18, color: Colors.purpleAccent),
                      SizedBox(width: 8),
                      Text(
                        'No feats added yet. Tap to add a feat.',
                        style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...character.feats.map((feat) {
                final srdFeat = SrdFeatsLibrary.findBySlug(feat.slug);
                final rawCategory = srdFeat?.category ?? 'Feat';
                final category = (is2014 &&
                        rawCategory.toLowerCase() == 'origin')
                    ? 'Feat'
                    : (srdFeat != null ? '${srdFeat.category} Feat' : 'Feat');
                final featCat = FeatCategory.parse(category);
                final desc = srdFeat?.descriptionMarkdown ??
                    'Feat granting specialized combat or exploration prowess.';

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
