import 'package:meta/meta.dart';
import 'source_block.dart';

/// Represents the processed source document partitioned into blocks.
@immutable
class SourceDocument {
  final String rawText;
  final String normalizedText;
  final List<SourceBlock> blocks;

  const SourceDocument({
    required this.rawText,
    required this.normalizedText,
    required this.blocks,
  });

  const SourceDocument.empty()
      : rawText = '',
        normalizedText = '',
        blocks = const [];

  bool get isEmpty => rawText.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceDocument &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          normalizedText == other.normalizedText;

  @override
  int get hashCode => Object.hash(rawText, normalizedText);

  @override
  String toString() =>
      'SourceDocument(lines: ${normalizedText.split('\n').length}, blocks: ${blocks.length})';
}
