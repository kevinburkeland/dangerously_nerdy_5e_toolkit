import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fix 5.2 source bar: item rules (AC/weapon/spell bonuses, base AC, armor type,
/// shield bonus) must be stored as data on [EquipmentItem], never guessed by
/// running a [RegExp] over an item's name.
const List<String> _kItemRulePropertyKeys = [
  'bonusAc',
  'acBonus',
  'baseAc',
  'bonusWeapon',
  'attackBonus',
  'magicBonus',
  'bonusSpellAttack',
  'bonusSpellSaveDc',
  'spellDcBonus',
  'maxDexBonus',
  'shieldBonus',
  'armorType',
];

String _stripDartComments(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final q = c;
      out.write(c);
      i++;
      while (i < n) {
        final ch = source[i];
        out.write(ch);
        if (ch == r'\' && i + 1 < n) {
          i++;
          out.write(source[i]);
          i++;
          continue;
        }
        i++;
        if (ch == q) break;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Scans a single Dart source string for regex-based item-rule derivation
/// (matching an item's `.name` with `RegExp` within a function/window that
/// writes any item-rule property key).
List<String> scanSourceForRegexItemRules(String path, String source) {
  final stripped = _stripDartComments(source);
  final lines = stripped.split('\n');
  final violations = <String>[];

  final regexOnItemName = RegExp(
    r'RegExp\s*\([^)]*\)\s*(?:\.\s*(?:firstMatch|allMatches|hasMatch)\s*\([^)]*\.name\b|\s*;\s*|\s*$)',
  );
  final matchOnItemName = RegExp(
    r'(?:firstMatch|allMatches|hasMatch)\s*\(\s*[a-zA-Z_][a-zA-Z0-9_]*\.name\b',
  );
  final propAssign = RegExp(
    "['\"](?:${_kItemRulePropertyKeys.join('|')})['\"]\\s*\\]\\s*=",
  );

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final windowEnd = (i + 15 < lines.length) ? i + 15 : lines.length;
    final window = lines.sublist(i, windowEnd).join('\n');

    final hasRegex = line.contains('RegExp(');
    final matchesName = regexOnItemName.hasMatch(window) ||
        (hasRegex && matchOnItemName.hasMatch(window));
    if (hasRegex && matchesName && propAssign.hasMatch(window)) {
      violations.add(
        '$path:${i + 1}: RegExp matching item name feeds item rule property assignment',
      );
    }
  }
  return violations;
}

void main() {
  group('Fix 5.2 source bar: no RegExp item-rule guessing from names', () {
    test('control: RegExp on item.name feeding props[bonusAc] fails', () {
      const badSource = '''
void bad(dynamic item, Map<String, dynamic> props) {
  final m = RegExp(r'\\+(\\d+)').firstMatch(item.name);
  if (m != null) {
    props['bonusAc'] = int.parse(m.group(1)!);
  }
}
''';
      final violations = scanSourceForRegexItemRules('memory_bad.dart', badSource);
      expect(violations, isNotEmpty);
    });

    test('control: comment mentioning RegExp and bonusAc passes', () {
      const commentSource = '''
// Previously RegExp(r'\\+(\\d+)').firstMatch(item.name) wrote props['bonusAc'] = 1;
const Map<String, dynamic> props = {'bonusAc': 1};
''';
      final violations =
          scanSourceForRegexItemRules('memory_comment.dart', commentSource);
      expect(violations, isEmpty);
    });

    test('control: static literal bonusAc map passes', () {
      const goodSource = '''
const Map<String, dynamic> props = {
  'bonusAc': 1,
  'acBonus': 1,
  'baseAc': 14,
};
''';
      final violations =
          scanSourceForRegexItemRules('memory_good.dart', goodSource);
      expect(violations, isEmpty);
    });

    test('no file under lib/ derives item rules from RegExp on item.name', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final allViolations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        final content = entity.readAsStringSync();
        allViolations.addAll(scanSourceForRegexItemRules(normalized, content));
      }

      expect(
        allViolations,
        isEmpty,
        reason: 'Regex-based item rule derivation found:\n${allViolations.join('\n')}',
      );
    });
  });
}
