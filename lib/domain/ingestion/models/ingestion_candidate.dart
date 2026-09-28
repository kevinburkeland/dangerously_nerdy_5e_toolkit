import 'package:meta/meta.dart';
import 'candidate_identification.dart';
import 'field_state.dart';
import 'ingestion_field.dart';
import 'source_block.dart';
import 'source_span.dart';

/// A candidate game object discovered in source text, holding extracted/inferred fields,
/// missing invariants, unassigned blocks, and user edits before domain validation.
@immutable
class IngestionCandidate {
  final String id;
  final SourceSpan span;
  final String rawSource;
  final String normalizedSource;
  final List<SourceBlock> blocks;
  final CandidateIdentification identification;

  /// The active target type key (e.g. 'monster', 'spell', 'item').
  /// Can be null if the candidate is unresolved (unknown or ambiguous).
  final String? targetTypeKey;

  /// Extracted, inferred, invalid, or missing fields keyed by property name.
  final Map<String, IngestionField<dynamic>> fields;

  /// Blocks within this candidate's span that were not mapped to any known field.
  final List<SourceBlock> unrecognizedBlocks;

  /// Set of block IDs that the user has explicitly marked as ignored.
  final Set<String> ignoredBlockIds;

  /// Non-blocking warnings or guidance notices.
  final List<String> warnings;

  /// Fatal/blocking validation or parsing errors.
  final List<String> errors;

  /// True if the user manually modified candidate type or fields.
  final bool isUserOverridden;

  const IngestionCandidate({
    required this.id,
    required this.span,
    required this.rawSource,
    required this.normalizedSource,
    required this.blocks,
    required this.identification,
    this.targetTypeKey,
    required this.fields,
    this.unrecognizedBlocks = const [],
    this.ignoredBlockIds = const {},
    this.warnings = const [],
    this.errors = const [],
    this.isUserOverridden = false,
  });

  /// True if the candidate has an explicitly resolved or chosen target type.
  bool get isTypeResolved =>
      targetTypeKey != null && targetTypeKey!.trim().isNotEmpty;

  /// Best display name available for this candidate.
  String get displayName {
    final nameField = fields['name'];
    if (nameField != null &&
        nameField.value != null &&
        nameField.value.toString().trim().isNotEmpty) {
      return nameField.value.toString().trim();
    }
    if (blocks.isNotEmpty && blocks.first.headingText != null) {
      return blocks.first.headingText!.trim();
    }
    if (identification.isAmbiguous) {
      return 'Ambiguous (${identification.plausibleTypeKeys.join(" / ")})';
    }
    if (identification.isUnknown) {
      return 'Unknown Object';
    }
    return 'Unnamed ${targetTypeKey != null && targetTypeKey!.isNotEmpty ? targetTypeKey![0].toUpperCase() + targetTypeKey!.substring(1) : "Candidate"}';
  }

  /// List of fields that are required by the schema but are currently missing.
  List<IngestionField<dynamic>> get missingRequiredFields => fields.values
      .where((f) => f.isRequired && f.state == IngestionFieldState.missing)
      .toList();

  /// List of fields that have invalid values or failed validation.
  List<IngestionField<dynamic>> get invalidFields => fields.values
      .where((f) => f.state == IngestionFieldState.invalid)
      .toList();

  /// List of fields that have unresolved ambiguous values.
  List<IngestionField<dynamic>> get ambiguousFields => fields.values
      .where((f) => f.state == IngestionFieldState.ambiguous)
      .toList();

  /// List of successfully extracted or user-supplied fields.
  List<IngestionField<dynamic>> get validFields => fields.values
      .where((f) =>
          f.state == IngestionFieldState.extracted ||
          (f.isUserEdited && f.value != null))
      .toList();

  /// True if candidate type is resolved and there are zero missing required fields,
  /// zero invalid fields, and zero blocking ambiguities.
  bool get isReadyToCommit =>
      isTypeResolved &&
      missingRequiredFields.isEmpty &&
      invalidFields.isEmpty &&
      ambiguousFields.isEmpty &&
      errors.isEmpty;

  /// Returns a copy of this candidate with an updated field.
  IngestionCandidate updateField(String fieldKey, IngestionField<dynamic> updatedField) {
    final newFields = Map<String, IngestionField<dynamic>>.from(fields);
    newFields[fieldKey] = updatedField;
    return copyWith(
      fields: newFields,
      isUserOverridden: true,
    );
  }

  /// Toggles ignore state on an unrecognized block.
  IngestionCandidate toggleIgnoreBlock(String blockId) {
    final newIgnored = Set<String>.from(ignoredBlockIds);
    if (newIgnored.contains(blockId)) {
      newIgnored.remove(blockId);
    } else {
      newIgnored.add(blockId);
    }
    return copyWith(ignoredBlockIds: newIgnored);
  }

  IngestionCandidate copyWith({
    String? id,
    SourceSpan? span,
    String? rawSource,
    String? normalizedSource,
    List<SourceBlock>? blocks,
    CandidateIdentification? identification,
    String? targetTypeKey,
    bool clearTargetTypeKey = false,
    Map<String, IngestionField<dynamic>>? fields,
    List<SourceBlock>? unrecognizedBlocks,
    Set<String>? ignoredBlockIds,
    List<String>? warnings,
    List<String>? errors,
    bool? isUserOverridden,
  }) {
    return IngestionCandidate(
      id: id ?? this.id,
      span: span ?? this.span,
      rawSource: rawSource ?? this.rawSource,
      normalizedSource: normalizedSource ?? this.normalizedSource,
      blocks: blocks ?? this.blocks,
      identification: identification ?? this.identification,
      targetTypeKey: clearTargetTypeKey
          ? null
          : (targetTypeKey ?? this.targetTypeKey),
      fields: fields ?? this.fields,
      unrecognizedBlocks: unrecognizedBlocks ?? this.unrecognizedBlocks,
      ignoredBlockIds: ignoredBlockIds ?? this.ignoredBlockIds,
      warnings: warnings ?? this.warnings,
      errors: errors ?? this.errors,
      isUserOverridden: isUserOverridden ?? this.isUserOverridden,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngestionCandidate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          targetTypeKey == other.targetTypeKey &&
          isUserOverridden == other.isUserOverridden;

  @override
  int get hashCode => Object.hash(id, targetTypeKey, isUserOverridden);

  @override
  String toString() =>
      'IngestionCandidate(id: $id, type: $targetTypeKey, name: "$displayName", fields: ${fields.length})';
}
