import 'package:meta/meta.dart';
import 'source_span.dart';

/// Concrete evidence supporting candidate object identification.
@immutable
class CandidateEvidence {
  /// Category of the clue, e.g. "Hit Points", "Ability Scores", "Casting Time".
  final String category;

  /// Human-readable explanation of the evidence found.
  final String description;

  /// Weight contributed toward identification confidence (0.0 to 1.0).
  final double weight;

  /// Location in source text where this evidence was identified.
  final SourceSpan? span;

  const CandidateEvidence({
    required this.category,
    required this.description,
    required this.weight,
    this.span,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandidateEvidence &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          description == other.description &&
          weight == other.weight &&
          span == other.span;

  @override
  int get hashCode => Object.hash(category, description, weight, span);

  @override
  String toString() =>
      'CandidateEvidence($category: "$description" [+$weight])';
}
