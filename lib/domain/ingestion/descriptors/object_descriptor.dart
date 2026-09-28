import 'package:meta/meta.dart';
import 'field_descriptor.dart';

/// Contract defining schema invariants, expected fields, and validation for an ingestible object type.
@immutable
abstract class ObjectDescriptor {
  const ObjectDescriptor();

  /// Internal programmatic key (e.g. 'monster', 'spell', 'equipment', 'feat').
  String get typeKey;

  /// User-facing display title.
  String get displayName;

  /// Human description of this object type.
  String get description;

  /// Complete list of known fields for this object type.
  List<FieldDescriptor> get fields;

  /// Quick map lookup for a field descriptor by key.
  FieldDescriptor? getField(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// Fields that MUST be present and valid before conversion to domain entity.
  List<FieldDescriptor> get requiredFields =>
      fields.where((f) => f.isRequired).toList();

  /// Optional fields.
  List<FieldDescriptor> get optionalFields =>
      fields.where((f) => !f.isRequired).toList();
}
