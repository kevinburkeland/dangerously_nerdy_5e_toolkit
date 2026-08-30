import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Result of transforming polymorphic compendium entries.
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

/// Universal recursive Anti-Corruption Layer transformer for community
/// compendium AST entry trees.
///
/// Correctly handles all standard node types:
///   `entries`, `section`, `inset`, `list`, `table`,
///   `abilityGeneric`, `abilityScore`, `cell`, `row`.
///
/// All inline tags (`{@spell …}`, `{@dice …}`, `{@item …}`, etc.) are
/// stripped to clean Markdown / strongly-typed objects.
class EntryNodeTransformer {
  static final RegExp _tagRegex = RegExp(r'\{@([a-zA-Z0-9_-]+)\s+([^}]+)\}');

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  /// Transforms an arbitrary AST node or tree into a [ParsedEntryResult].
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

  // ---------------------------------------------------------------------------
  // Core recursive parser
  // ---------------------------------------------------------------------------

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
      final processed = _processTags(node, math, refs, defaultRuleset);
      if (processed.isNotEmpty) {
        buffer.writeln(processed);
        buffer.writeln();
      }
      return;
    }

    if (node is List) {
      for (final item in node) {
        _parseNode(item, buffer, math, refs, depth, defaultRuleset);
      }
      return;
    }

    if (node is Map) {
      _parseMapNode(Map<String, dynamic>.from(node), buffer, math, refs, depth, defaultRuleset);
      return;
    }
  }

  void _parseMapNode(
    Map<String, dynamic> node,
    StringBuffer buffer,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    int depth,
    RulesetVersion defaultRuleset,
  ) {
    final type = node['type'] as String?;
    final name = node['name'] as String?;

    switch (type) {
      // -----------------------------------------------------------------------
      // Named entry block — renders as a heading then recurses into entries.
      // -----------------------------------------------------------------------
      case 'entries':
      case 'section':
        if (name != null && name.isNotEmpty) {
          final prefix = '#' * (depth + 3).clamp(1, 6);
          buffer.writeln('$prefix $name');
          buffer.writeln();
        }
        _parseNode(node['entries'] ?? node['entry'] ?? node['desc'] ?? node['description'], buffer, math, refs, depth + 1, defaultRuleset);

      // -----------------------------------------------------------------------
      // Inset (rules sidebar / callout) — all lines prefixed with "> ".
      // -----------------------------------------------------------------------
      case 'inset':
        if (name != null && name.isNotEmpty) {
          buffer.writeln('> **$name**');
          buffer.writeln('>');
        }
        final insetContent = _captureNode(node['entries'] ?? node['entry'] ?? node['desc'], depth + 1, math, refs, defaultRuleset);
        for (final line in insetContent.split('\n')) {
          buffer.writeln('> $line');
        }
        buffer.writeln();

      // -----------------------------------------------------------------------
      // List — supports ordered (numbered) and unordered (bullet) lists.
      // Correctly captures sub-content inline so list prefix is preserved.
      // -----------------------------------------------------------------------
      case 'list':
        _renderList(node, buffer, math, refs, depth, defaultRuleset);

      // -----------------------------------------------------------------------
      // Table — renders as GitHub-flavored Markdown table.
      // Caption is emitted as a bold heading above the table.
      // -----------------------------------------------------------------------
      case 'table':
        _renderTable(node, buffer, math, refs, defaultRuleset);

      // -----------------------------------------------------------------------
      // Ability Score Improvement / generic ability block.
      // -----------------------------------------------------------------------
      case 'abilityGeneric':
      case 'abilityScore':
        _renderAbilityGrant(node, name, buffer);

      // -----------------------------------------------------------------------
      // Image — emit an alt-text placeholder.
      // -----------------------------------------------------------------------
      case 'image':
        final alt = node['title']?.toString() ?? node['altText']?.toString() ?? 'Image';
        buffer.writeln('*[$alt]*');
        buffer.writeln();

      // -----------------------------------------------------------------------
      // Quote / read-aloud — blockquote format.
      // -----------------------------------------------------------------------
      case 'quote':
        final quoteContent = _captureNode(node['entries'] ?? node['entry'] ?? node['desc'], depth, math, refs, defaultRuleset);
        for (final line in quoteContent.split('\n')) {
          buffer.writeln('> $line');
        }
        final by = node['by']?.toString();
        if (by != null && by.isNotEmpty) buffer.writeln('> — *$by*');
        buffer.writeln();

      // -----------------------------------------------------------------------
      // Inline/statblock — render name then entries.
      // -----------------------------------------------------------------------
      case 'statblock':
      case 'inline':
        if (name != null && name.isNotEmpty) {
          buffer.writeln('**$name**');
        }
        _parseNode(node['entries'] ?? node['entry'] ?? node['desc'] ?? node['description'], buffer, math, refs, depth + 1, defaultRuleset);

      // -----------------------------------------------------------------------
      // Default — if there's an `entries` or `entry` key, recurse into it.
      // Emit the name (if any) as a heading first.
      // -----------------------------------------------------------------------
      default:
        if (name != null && name.isNotEmpty) {
          final prefix = '#' * (depth + 3).clamp(1, 6);
          buffer.writeln('$prefix $name');
          buffer.writeln();
        }
        if (node.containsKey('entries')) {
          _parseNode(node['entries'], buffer, math, refs, depth + 1, defaultRuleset);
        } else if (node.containsKey('entry')) {
          _parseNode(node['entry'], buffer, math, refs, depth, defaultRuleset);
        } else if (node.containsKey('desc')) {
          _parseNode(node['desc'], buffer, math, refs, depth + 1, defaultRuleset);
        } else if (node.containsKey('description')) {
          _parseNode(node['description'], buffer, math, refs, depth + 1, defaultRuleset);
        } else if (node.containsKey('text')) {
          _parseNode(node['text'], buffer, math, refs, depth + 1, defaultRuleset);
        } else if (node.containsKey('subclassFeatures')) {
          _parseNode(node['subclassFeatures'], buffer, math, refs, depth + 1, defaultRuleset);
        } else if (node.containsKey('features')) {
          _parseNode(node['features'], buffer, math, refs, depth + 1, defaultRuleset);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // List rendering (fixes inline prefix problem for Map-typed list items)
  // ---------------------------------------------------------------------------

  void _renderList(
    Map<String, dynamic> listNode,
    StringBuffer buffer,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    int depth,
    RulesetVersion defaultRuleset,
  ) {
    final style = listNode['style']?.toString() ?? '';
    final ordered = style.contains('list-decimal') || style.contains('ordered');
    final items = listNode['items'] as List? ?? [];
    int counter = 1;

    for (final item in items) {
      final prefix = ordered ? '${counter++}. ' : '- ';

      if (item is String) {
        final processed = _processTags(item, math, refs, defaultRuleset);
        buffer.writeln('$prefix$processed');
      } else if (item is Map) {
        // Capture sub-content so we can prefix the first line correctly.
        final subContent = _captureNode(Map<String, dynamic>.from(item), depth, math, refs, defaultRuleset);
        final lines = subContent.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.isEmpty) continue;
          if (i == 0) {
            buffer.writeln('$prefix$line');
          } else {
            // Indent continuation lines to align under the prefix
            buffer.writeln('${' ' * prefix.length}$line');
          }
        }
      } else {
        buffer.writeln('$prefix${item.toString()}');
      }
    }
    buffer.writeln();
  }

  // ---------------------------------------------------------------------------
  // Table rendering — supports caption, colLabels, rows, and complex cells
  // ---------------------------------------------------------------------------

  void _renderTable(
    Map<String, dynamic> tableNode,
    StringBuffer buffer,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    RulesetVersion defaultRuleset,
  ) {
    // Caption above the table
    final caption = tableNode['caption'] as String?;
    if (caption != null && caption.isNotEmpty) {
      buffer.writeln('**$caption**');
      buffer.writeln();
    }

    // Column headers
    final colLabels =
        (tableNode['colLabels'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rows = tableNode['rows'] as List? ?? [];

    if (colLabels.isNotEmpty) {
      buffer.writeln('| ${colLabels.join(' | ')} |');
      buffer.writeln('| ${colLabels.map((_) => '---').join(' | ')} |');
    } else if (rows.isNotEmpty && rows.first is List) {
      // Auto-generate separator based on row width
      final firstRow = rows.first as List;
      final sep = List.filled(firstRow.length, '---').join(' | ');
      buffer.writeln('| $sep |');
    }

    for (final row in rows) {
      if (row is List) {
        final processedRow = row.map((cell) {
          final cellText = _resolveCellText(cell, math, refs, defaultRuleset);
          return cellText.replaceAll('\n', ' ').replaceAll('|', '\\|');
        }).join(' | ');
        buffer.writeln('| $processedRow |');
      }
    }
    buffer.writeln();
  }

  String _resolveCellText(
    dynamic cell,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    RulesetVersion defaultRuleset,
  ) {
    if (cell is String) return _processTags(cell, math, refs, defaultRuleset);
    if (cell is num) return cell.toString();
    if (cell is Map) {
      final cellMap = Map<String, dynamic>.from(cell);
      // AST roll cell: {type: "cell", roll: {min: 1, max: 100}}
      if (cellMap['type'] == 'cell' && cellMap['roll'] is Map) {
        final roll = cellMap['roll'] as Map;
        final min = roll['min'] ?? roll['exact'];
        final max = roll['max'];
        if (min != null && max != null) return '$min–$max';
        if (min != null) return '$min';
      }
      // Text cell
      final entry = cellMap['entry']?.toString() ?? cellMap['entries']?.toString() ?? '';
      return _processTags(entry, math, refs, defaultRuleset);
    }
    return cell.toString();
  }

  // ---------------------------------------------------------------------------
  // Ability score grant rendering
  // ---------------------------------------------------------------------------

  void _renderAbilityGrant(
    Map<String, dynamic> node,
    String? name,
    StringBuffer buffer,
  ) {
    if (name != null && name.isNotEmpty) {
      buffer.write('**$name.** ');
    }

    // AST ability format: {str: 2}, {choose: {count: 1, amount: 2, from: [...]}}
    final parts = <String>[];
    for (final stat in const ['str', 'dex', 'con', 'int', 'wis', 'cha']) {
      if (node[stat] is num) {
        final val = (node[stat] as num).toInt();
        final sign = val >= 0 ? '+' : '';
        parts.add('${stat.toUpperCase()} $sign$val');
      }
    }

    final amount = node['amount'] ?? node['mod'];
    final count = (node['count'] as num?)?.toInt() ?? 1;
    if (amount != null) {
      parts.add('Increase $count ability score(s) each by $amount');
    }

    if (parts.isNotEmpty) {
      buffer.writeln(parts.join(', '));
    } else {
      buffer.writeln('Ability score improvement.');
    }
    buffer.writeln();
  }

  // ---------------------------------------------------------------------------
  // Capture helper — renders a node to a String without touching the main buffer
  // ---------------------------------------------------------------------------

  String _captureNode(
    dynamic node,
    int depth,
    List<EvaluationMath> math,
    List<EntityReference<DomainEntity>> refs,
    RulesetVersion defaultRuleset,
  ) {
    final sb = StringBuffer();
    _parseNode(node, sb, math, refs, depth, defaultRuleset);
    return sb.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Inline tag processor — strips all {@tag content} markup to clean Markdown
  // ---------------------------------------------------------------------------

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
        // Dice / damage
        case 'dice':
        case 'd20':
          return '**`$primary`**';

        case 'damage':
          final dmgType = _extractDamageType(parts);
          mathList.add(EvaluationMath(
            diceFormula: primary,
            damageType: dmgType,
          ));
          return '**`$primary ${dmgType.name}`**';

        case 'hit':
        case 'atk':
          final pfx = primary.startsWith('+') || primary.startsWith('-') ? '' : '+';
          return '**`$pfx$primary`**';

        case 'recharge':
          return primary.isEmpty ? '*(Recharge 6)*' : '*(Recharge $primary–6)*';

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

        // Entity references
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
        case 'monster':
          final slug = _slugify(primary);
          refsList.add(EntityReference<Monster>(
            refType: EntityType.monster,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://monster/$slug)';

        case 'class':
          final slug = _slugify(primary);
          refsList.add(EntityReference<CharacterClass>(
            refType: EntityType.classDefinition,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://class/$slug)';

        case 'subclass':
          final slug = _slugify(primary);
          refsList.add(EntityReference<Subclass>(
            refType: EntityType.subclass,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://subclass/$slug)';

        case 'race':
        case 'species':
          final slug = _slugify(primary);
          refsList.add(EntityReference<Race>(
            refType: EntityType.species,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://species/$slug)';

        case 'feat':
          final slug = _slugify(primary);
          refsList.add(EntityReference<Feat>(
            refType: EntityType.feat,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://feat/$slug)';

        case 'background':
          final slug = _slugify(primary);
          refsList.add(EntityReference<Background>(
            refType: EntityType.background,
            slug: slug,
            displayName: primary,
          ));
          return '[$primary](ref://background/$slug)';

        // Feature references — strip pipe syntax, bold the feature name
        case 'classfeature':
        case 'subclassfeature':
          // Format: "Feature Name|Class|Source|Level"
          return '**${parts[0].trim()}**';

        case 'optfeature':
          return '**$primary**';

        // Conditions / status
        case 'condition':
        case 'status':
          return '**$primary**';

        // Numeric / DC
        case 'dc':
          return 'DC $primary';

        // Skill references
        case 'skill':
        case 'sense':
        case 'action':
        case 'hazard':
        case 'reward':
        case 'table':
          return '**$primary**';

        // Inline formatting
        case 'b':
        case 'bold':
          return '**$primary**';

        case 'i':
        case 'italic':
          return '*$primary*';

        case 'strike':
        case 's':
          return '~~$primary~~';

        case 'code':
          return '`$primary`';

        case 'note':
          return '> **Note:** $primary';

        case 'quickref':
        case 'filter':
        case 'link':
        case 'area':
        case 'deck':
          return primary;

        default:
          return primary;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DamageType _extractDamageType(List<String> parts) {
    for (int i = 1; i < parts.length; i++) {
      final candidate = parts[i].trim().toLowerCase();
      final match = DamageType.values.where((e) => e.name == candidate);
      if (match.isNotEmpty) return match.first;
    }
    return DamageType.untyped;
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['']"), '')
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
