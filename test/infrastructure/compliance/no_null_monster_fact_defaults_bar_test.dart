import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Display files permitted to substitute the display placeholder `'—'` (or `''`
/// in form controllers when editing an existing monster) for a missing fact.
/// Replacing a missing fact with any numeric or game-fact string literal
/// (e.g. `?? 10`, `?? 'Medium'`, `?? '1'`) is ALWAYS forbidden everywhere.
const Map<String, String> kAllowedDisplayPlaceholderFiles = {
  'lib/models/srd_summons/minion_stat_block.dart':
      'Canonical MonsterStatBlockDisplayExt formatting helpers returning em-dash display placeholders',
  'lib/models/dpr/dpr_models.dart':
      'DprCombatantProfile description line formatting using em-dash display placeholders',
  'lib/services/rules/arena/arena_challenge_rating_validator.dart':
      'Pre-match refusal exception message formatting for missing CR text using em-dash placeholder',
  'lib/widgets/homebrew/monster_builder_dialog.dart':
      'Form controller initialization when editing an existing monster with null facts (empty TextEditingController text)',
};

bool _isDisplayPlaceholderAllowed(String path, String literal) {
  final isEmDash = literal == "'—'" || literal == '"—"' || literal == r"'\u2014'";
  final isEmptyFormText = literal == "''" || literal == '""';
  if (isEmDash) {
    if (path.startsWith('lib/widgets/') ||
        path.startsWith('lib/screens/') ||
        path.startsWith('lib/presentation/') ||
        kAllowedDisplayPlaceholderFiles.containsKey(path)) {
      return true;
    }
  }
  if (isEmptyFormText && path == 'lib/widgets/homebrew/monster_builder_dialog.dart') {
    return true;
  }
  return false;
}

/// Strips `//` and `/* ... */` comments while preserving line numbers and
/// leaving string literals intact so we can inspect the right-hand literal of `??`.
String _stripCommentsPreservingLines(String source) {
  final buf = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        buf.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      buf.write('  ');
      i += 2;
      while (i < n) {
        if (source[i] == '*' && i + 1 < n && source[i + 1] == '/') {
          buf.write('  ');
          i += 2;
          break;
        }
        buf.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    if (c == '\'' || c == '"') {
      final quote = c;
      final triple = i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final delimLen = triple ? 3 : 1;
      buf.write(source.substring(i, i + delimLen));
      i += delimLen;
      while (i < n) {
        if (!triple && source[i] == '\\' && i + 1 < n) {
          buf.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (triple &&
            i + 2 < n &&
            source[i] == quote &&
            source[i + 1] == quote &&
            source[i + 2] == quote) {
          buf.write(source.substring(i, i + 3));
          i += 3;
          break;
        }
        if (!triple && source[i] == quote) {
          buf.write(quote);
          i++;
          break;
        }
        buf.write(source[i]);
        i++;
      }
      continue;
    }
    buf.write(c);
    i++;
  }
  return buf.toString();
}

/// Matches reads of any of the 7 F-16 nullable monster/stat-block facts
/// (`sizeDisplay`, `typeDisplay`, `alignment`, `crDisplay`, `hitDice`,
/// `armorClass`, `hitPoints`, `hitDieFormula`, `challengeRating`, `monsterType`,
/// `challengeRatingValue`, `crValue`, or monster/stat-block `.size`, `.ac`,
/// `.maxHp`) followed by `?? <numeric or string literal>`.
final _kNullMonsterFactDefaultPattern = RegExp(
  r'\b(?:'
  r'(?:[A-Za-z_]\w*\??\.(?:sizeDisplay|typeDisplay|crDisplay|hitDice|armorClass|hitPoints|hitDieFormula|challengeRating|monsterType|challengeRatingValue|crValue|alignment))'
  r'|(?:(?:monster|sb|statBlock|statBlock2014|statBlock2024|sourceStatBlock|init|entry)\??\.(?:size|type|ac|hp|maxHp))'
  r')\s*\?\?\s*(-?\d+(?:\.\d+)?|'
  r"'(?:[^'\\]|\\.)*'"
  r'|"(?:[^"\\]|\\.)*")',
  multiLine: true,
);

List<String> scanNullMonsterFactDefaultViolations(Map<String, String> files) {
  final violations = <String>[];
  for (final entry in files.entries) {
    final cleaned = _stripCommentsPreservingLines(entry.value);
    for (final match in _kNullMonsterFactDefaultPattern.allMatches(cleaned)) {
      final literal = match.group(1)!;
      if (_isDisplayPlaceholderAllowed(entry.key, literal)) {
        continue;
      }
      final line = '\n'.allMatches(cleaned.substring(0, match.start)).length + 1;
      violations.add('${entry.key}:$line: ${match.group(0)}');
    }
  }
  return violations;
}

void main() {
  group('Fix 7.1 source bar: no null-to-literal defaults for nullable monster facts', () {
    test('controls: monster.armorClass ?? 10 fails; comment passes; em dash in display file passes', () {
      final bad = scanNullMonsterFactDefaultViolations({
        'lib/sample_bad.dart':
            'final x = 1;\nfinal ac = monster.armorClass ?? 10;\nfinal sz = sb.sizeDisplay ?? \'Medium\';\n',
      });
      expect(bad, hasLength(2));
      expect(bad[0], contains('lib/sample_bad.dart:2'));
      expect(bad[1], contains('lib/sample_bad.dart:3'));

      final commented = scanNullMonsterFactDefaultViolations({
        'lib/sample_comment.dart':
            '// final ac = monster.armorClass ?? 10;\n/* sb.sizeDisplay ?? \'Medium\' */\n',
      });
      expect(commented, isEmpty);

      final displayDash = scanNullMonsterFactDefaultViolations({
        'lib/widgets/monster_codex/monster_card.dart':
            "final label = sb.sizeDisplay ?? '—';\n",
      });
      expect(displayDash, isEmpty);

      // Em dash in non-display domain/service code is still rejected unless allowlisted
      final nonDisplayDash = scanNullMonsterFactDefaultViolations({
        'lib/services/acl/some_parser.dart':
            "final label = sb.sizeDisplay ?? '—';\n",
      });
      expect(nonDisplayDash, hasLength(1));
    });

    test('real bar: lib/ contains zero null-to-literal monster fact defaults', () {
      final libDir = Directory('lib');
      final files = <String, String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          files[entity.path] = entity.readAsStringSync();
        }
      }
      final violations = scanNullMonsterFactDefaultViolations(files);
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden null-to-literal monster fact default(s) found:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
