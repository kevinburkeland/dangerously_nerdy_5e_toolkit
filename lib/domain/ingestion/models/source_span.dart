import 'package:meta/meta.dart';

/// Represents a precise character range and line/column coordinate within the source text.
@immutable
class SourceSpan {
  final int startOffset;
  final int endOffset;
  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;
  final String text;

  const SourceSpan({
    required this.startOffset,
    required this.endOffset,
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
    required this.text,
  });

  const SourceSpan.empty()
      : startOffset = 0,
        endOffset = 0,
        startLine = 1,
        startColumn = 1,
        endLine = 1,
        endColumn = 1,
        text = '';

  int get length => endOffset - startOffset;
  bool get isEmpty => length <= 0;

  String get locationString => 'Line $startLine:$startColumn';

  SourceSpan copyWith({
    int? startOffset,
    int? endOffset,
    int? startLine,
    int? startColumn,
    int? endLine,
    int? endColumn,
    String? text,
  }) {
    return SourceSpan(
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      startLine: startLine ?? this.startLine,
      startColumn: startColumn ?? this.startColumn,
      endLine: endLine ?? this.endLine,
      endColumn: endColumn ?? this.endColumn,
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceSpan &&
          runtimeType == other.runtimeType &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset &&
          startLine == other.startLine &&
          startColumn == other.startColumn &&
          endLine == other.endLine &&
          endColumn == other.endColumn &&
          text == other.text;

  @override
  int get hashCode => Object.hash(
        startOffset,
        endOffset,
        startLine,
        startColumn,
        endLine,
        endColumn,
        text,
      );

  @override
  String toString() => 'SourceSpan($locationString, len: $length, "$text")';
}
