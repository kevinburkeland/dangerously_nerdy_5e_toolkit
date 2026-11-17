import 'package:flutter_test/flutter_test.dart';
import 'dart_string_literal_reader.dart';

void main() {
  group('DartStringLiteralReader', () {
    test('extracts single and double quoted strings', () {
      const source = '''
void main() {
  final a = 'hello';
  final b = "world";
}
''';
      final literals = extractDartStringLiterals(source);
      expect(literals.length, 2);
      expect(literals[0].value, 'hello');
      expect(literals[0].lineNumber, 2);
      expect(literals[0].isRaw, isFalse);
      expect(literals[0].isMultiline, isFalse);

      expect(literals[1].value, 'world');
      expect(literals[1].lineNumber, 3);
      expect(literals[1].isRaw, isFalse);
      expect(literals[1].isMultiline, isFalse);
    });

    test('extracts raw strings with escapes verbatim', () {
      const source = r'''
const pattern = r'(\d+)d(\d+)';
const rawDouble = R"Hit\s+Die";
''';
      final literals = extractDartStringLiterals(source);
      expect(literals.length, 2);
      expect(literals[0].value, r'(\d+)d(\d+)');
      expect(literals[0].isRaw, isTrue);
      expect(literals[1].value, r'Hit\s+Die');
      expect(literals[1].isRaw, isTrue);
    });

    test('extracts triple-quoted and multi-line strings', () {
      const source = '''
const multiSingle = \'\'\'
Line 1
Line 2
\'\'\';
const multiDouble = """
Line A
Line B
""";
''';
      final literals = extractDartStringLiterals(source);
      expect(literals.length, 2);
      expect(literals[0].value, '\nLine 1\nLine 2\n');
      expect(literals[0].isMultiline, isTrue);
      expect(literals[1].value, '\nLine A\nLine B\n');
      expect(literals[1].isMultiline, isTrue);
    });

    test('joins adjacent string literals across whitespace, newlines, and comments', () {
      const source = '''
final joined = 'Hello, '
    // comment between literals
    /* block comment */
    'world!';
''';
      final literals = extractDartStringLiterals(source);
      expect(literals.length, 1);
      expect(literals[0].value, 'Hello, world!');
      expect(literals[0].lineNumber, 1);
    });

    test('joins adjacent multi-line regex fragments', () {
      const source = r'''
final r = RegExp(
  r'(\d+)d(\d+)'
  r'(?:\s*([+-])\s*(\d+))?'
);
''';
      final literals = extractDartStringLiterals(source);
      expect(literals.length, 1);
      expect(literals[0].value, r'(\d+)d(\d+)(?:\s*([+-])\s*(\d+))?');
      expect(literals[0].lineNumber, 2);
    });

    test('handles string interpolation extracting literal parts', () {
      const source = r'''
final msg = 'Hello, $name! Today is ${date.format(r"yyyy-MM-dd")}.';
''';
      final literals = extractDartStringLiterals(source);
      // Literal parts of msg, plus the inner string inside ${...}
      expect(literals.any((l) => l.value == 'Hello, '), isTrue);
      expect(literals.any((l) => l.value == '! Today is '), isTrue);
      expect(literals.any((l) => l.value == 'yyyy-MM-dd'), isTrue);
      expect(literals.any((l) => l.value == '.'), isTrue);
    });

    test('skips single-line and nested multi-line comments', () {
      const source = '''
// 'ignored single line comment'
/* 'ignored block comment'
   /* 'nested block comment' */
*/
const valid = 'retained';
''';
      final literals = extractDartStringLiterals(source);
      expect(literals.length, 1);
      expect(literals[0].value, 'retained');
    });

    test('throws FormatException on unclosed string literal', () {
      const unclosedSingleEof = "final s = 'hello world;";
      expect(
        () => extractDartStringLiterals(unclosedSingleEof),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unclosed string literal starting'),
        )),
      );

      const unclosedSingleNewline = "final s = 'hello world\n';";
      expect(
        () => extractDartStringLiterals(unclosedSingleNewline),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unclosed single-line string literal at newline'),
        )),
      );

      const unclosedTriple = "final s = '''hello world;";
      expect(
        () => extractDartStringLiterals(unclosedTriple),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unclosed string literal starting'),
        )),
      );
    });

    test('throws FormatException on unclosed block comment', () {
      const unclosedComment = "/* unclosed comment\nfinal s = 'hello';";
      expect(
        () => extractDartStringLiterals(unclosedComment),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unclosed block comment'),
        )),
      );
    });
  });
}
