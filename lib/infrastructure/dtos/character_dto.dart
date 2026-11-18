import '../../models/domain/character_models.dart';

/// Thin Data Transfer Object codec for [Character], wrapping raw map
/// serialization at the Infrastructure boundary.
class CharacterDto {
  final Map<String, dynamic> _rawMap;

  const CharacterDto._(this._rawMap);

  /// Deserializes a raw Map payload into [CharacterDto].
  factory CharacterDto.fromMap(Map<String, dynamic> map) {
    return CharacterDto._(Map<String, dynamic>.from(map));
  }

  /// Creates a DTO from a domain [Character].
  factory CharacterDto.fromDomain(Character character) {
    return CharacterDto._(character.toMap());
  }

  String get name => _rawMap['name'] is String
      ? _rawMap['name'] as String
      : 'Unknown Adventurer';

  /// Converts this DTO into a domain [Character] entity.
  Character toDomain() {
    final copy = Map<String, dynamic>.from(_rawMap);
    if (copy['level'] is num) {
      copy['level'] = (copy['level'] as num).toInt().clamp(1, 20);
    }
    final prog = copy['progression'];
    if (prog is Map && prog['classes'] is List) {
      final progCopy = Map<String, dynamic>.from(prog);
      progCopy['classes'] = [
        for (final c in progCopy['classes'] as List)
          if (c is Map && c['level'] is num)
            {
              ...Map<String, dynamic>.from(c),
              'level': (c['level'] as num).toInt().clamp(1, 20),
            }
          else
            c,
      ];
      copy['progression'] = progCopy;
    }
    return Character.fromMap(copy);
  }

  /// Serializes to a Map for database storage or network transmission.
  Map<String, dynamic> toMap() => _rawMap;
}
