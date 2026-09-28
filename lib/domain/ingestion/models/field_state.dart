/// Semantic parsing state of an extracted or missing field in the ingestion workbench.
enum IngestionFieldState {
  /// Directly and unambiguously parsed from source text.
  extracted,

  /// Inferred from context or 5e rule conventions; NOT explicitly stated in source.
  inferred,

  /// Multiple plausible interpretations or source text contains uncertainty (e.g. "CR ?").
  ambiguous,

  /// Value fails syntax, type, or domain range validation (e.g. AC "lots").
  invalid,

  /// Expected or required field completely missing from source text.
  missing,

  /// Field was not provided in source, but is optional according to the object descriptor.
  optionalNotProvided;

  /// Compact symbol for visual identification.
  String get symbol => switch (this) {
        IngestionFieldState.extracted => '✓',
        IngestionFieldState.inferred => '~',
        IngestionFieldState.ambiguous => '?',
        IngestionFieldState.invalid => '!',
        IngestionFieldState.missing => '—',
        IngestionFieldState.optionalNotProvided => '○',
      };

  /// User-friendly name.
  String get displayName => switch (this) {
        IngestionFieldState.extracted => 'Extracted',
        IngestionFieldState.inferred => 'Inferred',
        IngestionFieldState.ambiguous => 'Ambiguous',
        IngestionFieldState.invalid => 'Invalid',
        IngestionFieldState.missing => 'Missing',
        IngestionFieldState.optionalNotProvided => 'Optional / Not Provided',
      };

  /// Accessible screen reader label.
  String get screenReaderLabel => switch (this) {
        IngestionFieldState.extracted => 'Extracted value',
        IngestionFieldState.inferred => 'Inferred value',
        IngestionFieldState.ambiguous => 'Ambiguous value requiring clarification',
        IngestionFieldState.invalid => 'Invalid field value',
        IngestionFieldState.missing => 'Missing required field',
        IngestionFieldState.optionalNotProvided => 'Optional field not provided',
      };

  /// Whether this state blocks domain entity creation when the field is required.
  bool get isBlocking =>
      this == IngestionFieldState.missing ||
      this == IngestionFieldState.invalid ||
      this == IngestionFieldState.ambiguous;
}
