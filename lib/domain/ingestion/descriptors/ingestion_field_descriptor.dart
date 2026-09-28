import 'package:meta/meta.dart';

/// Semantic role of a source field from a parsing/recognition perspective.
/// Distinct from domain invariants.
enum SourceFieldExpectation {
  /// Expected to be present to confidently identify and parse this candidate type.
  requiredForRecognition,

  /// Commonly present in traditional stat blocks or rules text, but not strictly
  /// a universal barrier to recognizing the candidate.
  commonlyPresent,

  /// Optional or situational field (e.g. reactions, legendary actions, upcast text).
  optional,
}

/// Primitive value types for purely syntactic parser validation.
enum FieldValueType {
  string,
  integer,
  floating,
  boolean,
  diceFormula,
  custom,
}

/// Generic, ruleset-agnostic descriptor for a field observed during ingestion.
///
/// Contains parsing metadata: labels, aliases, syntactic validation rules,
/// and source expectations. It does NOT define domain invariants.
@immutable
class IngestionFieldDescriptor {
  final String key;
  final String label;
  final SourceFieldExpectation expectation;
  final FieldValueType valueType;
  final String? helpText;
  final List<String> aliases;

  const IngestionFieldDescriptor({
    required this.key,
    required this.label,
    this.expectation = SourceFieldExpectation.commonlyPresent,
    this.valueType = FieldValueType.string,
    this.helpText,
    this.aliases = const [],
  });

  bool get isRequiredForRecognition =>
      expectation == SourceFieldExpectation.requiredForRecognition;

  /// Purely syntactic validation (e.g. valid integer format, valid dice notation).
  /// Ruleset domain validation is owned by RulesetIngestionCapability.
  String? validateSyntactic(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    switch (valueType) {
      case FieldValueType.integer:
        if (value is! int && int.tryParse(value.toString().trim()) == null) {
          return '$label must be a valid whole number (got "${value.toString()}").';
        }
      case FieldValueType.floating:
        if (value is! num && double.tryParse(value.toString().trim()) == null) {
          return '$label must be a valid number.';
        }
      case FieldValueType.boolean:
        if (value is! bool) {
          final s = value.toString().trim().toLowerCase();
          if (s != 'true' && s != 'false' && s != 'yes' && s != 'no') {
            return '$label must be true or false.';
          }
        }
      case FieldValueType.diceFormula:
        final s = value.toString().trim();
        final diceRegex = RegExp(r'^\d*d\d+(\s*[+-]\s*\d+)?$', caseSensitive: false);
        if (!diceRegex.hasMatch(s)) {
          return '$label must be valid dice notation (e.g. "2d6", "1d10+3"). Got "$s".';
        }
      default:
        break;
    }

    return null;
  }
}
