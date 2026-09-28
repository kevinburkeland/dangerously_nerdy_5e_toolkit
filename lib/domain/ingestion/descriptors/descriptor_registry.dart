import 'monster_descriptor.dart';
import 'object_descriptor.dart';
import 'spell_descriptor.dart';

/// Registry holding schemas for all ingestible object types.
class DescriptorRegistry {
  static final Map<String, ObjectDescriptor> _descriptors = {
    'monster': const MonsterDescriptor(),
    'spell': const SpellDescriptor(),
  };

  /// Returns the descriptor for a given type key, or null if unsupported.
  static ObjectDescriptor? getDescriptor(String? typeKey) {
    if (typeKey == null) return null;
    return _descriptors[typeKey.toLowerCase().trim()];
  }

  /// Returns all registered object descriptors.
  static List<ObjectDescriptor> get allDescriptors =>
      _descriptors.values.toList();

  /// Returns list of all registered type keys (e.g. ['monster', 'spell']).
  static List<String> get supportedTypeKeys => _descriptors.keys.toList();

  /// Registers a new or custom descriptor.
  static void register(ObjectDescriptor descriptor) {
    _descriptors[descriptor.typeKey.toLowerCase().trim()] = descriptor;
  }
}
