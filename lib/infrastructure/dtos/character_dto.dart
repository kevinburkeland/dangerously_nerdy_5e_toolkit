import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/domain/character_models.dart';

/// Data Transfer Object for [Character], isolating full document serialization
/// and deserialization to the Infrastructure layer.
@immutable
class CharacterDto {
  final Map<String, dynamic> rawMap;

  const CharacterDto(this.rawMap);

  /// Factory creating a DTO from a domain [Character].
  factory CharacterDto.fromDomain(Character character) {
    return CharacterDto(character.toMap());
  }

  /// Deserializes a raw Map payload into [CharacterDto].
  factory CharacterDto.fromMap(Map<String, dynamic> map) {
    return CharacterDto(map);
  }

  /// Converts this DTO into a domain [Character] entity.
  Character toDomain() {
    return Character.fromMap(rawMap);
  }

  /// Serializes to a Map for database storage.
  Map<String, dynamic> toMap() => rawMap;

  /// Serializes to JSON string.
  String toJson() => json.encode(rawMap);

  /// Deserializes from JSON string.
  factory CharacterDto.fromJson(String jsonStr) {
    return CharacterDto(Map<String, dynamic>.from(json.decode(jsonStr) as Map));
  }
}
