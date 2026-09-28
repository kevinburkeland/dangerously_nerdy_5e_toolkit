import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_block.dart';

void main() {
  group('SourceBlockParser Tests', () {
    const parser = SourceBlockParser();

    test('normalizes windows line endings and tracks spans accurately', () {
      const source = 'Line 1\r\nLine 2\r\nLine 3';
      final doc = parser.parse(source);

      expect(doc.blocks.length, equals(3));
      expect(doc.blocks[0].normalizedText, equals('Line 1'));
      expect(doc.blocks[0].span.startLine, equals(1));
      expect(doc.blocks[0].span.endLine, equals(1));
      expect(doc.blocks[1].normalizedText, equals('Line 2'));
      expect(doc.blocks[1].span.startLine, equals(2));
      expect(doc.blocks[2].normalizedText, equals('Line 3'));
      expect(doc.blocks[2].span.startLine, equals(3));
    });

    test('identifies markdown headings and heading levels', () {
      const source = '''
# Top Heading
## Secondary Heading
### Stat Block Title
Normal paragraph text.
''';
      final doc = parser.parse(source);

      expect(doc.blocks[0].type, equals(SourceBlockType.heading));
      expect(doc.blocks[0].headingLevel, equals(1));
      expect(doc.blocks[0].headingText, equals('Top Heading'));

      expect(doc.blocks[1].type, equals(SourceBlockType.heading));
      expect(doc.blocks[1].headingLevel, equals(2));
      expect(doc.blocks[1].headingText, equals('Secondary Heading'));

      expect(doc.blocks[2].type, equals(SourceBlockType.heading));
      expect(doc.blocks[2].headingLevel, equals(3));
      expect(doc.blocks[2].headingText, equals('Stat Block Title'));

      expect(doc.blocks[3].type, equals(SourceBlockType.paragraph));
    });

    test('identifies dividers and stat lines', () {
      const source = '''
Armor Class 16 (chain mail)
---
Hit Points 52 (8d8 + 16)
''';
      final doc = parser.parse(source);

      expect(doc.blocks[0].type, equals(SourceBlockType.statLine));
      expect(doc.blocks[1].type, equals(SourceBlockType.divider));
      expect(doc.blocks[2].type, equals(SourceBlockType.statLine));
    });
  });
}
