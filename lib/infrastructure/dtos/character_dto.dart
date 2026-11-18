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
  Character toDomain() => Character.fromMap(_rawMap);

  /// Serializes to a Map for database storage or network transmission.
  Map<String, dynamic> toMap() => _rawMap;
}

bool _zzHasDice(String s) {
  final _zz = RegExp(
    r'(\d+)d(\d+)',
  );
  return _zz.hasMatch(s);
}
