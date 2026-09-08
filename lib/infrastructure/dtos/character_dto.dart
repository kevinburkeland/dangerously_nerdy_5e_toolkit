import 'dart:convert';
import '../../models/domain/character_models.dart';

/// Data Transfer Object for [Character], isolating full document serialization,
/// legacy unparsed payload preservation, and external ACL boundary transformations
/// to the Infrastructure layer.
class CharacterDto {
  final String id;
  final String name;
  final int level;
  final int strength;
  final Map<String, dynamic> unparsedPayload;
  final Map<String, dynamic> _rawMap;

  const CharacterDto({
    required this.id,
    required this.name,
    required this.level,
    required this.strength,
    this.unparsedPayload = const {},
    Map<String, dynamic>? rawMap,
  }) : _rawMap = rawMap ?? const {};

  /// Deserializes a raw Map payload into [CharacterDto] while preserving arbitrary unknown
  /// homebrew fields and clamping core attributes safely.
  factory CharacterDto.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'id', 'name', 'level', 'strength'};
    final unparsed = <String, dynamic>{};

    json.forEach((key, value) {
      if (!knownKeys.contains(key)) {
        unparsed[key] = value;
      }
    });

    String resolvedId = '';
    if (json['id'] is String) {
      resolvedId = json['id'] as String;
    } else if (json['id'] is Map && (json['id'] as Map)['slug'] is String) {
      resolvedId = (json['id'] as Map)['slug'] as String;
    }

    final resolvedName = json['name'] is String ? json['name'] as String : 'Unknown Adventurer';
    final resolvedLevel = (json['level'] is num ? (json['level'] as num).toInt() : 1).clamp(1, 20);
    final resolvedStrength = (json['strength'] is num ? (json['strength'] as num).toInt() : 10).clamp(1, 30);

    return CharacterDto(
      id: resolvedId,
      name: resolvedName,
      level: resolvedLevel,
      strength: resolvedStrength,
      unparsedPayload: unparsed,
      rawMap: Map<String, dynamic>.from(json),
    );
  }

  /// Deserializes a raw Map payload into [CharacterDto].
  factory CharacterDto.fromMap(Map<String, dynamic> map) {
    return CharacterDto.fromJson(map);
  }

  /// Deserializes from a JSON string.
  factory CharacterDto.fromJsonString(String jsonStr) {
    return CharacterDto.fromJson(Map<String, dynamic>.from(json.decode(jsonStr) as Map));
  }

  /// Factory creating a DTO from a domain [Character].
  factory CharacterDto.fromDomain(Character character) {
    final map = character.toMap();
    return CharacterDto(
      id: character.id.slug,
      name: character.name,
      level: character.totalLevel,
      strength: character.baseScores.strength,
      unparsedPayload: const {},
      rawMap: map,
    );
  }

  /// Converts this DTO into a domain [Character] entity.
  Character toDomain() {
    if (_rawMap.isNotEmpty && _rawMap.containsKey('progression')) {
      return Character.fromMap(_rawMap);
    }
    return Character.fromMap(toJson());
  }

  /// Serializes to a Map for database storage or network transmission.
  Map<String, dynamic> toMap() {
    if (_rawMap.isNotEmpty && _rawMap.containsKey('progression')) {
      return _rawMap;
    }
    return toJson();
  }

  /// Serializes to JSON map representation with unparsed homebrew fields preserved.
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'level': level,
      'strength': strength,
    };
    data.addAll(unparsedPayload);
    return data;
  }

  /// Serializes to JSON string.
  String toJsonString() => json.encode(toMap());

  CharacterDto copyWith({
    String? id,
    String? name,
    int? level,
    int? strength,
    Map<String, dynamic>? unparsedPayload,
    Map<String, dynamic>? rawMap,
  }) {
    return CharacterDto(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      strength: strength ?? this.strength,
      unparsedPayload: unparsedPayload ?? this.unparsedPayload,
      rawMap: rawMap ?? _rawMap,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          level == other.level &&
          strength == other.strength;

  @override
  int get hashCode => Object.hash(id, name, level, strength);
}
