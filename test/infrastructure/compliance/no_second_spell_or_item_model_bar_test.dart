import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fix 6.3 / Fix 3.2 shape-based source bar: no second spell, item, monster,
/// or monster stat-block model class in app `lib/`.
///
/// Reads canonical property names dynamically from `vtt_ruleset_dnd5e`'s
/// `Spell`, `EquipmentItem`, `Monster`, and `MonsterStatBlock` definitions
/// (resolved via `.dart_tool/package_config.json`) and rejects any class in
/// `lib/` (regardless of class name or suffix, outside explicitly exempted
/// rows in [kSecondModelExemptions]) that declares a shadow model or >= 3
/// model-specific fields of any of those four canonical ruleset types.
const Set<String> _kForbiddenShadowModelNames = {
  'SpellItem',
  'SpellEditionDetails',
  'MagicItem',
  'ItemEditionDetails',
  'MonsterItem',
  'MinionStatBlock',
};

/// Generic entity/UI/metadata fields that may legitimately appear on non-model
/// classes (lists, views, helpers). `rules2014`, `rules2024`, `statBlock2014`,
/// and `statBlock2024` are intentionally NOT generic so edition-paired shadow
/// models are always caught.
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

/// Shared combat-simulation, mobility, and batch-roller fields carried on
/// `MonsterStatBlock` that also legitimately appear on runtime combat types
/// (still required by the type-aware bar):
/// - `bool canFly`: `MonsterCombatProfile`
/// - `bool hasHover`: `ArenaCombatant`, `MonsterCombatProfile`
/// - `int spellSaveDc`: `ArenaCombatant`, `MonsterCombatProfile`
/// - `int spellAttackBonus`: `ArenaCombatant`, `MonsterCombatProfile`
/// - `int attackBonus`: `DprAttackAction`
/// - `int damageDiceCount`: `MinionInstance`, `MinionInstanceDto`
/// - `int damageDiceSides`: `MinionInstance`, `MinionInstanceDto`
/// - `int damageBonus`: `DprAttackAction`
/// - `String damageType`: `DprAttackAction`, `MinionInstance`, `MinionInstanceDto`
/// - `int secondaryDamageDiceCount`: `MinionInstance`, `MinionInstanceDto`
/// - `int secondaryDamageDiceSides`: `MinionInstance`, `MinionInstanceDto`
/// - `String secondaryDamageType`: `DprAttackAction`, `MinionInstance`, `MinionInstanceDto`
/// - `bool hasPackTactics`: `MinionInstanceDto`
/// - `String specialTrait`: `MinionInstance`, `MinionInstanceDto`
const Set<String> _kSharedCombatAndRollerFields = {
  'canFly',
  'hasHover',
  'spellSaveDc',
  'spellAttackBonus',
  'attackBonus',
  'damageDiceCount',
  'damageDiceSides',
  'damageBonus',
  'damageType',
  'secondaryDamageDiceCount',
  'secondaryDamageDiceSides',
  'secondaryDamageType',
  'hasPackTactics',
  'specialTrait',
};

/// Explicit per-class exemption table `(normalizedPath, className) -> reason`.
///
/// Note: `lib/infrastructure/dtos/equipment_item_dto.dart` does not exist in
/// this repository. Zero new exemptions added for Monster / MonsterStatBlock.
const Map<(String, String), String> kSecondModelExemptions = {
  ('lib/infrastructure/dtos/spell_dto.dart', 'SpellDto'):
      'Wire-format DTO for Spell JSON/database transport, turned into Spell in one place via SpellDto.toDomain() in lib/infrastructure/dtos/spell_dto.dart; matches 11 Spell fields (int level, String school, String range, int rangeDistanceFeet, String rangeType, String damageType, SpellComponents components, String higherLevelsMarkdown, List<EvaluationMath> damageMath, List<EntityReference<DomainEntity>> relatedEntityRefs, List<CombatEffectRider> riders).',
  ('lib/models/dm_screen_data.dart', 'DmReferenceItem'):
      'DM Screen rules reference card (action-economy cost); kept because type-aware bar still matches 3 EquipmentItem fields (String cost, String cost2014, String cost2024).',
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

String _extractClassTopLevel(String stripped, String className) {
  final classMatch = RegExp(
    '\\bclass\\s+$className\\b[^{]*\\{',
  ).firstMatch(stripped);
  if (classMatch == null) return '';
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
  return topLevel.toString();
}

String normalizeDeclaredType(String rawType) {
  var t = rawType.trim();
  if (t.isEmpty) return 'dynamic';
  t = t.replaceAll(RegExp(r'\s+'), '');
  t = t.replaceAllMapped(
    RegExp(r'(?<![A-Za-z0-9_])[a-z_][a-z0-9_]*\.([A-Z])'),
    (m) => m.group(1)!,
  );
  if (t.endsWith('?')) {
    t = t.substring(0, t.length - 1);
  }
  return t.isEmpty ? 'dynamic' : t;
}

/// Extracts only top-level field declarations inside [className]'s class body,
/// mapping `fieldName -> normalizedType`.
Map<String, String> extractClassFieldTypes(String source, String className) {
  final stripped = _stripComments(source);
  final topLevel = _extractClassTopLevel(stripped, className);
  if (topLevel.isEmpty) return const {};
  final fields = <String, String>{};
  for (final stmt in topLevel.split(';')) {
    var s = stmt.trim();
    if (s.isEmpty) continue;
    s = s.replaceFirst(RegExp(r'^(?:@[A-Za-z0-9_]+(?:\([^)]*\))?\s+)+'), '');
    if (s.contains('=>')) continue;
    final eqIdx = s.indexOf('=');
    if (eqIdx != -1) {
      s = s.substring(0, eqIdx).trim();
    }
    if (s.contains('(') ||
        RegExp(r'\b(get|set|operator|factory)\b').hasMatch(s)) {
      continue;
    }
    // Strip leading storage/mutability modifiers
    var rest = s.replaceFirst(
      RegExp(r'^(?:static\s+|const\s+|final\s+|late\s+|var\s+)+'),
      '',
    ).trim();
    final m = RegExp(
      r'^(?:([A-Za-z_][A-Za-z0-9_<>,?.\s]*?)\s+)?([a-z_][A-Za-z0-9_]*)$',
    ).firstMatch(rest);
    if (m != null) {
      final rawType = m.group(1) ?? '';
      final fieldName = m.group(2)!;
      if (fieldName != 'return' && fieldName != 'throw') {
        fields[fieldName] = normalizeDeclaredType(rawType);
      }
    }
  }
  return fields;
}

Set<String> extractClassFieldNames(String source, String className) =>
    extractClassFieldTypes(source, className).keys.toSet();

/// Extracts top-level fields AND public derived getters with their declared types.
Map<String, String> extractCanonicalModelPropertyTypes(
  String source,
  String className,
) {
  final stripped = _stripComments(source);
  final props = <String, String>{...extractClassFieldTypes(source, className)};
  final topLevel = _extractClassTopLevel(stripped, className);
  const ignoredGetters = {
    'entityType',
    'hashCode',
    'sourceStatBlock',
    'isHomebrew',
  };
  for (final m in RegExp(
    r'(?:^|\n|;)\s*([A-Za-z_][A-Za-z0-9_<>,?.\s]*?)\s+get\s+([a-z][A-Za-z0-9_]*)\b',
  ).allMatches(topLevel)) {
    final g = m.group(2)!;
    if (!ignoredGetters.contains(g)) {
      props[g] = normalizeDeclaredType(m.group(1)!);
    }
  }
  return props;
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

Map<String, String> _filterNonGeneric(
  Map<String, String> fields, [
  Set<String> extraIgnored = const {},
]) {
  return {
    for (final e in fields.entries)
      if (!_kGenericEntityFields.contains(e.key) &&
          !extraIgnored.contains(e.key))
        e.key: e.value,
  };
}

List<String> _matchingTypedFields(
  Map<String, String> candidate,
  Map<String, String> canonical,
) {
  return [
    for (final e in candidate.entries)
      if (canonical[e.key] == e.value) '${e.value} ${e.key}',
  ]..sort();
}

({
  List<String> violations,
  List<String> classesScanned,
  List<String> matched,
  List<String> exempted,
}) scanSourceForShadowModelsDetailed({
  required String path,
  required String source,
  required Map<String, String> spellFields,
  required Map<String, String> itemFields,
  Map<String, String> monsterFields = const {},
  Map<String, String> statBlockFields = const {},
  Map<(String, String), String> exemptions = kSecondModelExemptions,
  Set<String> sharedCombatFields = _kSharedCombatAndRollerFields,
}) {
  final stripped = _stripComments(source);
  final violations = <String>[];
  final classesScanned = <String>[];
  final matched = <String>[];
  final exempted = <String>[];

  final spellSpecific = _filterNonGeneric(spellFields);
  final itemSpecific = _filterNonGeneric(itemFields);
  final monsterSpecific = _filterNonGeneric(monsterFields);
  final statBlockSpecific = _filterNonGeneric(statBlockFields, sharedCombatFields);

  final classRe = RegExp(r'\bclass\s+([A-Z][A-Za-z0-9_]*)\b[^{]*\{');
  for (final m in classRe.allMatches(stripped)) {
    final name = m.group(1)!;
    classesScanned.add('$path:$name');

    final exemptionReason = exemptions[(path, name)];
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

    final fields = _filterNonGeneric(extractClassFieldTypes(stripped, name));
    final spellOverlap = _matchingTypedFields(fields, spellSpecific);
    final itemOverlap = _matchingTypedFields(fields, itemSpecific);
    final monsterOverlap = _matchingTypedFields(fields, monsterSpecific);
    final statBlockOverlap = _matchingTypedFields(fields, statBlockSpecific);

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
    if (monsterOverlap.length >= 3) {
      final msg =
          '$path: class `$name` duplicates ${monsterOverlap.length} canonical Monster fields ($monsterOverlap)';
      matched.add(msg);
      violations.add(msg);
    }
    if (statBlockOverlap.length >= 3) {
      final msg =
          '$path: class `$name` duplicates ${statBlockOverlap.length} canonical MonsterStatBlock fields ($statBlockOverlap)';
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
  required Map<String, String> spellFields,
  required Map<String, String> itemFields,
  Map<String, String> monsterFields = const {},
  Map<String, String> statBlockFields = const {},
}) =>
    scanSourceForShadowModelsDetailed(
      path: path,
      source: source,
      spellFields: spellFields,
      itemFields: itemFields,
      monsterFields: monsterFields,
      statBlockFields: statBlockFields,
    ).violations;

void main() {
  late Map<String, String> spellFields;
  late Map<String, String> itemFields;
  late Map<String, String> monsterFields;
  late Map<String, String> statBlockFields;

  setUpAll(() {
    final rulesetLib = _findRulesetLibDir();
    final spellFile = File('${rulesetLib.path}/src/models/spell.dart');
    final itemFile = File('${rulesetLib.path}/src/models/equipment_item.dart');
    final monsterFile = File('${rulesetLib.path}/src/models/monster.dart').existsSync()
        ? File('${rulesetLib.path}/src/models/monster.dart')
        : File('${rulesetLib.path}/src/models/spell_monster_equipment.dart');
    final statBlockFile =
        File('${rulesetLib.path}/src/models/monster_stat_block.dart');
    expect(spellFile.existsSync(), isTrue);
    expect(itemFile.existsSync(), isTrue);
    expect(monsterFile.existsSync(), isTrue);
    expect(statBlockFile.existsSync(), isTrue);

    spellFields = extractClassFieldTypes(spellFile.readAsStringSync(), 'Spell');
    itemFields =
        extractClassFieldTypes(itemFile.readAsStringSync(), 'EquipmentItem');
    monsterFields = extractCanonicalModelPropertyTypes(
      monsterFile.readAsStringSync(),
      'Monster',
    );
    statBlockFields = extractClassFieldTypes(
      statBlockFile.readAsStringSync(),
      'MonsterStatBlock',
    );
    expect(spellFields.length, greaterThanOrEqualTo(10));
    expect(itemFields.length, greaterThanOrEqualTo(10));
    expect(monsterFields.length, greaterThanOrEqualTo(10));
    expect(statBlockFields.length, greaterThanOrEqualTo(20));
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        ),
        isNotEmpty,
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/fake2.dart',
          source: bad2,
          spellFields: spellFields,
          itemFields: itemFields,
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
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
  final ItemRarity rarityTier;
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        ),
        isEmpty,
        reason: 'Commented class Incantation must pass',
      );

      const dmRefShape = '''
class DmRefShape {
  final String id;
  final String name;
  final List<String> rules2014;
  final List<String> rules2024;
  const DmRefShape(this.id, this.name, this.rules2014, this.rules2024);
}
''';
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/dm_ref_shape.dart',
          source: dmRefShape,
          spellFields: spellFields,
          itemFields: itemFields,
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        ),
        isEmpty,
        reason: 'DmReferenceItem shape with List<String> rules2014/rules2024 must pass',
      );

      const dynamicIncantation = '''
class Incantation {
  final dynamic level;
  final dynamic school;
  final dynamic range;
  final dynamic castingTime;
  final dynamic duration;
  final dynamic components;
  const Incantation(this.level, this.school, this.range, this.castingTime, this.duration, this.components);
}
''';
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/dynamic_incantation.dart',
          source: dynamicIncantation,
          spellFields: spellFields,
          itemFields: itemFields,
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        ),
        isEmpty,
        reason: 'Incantation with dynamic fields must pass type-aware bar',
      );
    });

    test('control: Fix 6.3 shape-based bar catches renamed Monster and MonsterStatBlock classes', () {
      const creatureRecord = '''
class CreatureRecord {
  final int armorClass;
  final int hitPoints;
  final String challengeRating;
  const CreatureRecord(this.armorClass, this.hitPoints, this.challengeRating);
}
''';
      const shadowStatBlock = '''
class BeastSheet {
  final int maxHp;
  final String crDisplay;
  final int strScore;
  const BeastSheet(this.maxHp, this.crDisplay, this.strScore);
}
''';
      const monsterHolder = '''
class MonsterRow {
  final Monster monster;
  final int accent;
  const MonsterRow(this.monster, this.accent);
}
''';
      const monsterComment = '''
// class CreatureRecord { final int armorClass; final int hitPoints; final String challengeRating; }
class SafeMonsterHelper {
  final int count;
  const SafeMonsterHelper(this.count);
}
''';

      final r1 = scanSourceForShadowModels(
        path: 'lib/models/creature_record.dart',
        source: creatureRecord,
        spellFields: spellFields,
        itemFields: itemFields,
        monsterFields: monsterFields,
        statBlockFields: statBlockFields,
      );
      expect(r1, isNotEmpty);
      expect(r1.single, contains('lib/models/creature_record.dart'));
      expect(r1.single, contains('CreatureRecord'));

      final r2 = scanSourceForShadowModels(
        path: 'lib/models/beast_sheet.dart',
        source: shadowStatBlock,
        spellFields: spellFields,
        itemFields: itemFields,
        monsterFields: monsterFields,
        statBlockFields: statBlockFields,
      );
      expect(r2, isNotEmpty);
      expect(r2.single, contains('BeastSheet'));

      expect(
        scanSourceForShadowModels(
          path: 'lib/presentation/monster_row.dart',
          source: monsterHolder,
          spellFields: spellFields,
          itemFields: itemFields,
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        ),
        isEmpty,
      );
      expect(
        scanSourceForShadowModels(
          path: 'lib/models/monster_comment.dart',
          source: monsterComment,
          spellFields: spellFields,
          itemFields: itemFields,
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        ),
        isEmpty,
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
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
          monsterFields: monsterFields,
          statBlockFields: statBlockFields,
        );
        allViolations.addAll(res.violations);
        allClasses.addAll(res.classesScanned);
        allMatched.addAll(res.matched);
        allExempted.addAll(res.exempted);
      }

      stdout.writeln(
        'Fix 6.3 scan summary: ${allClasses.length} classes scanned, '
        '${allMatched.length} unexempted matches, '
        '${allExempted.length} exempted (${allExempted.join('; ')})',
      );

      expect(
        allViolations,
        isEmpty,
        reason: 'Second spell/item/monster model found in lib/:\n${allViolations.join('\n')}',
      );
    });
  });
}
