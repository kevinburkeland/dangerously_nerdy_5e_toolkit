import 'package:meta/meta.dart';
import 'source_span.dart';

enum SourceBlockType {
  heading,
  statLine,
  paragraph,
  list,
  divider,
  table,
  unknown,
}

/// A syntactically partitioned unit of text from the source document.
@immutable
class SourceBlock {
  final String id;
  final String rawText;
  final String normalizedText;
  final SourceSpan span;
  final SourceBlockType type;
  final String? headingText;
  final int headingLevel;
  final bool isIgnored;

  const SourceBlock({
    required this.id,
    required this.rawText,
    required this.normalizedText,
    required this.span,
    this.type = SourceBlockType.paragraph,
    this.headingText,
    this.headingLevel = 0,
    this.isIgnored = false,
  });

  SourceBlock copyWith({
    String? id,
    String? rawText,
    String? normalizedText,
    SourceSpan? span,
    SourceBlockType? type,
    String? headingText,
    int? headingLevel,
    bool? isIgnored,
  }) {
    return SourceBlock(
      id: id ?? this.id,
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      span: span ?? this.span,
      type: type ?? this.type,
      headingText: headingText ?? this.headingText,
      headingLevel: headingLevel ?? this.headingLevel,
      isIgnored: isIgnored ?? this.isIgnored,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rawText == other.rawText &&
          normalizedText == other.normalizedText &&
          span == other.span &&
          type == other.type &&
          headingText == other.headingText &&
          headingLevel == other.headingLevel &&
          isIgnored == other.isIgnored;

  @override
  int get hashCode => Object.hash(
        id,
        rawText,
        normalizedText,
        span,
        type,
        headingText,
        headingLevel,
        isIgnored,
      );

  @override
  String toString() =>
      'SourceBlock(id: $id, type: $type, span: ${span.locationString}, heading: $headingText)';
}
