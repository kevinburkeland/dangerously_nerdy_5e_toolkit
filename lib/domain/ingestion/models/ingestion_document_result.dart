import 'package:meta/meta.dart';
import 'ingestion_candidate.dart';
import 'source_block.dart';
import 'source_document.dart';

/// Top-level result of parsing source text into candidate objects and unassigned sections.
@immutable
class IngestionDocumentResult {
  final SourceDocument source;
  final List<IngestionCandidate> candidates;

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
    this.unassignedBlocks = const [],
    this.warnings = const [],
    this.parseDurationMs = 0,
  });

  const IngestionDocumentResult.empty()
      : source = const SourceDocument.empty(),
        candidates = const [],
        unassignedBlocks = const [],
        warnings = const [],
        parseDurationMs = 0;

  bool get isEmpty => candidates.isEmpty && unassignedBlocks.isEmpty;
  bool get hasCandidates => candidates.isNotEmpty;
  bool get hasUnassigned => unassignedBlocks.isNotEmpty;

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
    List<SourceBlock>? unassignedBlocks,
    List<String>? warnings,
    int? parseDurationMs,
  }) {
    return IngestionDocumentResult(
      source: source ?? this.source,
      candidates: candidates ?? this.candidates,
      unassignedBlocks: unassignedBlocks ?? this.unassignedBlocks,
      warnings: warnings ?? this.warnings,
      parseDurationMs: parseDurationMs ?? this.parseDurationMs,
    );
  }

  @override
  String toString() =>
      'IngestionDocumentResult(candidates: ${candidates.length}, unassigned: ${unassignedBlocks.length}, took: ${parseDurationMs}ms)';
}
