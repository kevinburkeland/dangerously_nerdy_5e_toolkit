import 'package:meta/meta.dart';
import 'ingestion_candidate.dart';
import 'ingestion_section.dart';
import 'source_block.dart';
import 'source_document.dart';

/// Top-level result of parsing source text into hierarchical sections, candidate objects,
/// and unassigned blocks.
@immutable
class IngestionDocumentResult {
  final SourceDocument source;
  final List<IngestionCandidate> candidates;

  /// Top-level structural sections decomposing the source document hierarchically.
  final List<IngestionSection> sections;

  /// Text blocks from the source document that were not assigned to any detected candidate.
  /// (e.g., surrounding prose, narrative intros, author notes, or unparseable sections).
  final List<SourceBlock> unassignedBlocks;

  /// System or parser level warnings.
  final List<String> warnings;

  /// Elapsed duration of parse in milliseconds.
  final int parseDurationMs;

  const IngestionDocumentResult({
    required this.source,
    required this.candidates,
    this.sections = const [],
    this.unassignedBlocks = const [],
    this.warnings = const [],
    this.parseDurationMs = 0,
  });

  const IngestionDocumentResult.empty()
      : source = const SourceDocument.empty(),
        candidates = const [],
        sections = const [],
        unassignedBlocks = const [],
        warnings = const [],
        parseDurationMs = 0;

  bool get isEmpty => candidates.isEmpty && sections.isEmpty && unassignedBlocks.isEmpty;
  bool get hasCandidates => candidates.isNotEmpty;
  bool get hasSections => sections.isNotEmpty;
  bool get hasUnassigned => unassignedBlocks.isNotEmpty;

  /// Finds an [IngestionSection] by its unique [sectionId] across the entire section tree.
  IngestionSection? findSection(String sectionId) {
    for (final section in sections) {
      final found = section.findSection(sectionId);
      if (found != null) return found;
    }
    return null;
  }

  /// Updates a section in the hierarchical tree matching [sectionId] with [updated].
  IngestionDocumentResult updateSection(String sectionId, IngestionSection updated) {
    final nextSections = sections.map((s) => s.updateSection(sectionId, updated)).toList();
    return copyWith(sections: nextSections);
  }

  IngestionDocumentResult updateCandidate(
      int index, IngestionCandidate updated) {
    final nextCandidates = List<IngestionCandidate>.from(candidates);
    if (index >= 0 && index < nextCandidates.length) {
      nextCandidates[index] = updated;
    }
    return copyWith(candidates: nextCandidates);
  }

  IngestionDocumentResult copyWith({
    SourceDocument? source,
    List<IngestionCandidate>? candidates,
    List<IngestionSection>? sections,
    List<SourceBlock>? unassignedBlocks,
    List<String>? warnings,
    int? parseDurationMs,
  }) {
    return IngestionDocumentResult(
      source: source ?? this.source,
      candidates: candidates ?? this.candidates,
      sections: sections ?? this.sections,
      unassignedBlocks: unassignedBlocks ?? this.unassignedBlocks,
      warnings: warnings ?? this.warnings,
      parseDurationMs: parseDurationMs ?? this.parseDurationMs,
    );
  }

  @override
  String toString() =>
      'IngestionDocumentResult(candidates: ${candidates.length}, sections: ${sections.length}, unassigned: ${unassignedBlocks.length}, took: ${parseDurationMs}ms)';
}
