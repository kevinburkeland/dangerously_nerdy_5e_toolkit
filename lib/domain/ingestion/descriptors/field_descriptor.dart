import 'package:meta/meta.dart';

enum FieldValueType {
  string,
  integer,
  floating,
  boolean,
  diceFormula,
  markdown,
  stringList,
  abilityScores,
}

/// Metadata describing an individual field for an ingestible object type.
@immutable
class FieldDescriptor {
  final String key;
  final String label;
  final FieldValueType valueType;
  final bool isRequired;
  final String? description;
  final String? placeholder;
  final String? Function(dynamic value)? customValidator;

  const FieldDescriptor({
    required this.key,
    required this.label,
    required this.valueType,
    this.isRequired = false,
    this.description,
    this.placeholder,
    this.customValidator,
  });

  /// Validates a candidate value according to this descriptor's type and rules.
  /// Returns null if valid, or an error message if invalid.
  String? validate(dynamic value) {
    if (isRequired && (value == null || value.toString().trim().isEmpty)) {
      return '$label is required.';
    }
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
        // Other types have no default structure restrictions
    }

    if (customValidator != null) {
      return customValidator!(value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldDescriptor &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          label == other.label &&
          valueType == other.valueType &&
          isRequired == other.isRequired;

  @override
  int get hashCode => Object.hash(key, label, valueType, isRequired);

  @override
  String toString() =>
      'FieldDescriptor($key, $label, type: $valueType, req: $isRequired)';
}
