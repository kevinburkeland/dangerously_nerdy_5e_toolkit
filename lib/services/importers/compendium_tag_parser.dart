import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Result of transforming community compendium entries and inline tags
class ParsedTextResult {
  final String cleanMarkdown;
  final List<EvaluationMath> extractedMath;
  final List<EntityReference<DomainEntity>> extractedReferences;

  const ParsedTextResult({
    required this.cleanMarkdown,
    this.extractedMath = const [],
    this.extractedReferences = const [],
  });
}

/// Robust parser for community compendium JSON tags, entries AST, and source detection.
class CompendiumTagParser {
  static final RegExp tagPattern = RegExp(r'\{@([a-zA-Z0-9_-]+)\s+([^}]+)\}');

  /// Detects whether a given source tag originates from 2014, 2024, or third-party/homebrew.
  RulesetVersion detectRuleset(
    String? source, {
    RulesetVersion fallback = RulesetVersion.v2024,
  }) {
    if (source == null || source.trim().isEmpty) return fallback;
    final s = source.trim().toUpperCase();

    // 2024 Revised ruleset sources
    if (s.contains('XPHB') ||
        s.contains('SRD52') ||
        s.contains('XDMG') ||
        s.contains('XMM') ||
        s == '2024' ||
        s.contains('FREE RULES (2024)')) {
      return RulesetVersion.v2024;
    }

    // 2014 Legacy ruleset sources
    if (s.contains('PHB') ||
        s.contains('SRD') ||
        s.contains('DMG') ||
        s.contains('MM') ||
        s.contains('VGM') ||
        s.contains('XGE') ||
        s.contains('TCE') ||
        s.contains('MTF') ||
        s == '2014') {
      return RulesetVersion.v2014;
    }

    return RulesetVersion.homebrew;
  }

  /// Parses arbitrary entry nodes (String, List, Map) into clean Markdown with extracted math & refs.
  ParsedTextResult parseEntries(
    dynamic entries, {
    RulesetVersion defaultRuleset = RulesetVersion.v2024,
    int maxDepth = 10,
  }) {
    final List<EvaluationMath> mathList = [];
    final List<EntityReference<DomainEntity>> refsList = [];
    final buffer = StringBuffer();

    _parseNode(entries, buffer, mathList, refsList, 0, defaultRuleset, maxDepth);

    return ParsedTextResult(
      cleanMarkdown: buffer.toString().trim(),
      extractedMath: List.unmodifiable(mathList),
      extractedReferences: List.unmodifiable(refsList),
    );
  }

  void _parseNode(
    dynamic node,
    StringBuffer buffer,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    int depth,
    RulesetVersion defaultRuleset,
    int maxDepth,
  ) {
    if (node == null || depth > maxDepth) return;

    if (node is String) {
      buffer.writeln(processTags(node, math: math, refs: refs, defaultRuleset: defaultRuleset));
      buffer.writeln();
    } else if (node is List) {
      for (final item in node) {
        _parseNode(item, buffer, math, refs, depth, defaultRuleset, maxDepth);
      }
    } else if (node is Map<String, dynamic>) {
      final type = node['type'] as String?;
      final name = node['name'] as String?;

      if (name != null && name.isNotEmpty) {
        final prefix = '#' * (depth + 3).clamp(1, 6);
        buffer.writeln('$prefix $name');
        buffer.writeln();
      }

      switch (type) {
        case 'entries':
        case 'section':
          _parseNode(node['entries'], buffer, math, refs, depth + 1, defaultRuleset, maxDepth);

        case 'inset':
          buffer.writeln('> ');
          _parseNode(node['entries'], buffer, math, refs, depth + 1, defaultRuleset, maxDepth);

        case 'list':
          final items = node['items'] as List? ?? [];
          for (final item in items) {
            buffer.write('- ');
            _parseNode(item, buffer, math, refs, depth, defaultRuleset, maxDepth);
          }

        case 'table':
          buffer.writeln(parseTableNode(node, math: math, refs: refs, defaultRuleset: defaultRuleset));
          buffer.writeln();

        default:
          if (node.containsKey('entries')) {
            _parseNode(node['entries'], buffer, math, refs, depth + 1, defaultRuleset, maxDepth);
          } else if (node.containsKey('entry')) {
            _parseNode(node['entry'], buffer, math, refs, depth, defaultRuleset, maxDepth);
          }
      }
    }
  }

  /// Processes inline compendium tags like {@damage 1d8}, {@spell Fireball}, {@dice 1d20+3}.
  String processTags(
    String input, {
    List<EvaluationMath>? math,
    List<EntityReference<DomainEntity>>? refs,
    RulesetVersion defaultRuleset = RulesetVersion.v2024,
  }) {
    return input.replaceAllMapped(tagPattern, (match) {
      final tag = match.group(1)?.toLowerCase() ?? '';
      final payload = match.group(2) ?? '';
      final parts = payload.split('|');
      final primary = parts.isNotEmpty ? parts[0].trim() : '';

      switch (tag) {
        case 'damage':
          final parsedMath = extractDamageMath(payload);
          if (parsedMath != null && math != null) {
            math.add(parsedMath);
          }
          return primary;

        case 'dice':
        case 'hit':
        case 'd20':
        case 'scaledice':
        case 'scaledamage':
          return primary;

        case 'spell':
          if (refs != null && primary.isNotEmpty) {
            final source = parts.length > 1 ? parts[1].trim() : null;
            final ruleset = detectRuleset(source, fallback: defaultRuleset);
            refs.add(EntityReference<Spell>(
              refType: EntityType.spell,
              slug: primary.toLowerCase().replaceAll(' ', '-'),
              displayName: primary,
              rulesetPreferred: ruleset,
            ));
          }
          return parts.length > 2 ? parts[2].trim() : primary;

        case 'creature':
        case 'monster':
          if (refs != null && primary.isNotEmpty) {
            final source = parts.length > 1 ? parts[1].trim() : null;
            final ruleset = detectRuleset(source, fallback: defaultRuleset);
            refs.add(EntityReference<Monster>(
              refType: EntityType.monster,
              slug: primary.toLowerCase().replaceAll(' ', '-'),
              displayName: primary,
              rulesetPreferred: ruleset,
            ));
          }
          return parts.length > 2 ? parts[2].trim() : primary;

        case 'item':
          if (refs != null && primary.isNotEmpty) {
            final source = parts.length > 1 ? parts[1].trim() : null;
            final ruleset = detectRuleset(source, fallback: defaultRuleset);
            refs.add(EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: primary.toLowerCase().replaceAll(' ', '-'),
              displayName: primary,
              rulesetPreferred: ruleset,
            ));
          }
          return parts.length > 2 ? parts[2].trim() : primary;

        case 'condition':
        case 'status':
        case 'sense':
        case 'skill':
        case 'action':
        case 'feat':
        case 'background':
        case 'race':
        case 'class':
        case 'subclass':
          return parts.length > 2 ? parts[2].trim() : primary;

        case 'b':
        case 'bold':
          return '**$primary**';

        case 'i':
        case 'italic':
        case 'em':
          return '*$primary*';

        case 'strike':
          return '~~$primary~~';

        case 'code':
          return '`$primary`';

        case 'note':
          return '> **Note:** $primary';

        default:
          return primary;
      }
    });
  }

  /// Strips all compendium inline tags without capturing math or references.
  String stripTags(String text) {
    return processTags(text);
  }

  /// Extracts structured damage formula and damage type from a tag argument string.
  EvaluationMath? extractDamageMath(String tagArgs) {
    if (tagArgs.isEmpty) return null;
    final parts = tagArgs.split('|');
    final formula = parts[0].trim();
    if (formula.isEmpty) return null;

    DamageType type = DamageType.untyped;
    if (parts.length > 1) {
      final typeStr = parts[1].trim().toLowerCase();
      type = DamageType.values.firstWhere(
        (d) => d.name.toLowerCase() == typeStr,
        orElse: () => DamageType.untyped,
      );
    }

    return EvaluationMath(
      diceFormula: formula,
      damageType: type,
    );
  }

  /// Renders a compendium table AST node into clean GitHub-flavored markdown.
  String parseTableNode(
    Map<String, dynamic> tableMap, {
    List<EvaluationMath>? math,
    List<EntityReference<DomainEntity>>? refs,
    RulesetVersion defaultRuleset = RulesetVersion.v2024,
  }) {
    final buffer = StringBuffer();
    final caption = tableMap['caption'] as String?;
    if (caption != null && caption.isNotEmpty) {
      buffer.writeln('**$caption**\n');
    }

    final colLabels = (tableMap['colLabels'] as List? ?? [])
        .map((e) => processTags(e.toString(), math: math, refs: refs, defaultRuleset: defaultRuleset))
        .toList();

    if (colLabels.isNotEmpty) {
      buffer.writeln('| ${colLabels.join(' | ')} |');
      buffer.writeln('| ${colLabels.map((_) => '---').join(' | ')} |');
    }

    final rows = tableMap['rows'] as List? ?? [];
    for (final row in rows) {
      if (row is List) {
        final rowCells = row
            .map((cell) => processTags(
                  cell?.toString() ?? '',
                  math: math,
                  refs: refs,
                  defaultRuleset: defaultRuleset,
                ).replaceAll('\n', ' '))
            .toList();
        buffer.writeln('| ${rowCells.join(' | ')} |');
      }
    }

    return buffer.toString().trim();
  }
}
