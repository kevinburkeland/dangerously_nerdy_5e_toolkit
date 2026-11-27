import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fix 6.3 / Fix 3.2 shape-based source bar: no second spell or item model class in app `lib/`.
///
/// Reads canonical field names dynamically from `vtt_ruleset_dnd5e`'s `Spell`
/// and `EquipmentItem` definitions (resolved via `.dart_tool/package_config.json`)
/// and rejects any class in `lib/` (regardless of class name or suffix, outside
/// explicitly exempted wire-format DTOs) that declares a shadow model or >= 3
/// non-generic fields of `Spell` or `EquipmentItem`.
const Set<String> _kForbiddenShadowModelNames = {
  'SpellItem',
  'SpellEditionDetails',
  'MagicItem',
  'ItemEditionDetails',
};

/// Generic entity/UI/metadata fields that may legitimately appear on non-model
/// classes (lists, views, helpers). `rules2014` and `rules2024` are intentionally
/// NOT generic so edition-paired shadow models are always caught.
const Set<String> _kGenericEntityFields = {
  'id',
  'name',
  'name2014',
  'name2024',
  'description',
  'descriptionMarkdown',
  'isChangedIn2024',
  'diffSummary',
  'diffHighlights',
  'tags',
  'customProperties',
};

/// Explicit per-class exemption table `(normalizedPath, className) -> reason`.
///
/// Note: `lib/infrastructure/dtos/equipment_item_dto.dart` does not exist in
/// this repository.
const Map<(String, String), String> kSecondModelExemptions = {
  ('lib/infrastructure/dtos/spell_dto.dart', 'SpellDto'):
      'Wire-format DTO for Spell JSON/database transport; converted to ruleset Spell in one place via SpellDto.toDomain().',
  ('lib/models/dm_screen_data.dart', 'DmReferenceItem'):
      'DM Screen rules reference card (DmCategory actions/conditions/tables, action-economy cost/cost2014/cost2024, List<String> rules2014/rules2024); not an equipment model.',
  ('lib/models/srd_summons/summon_preset.dart', 'SummonPreset'):
      'Summon squad preset (statBlocks, budgetBySpellLevel, isRandomTable) covering summon spells and magic-item summoners; holds 4 display strings alongside optional spellId.',
  ('lib/models/glyph_gallery_data.dart', 'GlyphItemEntry'):
      'Illustrative Glyph Gallery showcase entry (29 entries, 7 not in MagicItemLibrary) implementing GlyphRenderable for UI showcase only.',
};

String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    if (src[i] == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (src[i] == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        if (src[i] == '\n') out.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    out.write(src[i]);
    i++;
  }
  return out.toString();
}

/// Extracts only top-level field declarations inside [className]'s class body,
/// ignoring method/constructor bodies and parameter lists so reference-holder
/// classes and local variables cannot cause false matches.
Set<String> extractClassFieldNames(String source, String className) {
  final stripped = _stripComments(source);
  final classMatch = RegExp(
    '\\bclass\\s+$className\\b[^{]*\\{',
  ).firstMatch(stripped);
  if (classMatch == null) return const {};
  var depth = 1;
  var i = classMatch.end;
  final topLevel = StringBuffer();
  var parenDepth = 0;
  while (i < stripped.length && depth > 0) {
    final ch = stripped[i];
    if (ch == '{') {
      depth++;
      i++;
      continue;
    }
    if (ch == '}') {
      depth--;
      if (depth == 1) topLevel.write('\n');
      i++;
      continue;
    }
    if (depth == 1) {
      if (ch == '(') {
        parenDepth++;
        if (parenDepth == 1) topLevel.write('(');
      } else if (ch == ')' && parenDepth > 0) {
        parenDepth--;
        if (parenDepth == 0) topLevel.write(')');
      } else if (parenDepth == 0) {
        topLevel.write(ch);
      }
    }
    i++;
  }
  final fields = <String>{};
  for (final stmt in topLevel.toString().split(';')) {
    var s = stmt.trim();
    if (s.isEmpty) continue;
    // Strip leading annotations (e.g., @override, @immutable).
    s = s.replaceFirst(RegExp(r'^(?:@[A-Za-z0-9_]+(?:\([^)]*\))?\s+)+'), '');
    // Strip initializer (`= ...`) if present, but skip arrow methods (`=>`).
    if (s.contains('=>')) continue;
    final eqIdx = s.indexOf('=');
    if (eqIdx != -1) {
      s = s.substring(0, eqIdx).trim();
    }
    // Skip methods, constructors, getters, setters, and operators.
    if (s.contains('(') ||
        RegExp(r'\b(get|set|operator|factory)\b').hasMatch(s)) {
      continue;
    }
    final m = RegExp(
      r'^(?:(?:static\s+const|static\s+final|static\s+late|late\s+final|late|final|var)\s+|(?:[A-Za-z_][A-Za-z0-9_<>,?.\s]*\s+))([a-z_][A-Za-z0-9_]*)$',
    ).firstMatch(s);
    if (m != null) {
      final fieldName = m.group(1)!;
      if (fieldName != 'return' && fieldName != 'throw') {
        fields.add(fieldName);
      }
    }
  }
  return fields;
}

Directory _findRulesetLibDir() {
  final configFile = File('.dart_tool/package_config.json');
  final text = configFile.readAsStringSync();
  final m = RegExp(
    r'"name"\s*:\s*"vtt_ruleset_dnd5e"[^}]*"rootUri"\s*:\s*"([^"]+)"',
  ).firstMatch(text);
  if (m == null) {
    throw StateError('Could not locate vtt_ruleset_dnd5e in package_config.json');
  }
  final uri = Uri.parse(m.group(1)!);
  final rootPath = uri.scheme == 'file' ? uri.toFilePath() : uri.path;
  return Directory('$rootPath/lib');
}

({
  List<String> violations,
  List<String> classesScanned,
  List<String> matched,
  List<String> exempted,
}) scanSourceForShadowModelsDetailed({
  required String path,
  required String source,
  required Set<String> spellFields,
  required Set<String> itemFields,
}) {
  final stripped = _stripComments(source);
  final violations = <String>[];
  final classesScanned = <String>[];
  final matched = <String>[];
  final exempted = <String>[];

  final spellSpecific = spellFields.difference(_kGenericEntityFields);
  final itemSpecific = itemFields.difference(_kGenericEntityFields);

  final classRe = RegExp(r'\bclass\s+([A-Z][A-Za-z0-9_]*)\b[^{]*\{');
  for (final m in classRe.allMatches(stripped)) {
    final name = m.group(1)!;
    classesScanned.add('$path:$name');

    final exemptionReason = kSecondModelExemptions[(path, name)];
    if (exemptionReason != null) {
      exempted.add('$path:$name ($exemptionReason)');
      continue;
    }

    if (_kForbiddenShadowModelNames.contains(name)) {
      final msg = '$path: forbidden shadow model class `$name`';
      matched.add(msg);
      violations.add(msg);
      continue;
    }

    final fields =
        extractClassFieldNames(stripped, name).difference(_kGenericEntityFields);
    final spellOverlap = fields.intersection(spellSpecific);
    final itemOverlap = fields.intersection(itemSpecific);

    if (spellOverlap.length >= 3) {
      final msg =
          '$path: class `$name` duplicates ${spellOverlap.length} canonical Spell fields ($spellOverlap)';
      matched.add(msg);
      violations.add(msg);
    }
    if (itemOverlap.length >= 3) {
      final msg =
          '$path: class `$name` duplicates ${itemOverlap.length} canonical EquipmentItem fields ($itemOverlap)';
      matched.add(msg);
      violations.add(msg);
    }
  }
  return (
    violations: violations,
    classesScanned: classesScanned,
    matched: matched,
    exempted: exempted,
  );
}

List<String> scanSourceForShadowModels({
  required String path,
  required String source,
  required Set<String> spellFields,
  required Set<String> itemFields,
}) =>
    scanSourceForShadowModelsDetailed(
      path: path,
      source: source,
      spellFields: spellFields,
      itemFields: itemFields,
    ).violations;

void main() {
  late Set<String> spellFields;
  late Set<String> itemFields;

  setUpAll(() {
    final rulesetLib = _findRulesetLibDir();
    final spellFile = File('${rulesetLib.path}/src/models/spell.dart');
    final itemFile = File('${rulesetLib.path}/src/models/equipment_item.dart');
    expect(spellFile.existsSync(), isTrue);
    expect(itemFile.existsSync(), isTrue);
    spellFields = extractClassFieldNames(spellFile.readAsStringSync(), 'Spell');
    itemFields =
        extractClassFieldNames(itemFile.readAsStringSync(), 'EquipmentItem');
    expect(spellFields.length, greaterThanOrEqualTo(10));
    expect(itemFields.length, greaterThanOrEqualTo(10));
  });

  group('Fix 6.3 source bar: no second spell or item model in lib/', () {
    test('control: class SpellItem or shadow spell model fails', () {
      const bad1 = 'class SpellItem { final String id; const SpellItem(this.id); }';
      const bad2 = '''
class CustomSpellModel {
  final String id;
  final String name;
  final int level;
  final String school;
  final String range;
  const CustomSpellModel(this.id, this.name, this.level, this.school, this.range);
}
''';
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/fake.dart',
          source: bad1,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isNotEmpty,
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/fake2.dart',
          source: bad2,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isNotEmpty,
      );
    });

    test('control: Fix 3.2 shape-based bar catches renamed Spell and EquipmentItem classes', () {
      const incantation = '''
class Incantation {
  final int level;
  final String school;
  final String range;
  final String castingTime;
  final String duration;
  final String components;
  const Incantation(this.level, this.school, this.range, this.castingTime, this.duration, this.components);
}
''';
      const spellEntry = '''
class SpellEntry {
  final int level;
  final String school;
  final String range;
  final String castingTime;
  final String duration;
  final String components;
  const SpellEntry(this.level, this.school, this.range, this.castingTime, this.duration, this.components);
}
''';
      const fooDetails = '''
class FooDetails {
  final String rarityTier;
  final String itemType;
  final bool requiresAttunement;
  const FooDetails(this.rarityTier, this.itemType, this.requiresAttunement);
}
''';
      const spellRow = '''
class SpellRow {
  final Spell spell;
  final int glyphColor;
  const SpellRow(this.spell, this.glyphColor);
}
''';
      const commentOnly = '''
// Example:
// class Incantation { final int level; final String school; final String range; }
class SafeHelper {
  final int count;
  const SafeHelper(this.count);
}
''';

      expect(
        scanSourceForShadowModels(
          path: 'lib/models/incantation.dart',
          source: incantation,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isNotEmpty,
        reason: 'Incantation must fail naming lib/models/incantation.dart and Incantation',
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/spell_entry.dart',
          source: spellEntry,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isNotEmpty,
        reason: 'SpellEntry must fail despite Details/Entry suffix',
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/foo_details.dart',
          source: fooDetails,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isNotEmpty,
        reason: 'FooDetails must fail despite Details suffix',
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/presentation/spell_row.dart',
          source: spellRow,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isEmpty,
        reason: 'Reference holder class with Spell field + glyphColor must pass',
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/comment_only.dart',
          source: commentOnly,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isEmpty,
        reason: 'Commented class Incantation must pass',
      );
    });

    test('control: comment mentioning SpellItem or UI widget passes', () {
      const ok = '''
// Formerly class SpellItem lived here.
class SpellCardWidget {
  final String title;
  const SpellCardWidget(this.title);
}
''';
      expect(
        scanSourceForShadowModels(
          path: 'lib/widgets/fake_card.dart',
          source: ok,
          spellFields: spellFields,
          itemFields: itemFields,
        ),
        isEmpty,
      );
    });

    test('no file under lib/ defines a second Spell or EquipmentItem model', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final allViolations = <String>[];
      final allClasses = <String>[];
      final allMatched = <String>[];
      final allExempted = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        final res = scanSourceForShadowModelsDetailed(
          path: normalized,
          source: entity.readAsStringSync(),
          spellFields: spellFields,
          itemFields: itemFields,
        );
        allViolations.addAll(res.violations);
        allClasses.addAll(res.classesScanned);
        allMatched.addAll(res.matched);
        allExempted.addAll(res.exempted);
      }

      stdout.writeln(
        'Fix 3.2 scan summary: ${allClasses.length} classes scanned, '
        '${allMatched.length} unexempted matches, '
        '${allExempted.length} exempted (${allExempted.join('; ')})',
      );

      expect(
        allViolations,
        isEmpty,
        reason: 'Second spell/item model found in lib/:\n${allViolations.join('\n')}',
      );
    });
  });
}
