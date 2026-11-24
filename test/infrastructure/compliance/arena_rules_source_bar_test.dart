import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_directive_reader.dart';

final _inlineD20CompareRe = RegExp(
  r'\b(?:d20|naturalRoll|natRoll)\s*(?:==|!=|>=|<=|>|<)\s*(?:20|1)\b',
);

final _inlineShieldAcPlus5Re = RegExp(
  r'\b(?:effectiveAc|targetAc|armorClass|ac)\s*\+\s*5\b',
);

/// Scans all `.dart` files under [dir] (comments and string literals stripped)
/// for inline d20 == 20 / == 1 attack classification or `effectiveAc + 5`
/// Shield reaction checks that belong in `vtt_ruleset_dnd5e`.
List<String> scanInlineArenaCombatRules(Directory dir) {
  if (!dir.existsSync()) {
    throw StateError('Rules directory does not exist: ${dir.path}');
  }
  final violations = <String>[];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final stripped =
        stripCommentsAndStringsPreservingNewlines(file.readAsStringSync());
    final lines = stripped.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final d20Match = _inlineD20CompareRe.firstMatch(line);
      if (d20Match != null) {
        violations.add(
          '${file.path}:${i + 1}: inline d20 comparison "${d20Match.group(0)}" '
          '(use classifyAttackRoll from vtt_ruleset_dnd5e)',
        );
      }
      final shieldMatch = _inlineShieldAcPlus5Re.firstMatch(line);
      if (shieldMatch != null) {
        violations.add(
          '${file.path}:${i + 1}: inline Shield AC+5 check "${shieldMatch.group(0)}" '
          '(use doesShieldBlockAttack from vtt_ruleset_dnd5e)',
        );
      }
    }
  }
  return violations;
}

void main() {
  group('Fix 5.2 source bar: no inline d20==20/1 or Shield AC+5 under lib/services/rules/',
      () {
    test('control: in-memory file with d20 == 20 or effectiveAc + 5 fails; commented versions pass',
        () {
      final tmp = Directory.systemTemp.createTempSync('arena_rules_bar_ctrl_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final badFile = File('${tmp.path}/bad_rules.dart')
        ..writeAsStringSync('''
bool f(int d20, int total, int effectiveAc) {
  final isCrit = d20 == 20;
  if (total < effectiveAc + 5) return false;
  return isCrit;
}
''');
      final badHits = scanInlineArenaCombatRules(tmp);
      expect(badHits, hasLength(2));
      expect(badHits[0], contains('bad_rules.dart:2'));
      expect(badHits[0], contains('d20 == 20'));
      expect(badHits[1], contains('bad_rules.dart:3'));
      expect(badHits[1], contains('effectiveAc + 5'));

      badFile.writeAsStringSync('''
// final isCrit = d20 == 20;
/* if (total < effectiveAc + 5) return false; */
const doc = 'd20 == 20 and effectiveAc + 5';
bool f(int d20) => d20 > 0;
''');
      final okHits = scanInlineArenaCombatRules(tmp);
      expect(okHits, isEmpty);
    });

    test('real bar: lib/services/rules/ delegates attack roll classification and Shield AC+5 to vtt_ruleset_dnd5e',
        () {
      final hits = scanInlineArenaCombatRules(Directory('lib/services/rules'));
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  });
}
