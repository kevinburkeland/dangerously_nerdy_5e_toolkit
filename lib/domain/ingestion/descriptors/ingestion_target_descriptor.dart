import 'package:meta/meta.dart';
import 'ingestion_field_descriptor.dart';

/// Ruleset-agnostic schema description for an ingestible candidate target type
/// (e.g. 'monster', 'spell', 'item', 'feat').
@immutable
abstract class IngestionTargetDescriptor {
  /// Machine-readable key (e.g. 'monster', 'spell').
  String get typeKey;

  /// User-facing display title (e.g. 'Monster / Creature', 'Spell').
  String get displayName;

  /// Fields expected or supported by this target type.
  List<IngestionFieldDescriptor> get fields;

  const IngestionTargetDescriptor();

  /// Returns the field descriptor for [fieldKey], or null if unrecognized.
  IngestionFieldDescriptor? getField(String fieldKey) {
    try {
      return fields.firstWhere((f) => f.key == fieldKey);
    } catch (_) {
      return null;
    }
  }

  /// Fields expected for confident candidate recognition.
  List<IngestionFieldDescriptor> get recognitionFields =>
      fields.where((f) => f.isRequiredForRecognition).toList();
}
