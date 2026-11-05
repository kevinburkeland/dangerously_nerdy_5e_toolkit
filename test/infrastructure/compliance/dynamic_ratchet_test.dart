import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int countDynamic(String source) {
  int count = 0;
  final n = source.length;
  int i = 0;

  bool isIdentChar(int c) {
    return (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        c == 95 ||
        c == 36;
  }

  final stack = <Map<String, dynamic>>[{'type': 'code', 'braceDepth': 0}];

  while (i < n) {
    final ctx = stack.last;
    final type = ctx['type'] as String;

    if (type == 'code') {
      if (source.startsWith('//', i)) {
        while (i < n && source[i] != '\n') {
          i++;
        }
        continue;
      }
      if (source.startsWith('/*', i)) {
        int depth = 1;
        i += 2;
        while (i < n && depth > 0) {
          if (source.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (source.startsWith('*/', i)) {
            depth--;
            i += 2;
          } else {
            i++;
          }
        }
        continue;
      }

      if (source[i] == 'r' && i + 1 < n && (source[i + 1] == "'" || source[i + 1] == '"')) {
        final q = source[i + 1];
        final isTriple = i + 3 < n && source[i + 2] == q && source[i + 3] == q;
        final delim = isTriple ? q * 3 : q;
        i += 1 + delim.length;
        while (i < n) {
          if (source.startsWith(delim, i)) {
            i += delim.length;
            break;
          } else {
            i++;
          }
        }
        continue;
      }

      if (source[i] == "'" || source[i] == '"') {
        final q = source[i];
        final isTriple = i + 2 < n && source[i + 1] == q && source[i + 2] == q;
        final delim = isTriple ? q * 3 : q;
        i += delim.length;
        stack.add({'type': 'string', 'delim': delim});
        continue;
      }

      if (source[i] == '{') {
        ctx['braceDepth'] = (ctx['braceDepth'] as int) + 1;
        i++;
        continue;
      }
      if (source[i] == '}') {
        final bd = ctx['braceDepth'] as int;
        if (bd > 0) {
          ctx['braceDepth'] = bd - 1;
          i++;
        } else {
          if (stack.length > 1) {
            stack.removeLast();
            i++;
          } else {
            i++;
          }
        }
        continue;
      }

      if (source.startsWith('dynamic', i)) {
        final before = i > 0 ? source.codeUnitAt(i - 1) : null;
        final after = i + 7 < n ? source.codeUnitAt(i + 7) : null;
        final beforeIsIdent = before != null && isIdentChar(before);
        final afterIsIdent = after != null && isIdentChar(after);
        if (!beforeIsIdent && !afterIsIdent) {
          count++;
          i += 7;
          continue;
        }
      }

      i++;
    } else if (type == 'string') {
      final delim = ctx['delim'] as String;
      if (source.startsWith(delim, i)) {
        i += delim.length;
        stack.removeLast();
        continue;
      }

      if (source[i] == r'\' && i + 1 < n) {
        i += 2;
        continue;
      }

      if (source.startsWith(r'${', i)) {
        i += 2;
        stack.add({'type': 'code', 'braceDepth': 0});
        continue;
      }

      if (source[i] == r'$') {
        i++;
        while (i < n && isIdentChar(source.codeUnitAt(i))) {
          i++;
        }
        continue;
      }

      i++;
    }
  }

  return count;
}

// Cleanup slice 8 Step 4: dynamic ceiling lowered to 1054
const kDynamicCeiling = 1054;

void main() {
  group('dynamic ratchet', () {
    test('DC1: controls give exactly stated counts', () {
      expect(countDynamic('dynamic x;'), 1);
      expect(countDynamic('Map<String, dynamic> m; List<dynamic> l;'), 2);
      expect(countDynamic('// dynamic'), 0);
      expect(countDynamic('/// a dynamic value'), 0);
      expect(countDynamic('/* dynamic */'), 0);
      expect(countDynamic('/* outer /* inner */ dynamic */'), 0);
      expect(countDynamic("'dynamic'"), 0);
      expect(countDynamic('"dynamic"'), 0);
      expect(countDynamic("'''\ndynamic\n'''"), 0);
      expect(countDynamic("r'dynamic\\'" ' dynamic y;'), 1);
      expect(countDynamic("'it\\'s' ; dynamic z;"), 1);
      expect(countDynamic(r"'${x as dynamic}'"), 1);
      expect(countDynamic("final m = 'image/*'; dynamic q;"), 1);
      expect(countDynamic('dynamicValue isDynamic _dynamic dynamic2'), 0);
    });

    test('DR1: total dynamic count in lib/ matches kDynamicCeiling', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      int total = 0;
      final fileCounts = <String, int>{};

      for (final file in files) {
        final content = file.readAsStringSync();
        final c = countDynamic(content);
        if (c > 0) {
          fileCounts[file.path] = c;
          total += c;
        }
      }

      if (total > kDynamicCeiling) {
        final sorted = fileCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top10 = sorted.take(10).map((e) => '  ${e.key}: ${e.value}').join('\n');
        fail(
          'Dynamic count ($total) exceeds ceiling ($kDynamicCeiling).\n'
          'Top 10 files:\n$top10',
        );
      } else if (total < kDynamicCeiling) {
        fail('lower kDynamicCeiling to $total');
      }

      expect(total, equals(kDynamicCeiling));
    });
  });
}
