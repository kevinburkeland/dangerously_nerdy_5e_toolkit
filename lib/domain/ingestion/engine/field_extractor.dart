import '../descriptors/ingestion_target_descriptor.dart';
import '../models/ingestion_field.dart';
import '../models/source_block.dart';
import '../models/source_span.dart';

class FieldExtractionResult {
  final Map<String, IngestionField<dynamic>> fields;
  final List<SourceBlock> unrecognizedBlocks;

  const FieldExtractionResult({
    required this.fields,
    this.unrecognizedBlocks = const [],
  });
}

/// Abstract contract for extracting target-specific fields from source blocks.
abstract interface class FieldExtractor {
  FieldExtractionResult extract({
    required List<SourceBlock> blocks,
    required IngestionTargetDescriptor descriptor,
    SourceSpan? span,
  });
}
