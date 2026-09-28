import '../descriptors/object_descriptor.dart';
import '../models/ingestion_field.dart';
import '../models/source_block.dart';

class FieldExtractionResult {
  final Map<String, IngestionField<dynamic>> fields;
  final List<SourceBlock> unrecognizedBlocks;

  const FieldExtractionResult({
    required this.fields,
    this.unrecognizedBlocks = const [],
  });
}

/// Abstract contract for extracting object-specific fields from source blocks.
abstract class FieldExtractor {
  FieldExtractionResult extract({
    required List<SourceBlock> blocks,
    required ObjectDescriptor descriptor,
  });
}
