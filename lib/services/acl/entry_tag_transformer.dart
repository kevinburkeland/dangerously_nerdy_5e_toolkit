import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Result of transforming polymorphic compendium entries
class ParsedEntryResult {
  final String markdown;
  final List<EvaluationMath> extractedMath;
  final List<EntityReference<DomainEntity>> extractedRefs;

  const ParsedEntryResult({
    required this.markdown,
    required this.extractedMath,
    required this.extractedRefs,
  });
}

/// Anti-Corruption Layer (ACL) Transformer for standard compendium polymorphic entries and inline markup tags.
class EntryTagTransformer {
  static final RegExp _tagRegex = RegExp(r'\{@([a-zA-Z0-9_-]+)\s+([^}]+)\}');

  /// Main recursive AST entry point.
  ParsedEntryResult transformEntries(
    dynamic entries, {
    RulesetVersion defaultRuleset = RulesetVersion.v2024,
  }) {
    final List<EvaluationMath> mathList = [];
    final List<EntityReference<DomainEntity>> refsList = [];
    final buffer = StringBuffer();

    _parseNode(entries, buffer, mathList, refsList, 0, defaultRuleset);

    return ParsedEntryResult(
      markdown: buffer.toString().trim(),
      extractedMath: List.unmodifiable(mathList),
      extractedRefs: List.unmodifiable(refsList),
    );
  }

  void _parseNode(
    dynamic node,
    StringBuffer buffer,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    int depth,
    RulesetVersion defaultRuleset,
  ) {
    if (node == null) return;

    if (node is String) {
      buffer.writeln(_processTags(node, math, refs, defaultRuleset));
      buffer.writeln();
    } else if (node is List) {
      for (final item in node) {
        _parseNode(item, buffer, math, refs, depth, defaultRuleset);
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
        case 'inset':
          if (type == 'inset') buffer.writeln('> ');
          _parseNode(node['entries'], buffer, math, refs, depth + 1, defaultRuleset);
          break;

        case 'list':
          final items = node['items'] as List? ?? [];
          for (final item in items) {
            buffer.write('- ');
            _parseNode(item, buffer, math, refs, depth, defaultRuleset);
          }
          break;

        case 'table':
          _renderTable(node, buffer, math, refs, defaultRuleset);
          break;

        default:
          if (node.containsKey('entries')) {
            _parseNode(node['entries'], buffer, math, refs, depth + 1, defaultRuleset);
          } else if (node.containsKey('entry')) {
            _parseNode(node['entry'], buffer, math, refs, depth, defaultRuleset);
          }
      }
    }
  }

  void _renderTable(
    Map<String, dynamic> tableNode,
    StringBuffer buffer,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    RulesetVersion defaultRuleset,
  ) {
    final colLabels =
        (tableNode['colLabels'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rows = tableNode['rows'] as List? ?? [];

    if (colLabels.isNotEmpty) {
      buffer.writeln('| ${colLabels.join(' | ')} |');
      buffer.writeln('| ${colLabels.map((_) => '---').join(' | ')} |');
    }

    for (final row in rows) {
      if (row is List) {
        final processedRow = row.map((cell) {
          final cellStr = cell.toString();
          return _processTags(cellStr, math, refs, defaultRuleset).replaceAll('\n', ' ');
        }).join(' | ');
        buffer.writeln('| $processedRow |');
      }
    }
    buffer.writeln();
  }

  /// Strip/convert compendium inline tags into clean markdown and strongly-typed objects.
  String _processTags(
    String input,
    List<EvaluationMath> mathList,
    List<EntityReference<DomainEntity>> refsList,
    RulesetVersion defaultRuleset,
  ) {
    return input.replaceAllMapped(_tagRegex, (match) {
      final tag = match.group(1)?.toLowerCase();
      final content = match.group(2) ?? '';
      final parts = content.split('|');
      final primary = parts[0].trim();

      switch (tag) {
        case 'dice':
          return '**`$primary`**';

        case 'damage':
          final dmgType = _extractDamageType(parts);
          mathList.add(EvaluationMath(
            diceFormula: primary,
            damageType: dmgType,
          ));
          return '**`$primary ${dmgType.name}`**';

        case 'scaledamage':
        case 'scaledice':
          final baseDice = parts.length > 1 ? parts[1].trim() : primary;
          final scalingDice = parts.length > 2 ? parts[2].trim() : primary;
          mathList.add(EvaluationMath(
            diceFormula: baseDice,
            damageType: _extractDamageType(parts),
            scalingFormula: scalingDice,
          ));
          return '**`$baseDice`** *(scales: $scalingDice)*';

        case 'spell':
          final slug = _slugify(primary);
          final ruleset = _mapSourceToRuleset(
            parts.length > 1 ? parts[1] : null,
            defaultRuleset,
          );
          refsList.add(EntityReference<Spell>(
            refType: EntityType.spell,
            slug: slug,
            displayName: primary,
            rulesetPreferred: ruleset,
          ));
          return '[$primary](ref://spell/$slug)';

        case 'item':
          final slug = _slugify(primary);
          refsList.add(EntityReference<EquipmentItem>(
            refType: EntityType.equipment,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://equipment/$slug)';

        case 'creature':
          final slug = _slugify(primary);
          refsList.add(EntityReference<Monster>(
            refType: EntityType.monster,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://monster/$slug)';

        case 'condition':
        case 'status':
          return '**$primary**';

        case 'dc':
          return 'DC $primary';

        case 'quickref':
        case 'filter':
          return primary;

        default:
          return primary;
      }
    });
  }

  DamageType _extractDamageType(List<String> parts) {
    for (int i = 1; i < parts.length; i++) {
      final candidate = parts[i].trim().toLowerCase();
      final match = DamageType.values.where((e) => e.name == candidate);
      if (match.isNotEmpty) {
        return match.first;
      }
    }
    return DamageType.untyped;
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  RulesetVersion _mapSourceToRuleset(String? source, RulesetVersion defaultRuleset) {
    if (source == null || source.isEmpty) return defaultRuleset;
    final s = source.toUpperCase();
    if (s.contains('XPHB') || s.contains('SRD52')) return RulesetVersion.v2024;
    if (s.contains('PHB') || s.contains('SRD')) return RulesetVersion.v2014;
    return defaultRuleset;
  }
}
