import 'package:meta/meta.dart';
import 'field_state.dart';
import 'source_span.dart';

/// A typed, inspectable field extracted from source text or declared missing/invalid.
@immutable
class IngestionField<T> {
  /// Internal programmatic key (e.g. 'armorClass', 'hitPoints', 'castingTime').
  final String key;

  /// User-facing label (e.g. 'Armor Class', 'Hit Points').
  final String label;

  /// Semantic state of this field (extracted, missing, invalid, ambiguous, etc.).
  final IngestionFieldState state;

  /// Exact unparsed text substring representing this field in source, if present.
  final String? rawText;

  /// Strongly-typed parsed or user-provided value.
  final T? value;

  /// Source span for traceability to original source document.
  final SourceSpan? span;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Short explanation of how this value was extracted or why it is in this state.
  final String? evidence;

  /// Selectable options when state is ambiguous.
  final List<String> ambiguousOptions;

  /// Validation error description when state is invalid.
  final String? validationError;

  /// True if the user manually modified this field in the workbench editor.
  final bool isUserEdited;

  /// True if this field is required by the domain object's invariants.
  final bool isRequired;

  const IngestionField({
    required this.key,
    required this.label,
    required this.state,
    this.rawText,
    this.value,
    this.span,
    this.confidence = 1.0,
    this.evidence,
    this.ambiguousOptions = const [],
    this.validationError,
    this.isUserEdited = false,
    this.isRequired = false,
  });

  /// Factory for a cleanly extracted field.
  factory IngestionField.extracted({
    required String key,
    required String label,
    required T value,
    String? rawText,
    SourceSpan? span,
    double confidence = 1.0,
    String? evidence,
    bool isRequired = false,
    bool isUserEdited = false,
  }) {
    return IngestionField<T>(
      key: key,
      label: label,
      state: IngestionFieldState.extracted,
      value: value,
      rawText: rawText ?? value.toString(),
      span: span,
      confidence: confidence,
      evidence: evidence,
      isRequired: isRequired,
      isUserEdited: isUserEdited,
    );
  }

  /// Factory for an inferred field (never authoritative without review).
  factory IngestionField.inferred({
    required String key,
    required String label,
    required T value,
    required String evidence,
    SourceSpan? span,
    double confidence = 0.6,
    bool isRequired = false,
  }) {
    return IngestionField<T>(
      key: key,
      label: label,
      state: IngestionFieldState.inferred,
      value: value,
      rawText: null,
      span: span,
      confidence: confidence,
      evidence: evidence,
      isRequired: isRequired,
    );
  }

  /// Factory for a missing field.
  factory IngestionField.missing({
    required String key,
    required String label,
    bool isRequired = true,
    String? evidence,
  }) {
    return IngestionField<T>(
      key: key,
      label: label,
      state: IngestionFieldState.missing,
      value: null,
      rawText: null,
      isRequired: isRequired,
      evidence: evidence ?? 'Expected in standard stat block but not found in source text',
    );
  }

  /// Factory for an ambiguous field.
  factory IngestionField.ambiguous({
    required String key,
    required String label,
    required List<String> options,
    String? rawText,
    SourceSpan? span,
    bool isRequired = false,
    String? evidence,
  }) {
    return IngestionField<T>(
      key: key,
      label: label,
      state: IngestionFieldState.ambiguous,
      value: null,
      rawText: rawText,
      span: span,
      ambiguousOptions: options,
      isRequired: isRequired,
      evidence: evidence ?? 'Source contains multiple plausible interpretations',
    );
  }

  /// Factory for an invalid field.
  factory IngestionField.invalid({
    required String key,
    required String label,
    required String rawText,
    required String validationError,
    SourceSpan? span,
    bool isRequired = false,
  }) {
    return IngestionField<T>(
      key: key,
      label: label,
      state: IngestionFieldState.invalid,
      value: null,
      rawText: rawText,
      span: span,
      validationError: validationError,
      isRequired: isRequired,
    );
  }

  /// Factory for an optional field that was not provided.
  factory IngestionField.optionalNotProvided({
    required String key,
    required String label,
  }) {
    return IngestionField<T>(
      key: key,
      label: label,
      state: IngestionFieldState.optionalNotProvided,
      value: null,
      rawText: null,
      isRequired: false,
    );
  }

  /// Returns a new instance representing a user manual edit.
  IngestionField<T> withUserEdit(T? newValue, {String? newRawText}) {
    return copyWith(
      value: newValue,
      rawText: newRawText ?? (newValue?.toString()),
      state: newValue != null
          ? IngestionFieldState.extracted
          : (isRequired ? IngestionFieldState.missing : IngestionFieldState.optionalNotProvided),
      isUserEdited: true,
      validationError: null,
    );
  }

  IngestionField<T> copyWith({
    String? key,
    String? label,
    IngestionFieldState? state,
    String? rawText,
    T? value,
    SourceSpan? span,
    double? confidence,
    String? evidence,
    List<String>? ambiguousOptions,
    String? validationError,
    bool? isUserEdited,
    bool? isRequired,
  }) {
    return IngestionField<T>(
      key: key ?? this.key,
      label: label ?? this.label,
      state: state ?? this.state,
      rawText: rawText ?? this.rawText,
      value: value ?? this.value,
      span: span ?? this.span,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      ambiguousOptions: ambiguousOptions ?? this.ambiguousOptions,
      validationError: validationError ?? this.validationError,
      isUserEdited: isUserEdited ?? this.isUserEdited,
      isRequired: isRequired ?? this.isRequired,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngestionField &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          label == other.label &&
          state == other.state &&
          rawText == other.rawText &&
          value == other.value &&
          span == other.span &&
          isUserEdited == other.isUserEdited &&
          isRequired == other.isRequired &&
          validationError == other.validationError;

  @override
  int get hashCode => Object.hash(
        key,
        label,
        state,
        rawText,
        value,
        span,
        isUserEdited,
        isRequired,
        validationError,
      );

  @override
  String toString() =>
      'IngestionField($key [${state.symbol}]: ${value ?? rawText ?? "[none]"} userEdited: $isUserEdited)';
}
