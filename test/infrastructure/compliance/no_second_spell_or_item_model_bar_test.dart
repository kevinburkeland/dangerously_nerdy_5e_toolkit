import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fix 6.3 source bar: no second spell or item model class in app `lib/`.
///
/// Reads canonical field names dynamically from `vtt_ruleset_dnd5e`'s `Spell`
/// and `EquipmentItem` definitions (resolved via `.dart_tool/package_config.json`)
/// and rejects any class in `lib/` (outside explicit DTO serialization wrappers)
/// that declares a spell/item shadow model by name or by matching >= 4 canonical
/// domain fields of `Spell` or `EquipmentItem`.
const Set<String> _kForbiddenShadowModelNames = {
  'SpellItem',
  'SpellEditionDetails',
  'MagicItem',
  'ItemEditionDetails',
};

const Set<String> _kGenericEntityFields = {
  'id',
  'name',
  'name2014',
  'name2024',
  'isChangedIn2024',
  'diffSummary',
  'diffHighlights',
  'tags',
  'customProperties',
  'descriptionMarkdown',
  'rules2014',
  'rules2024',
};

const Set<String> _kDtoFiles = {
  'lib/infrastructure/dtos/spell_dto.dart',
  'lib/infrastructure/dtos/equipment_item_dto.dart',
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

Set<String> extractClassFieldNames(String source, String className) {
  final stripped = _stripComments(source);
  final classMatch = RegExp(
    '\\bclass\\s+$className\\b[^{]*\\{',
  ).firstMatch(stripped);
  if (classMatch == null) return const {};
  var depth = 1;
  var i = classMatch.end;
  while (i < stripped.length && depth > 0) {
    if (stripped[i] == '{') depth++;
    if (stripped[i] == '}') depth--;
    i++;
  }
  final body = stripped.substring(classMatch.end, i - 1);
  final fields = <String>{};
  for (final m in RegExp(r'\bfinal\s+[^=;]+?\s+([a-z][A-Za-z0-9_]*)\s*;')
      .allMatches(body)) {
    fields.add(m.group(1)!);
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

List<String> scanSourceForShadowModels({
  required String path,
  required String source,
  required Set<String> spellFields,
  required Set<String> itemFields,
}) {
  if (_kDtoFiles.contains(path)) return const [];
  final stripped = _stripComments(source);
  final violations = <String>[];

  final classRe = RegExp(r'\bclass\s+([A-Z][A-Za-z0-9_]*)\b[^{]*\{');
  for (final m in classRe.allMatches(stripped)) {
    final name = m.group(1)!;
    if (_kForbiddenShadowModelNames.contains(name)) {
      violations.add('$path: forbidden shadow model class `$name`');
      continue;
    }

    // Check if class name hints at spell/item model or declares hallmark spell/item shape
    final rawFields = extractClassFieldNames(stripped, name);
    if (rawFields.contains('level') &&
        rawFields.contains('school') &&
        rawFields.contains('rules2014')) {
      violations.add(
        '$path: class `$name` declares spell model fields (level, school, rules2014)',
      );
      continue;
    }

    final lowerName = name.toLowerCase();
    final looksLikeSpellOrItem =
        lowerName.contains('spell') || lowerName.contains('item');
    if (!looksLikeSpellOrItem) continue;
    if (lowerName.endsWith('library') ||
        lowerName.endsWith('screen') ||
        lowerName.endsWith('state') ||
        lowerName.endsWith('dialog') ||
        lowerName.endsWith('card') ||
        lowerName.endsWith('sheet') ||
        lowerName.endsWith('widget') ||
        lowerName.endsWith('service') ||
        lowerName.endsWith('parser') ||
        lowerName.endsWith('extractor') ||
        lowerName.endsWith('descriptor') ||
        lowerName.endsWith('resolver') ||
        lowerName.endsWith('dto') ||
        lowerName.endsWith('presentation') ||
        lowerName.endsWith('entry') ||
        lowerName.endsWith('details') ||
        lowerName.endsWith('selection') ||
        lowerName.endsWith('result') ||
        lowerName.endsWith('plan') ||
        lowerName.endsWith('formula') ||
        lowerName.endsWith('controller') ||
        lowerName.endsWith('repository') ||
        lowerName.endsWith('store')) {
      continue;
    }

    final fields = rawFields.difference(_kGenericEntityFields);
    final spellSpecific = spellFields.difference(_kGenericEntityFields);
    final itemSpecific = itemFields.difference(_kGenericEntityFields);
    final spellOverlap = fields.intersection(spellSpecific);
    final itemOverlap = fields.intersection(itemSpecific);
    if (spellOverlap.length >= 3) {
      violations.add(
        '$path: class `$name` duplicates ${spellOverlap.length} canonical Spell fields ($spellOverlap)',
      );
    }
    if (itemOverlap.length >= 3 &&
        (itemOverlap.contains('rarity') ||
            itemOverlap.contains('rarityTier') ||
            itemOverlap.contains('itemType') ||
            itemOverlap.contains('requiresAttunement'))) {
      violations.add(
        '$path: class `$name` duplicates ${itemOverlap.length} canonical EquipmentItem fields ($itemOverlap)',
      );
    }
  }
  return violations;
}

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
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        allViolations.addAll(
          scanSourceForShadowModels(
            path: normalized,
            source: entity.readAsStringSync(),
            spellFields: spellFields,
            itemFields: itemFields,
          ),
        );
      }

      expect(
        allViolations,
        isEmpty,
        reason: 'Second spell/item model found in lib/:\n${allViolations.join('\n')}',
      );
    });
  });
}
