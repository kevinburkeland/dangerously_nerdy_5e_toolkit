class CharacterDto {
  final String id;
  final String name;
  final int level;
  final int strength;
  final Map<String, dynamic> unparsedPayload;

  const CharacterDto({
    required this.id,
    required this.name,
    required this.level,
    required this.strength,
    this.unparsedPayload = const {},
  });

  factory CharacterDto.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'id', 'name', 'level', 'strength'};
    final unparsed = <String, dynamic>{};

    json.forEach((key, value) {
      if (!knownKeys.contains(key)) {
        unparsed[key] = value;
      }
    });

    return CharacterDto(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] is String ? json['name'] as String : 'Unknown Adventurer',
      level: (json['level'] is num ? (json['level'] as num).toInt() : 1).clamp(1, 20),
      strength: (json['strength'] is num ? (json['strength'] as num).toInt() : 10).clamp(1, 30),
      unparsedPayload: unparsed,
    );
  }

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

  CharacterDto copyWith({
    String? id,
    String? name,
    int? level,
    int? strength,
    Map<String, dynamic>? unparsedPayload,
  }) {
    return CharacterDto(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      strength: strength ?? this.strength,
      unparsedPayload: unparsedPayload ?? this.unparsedPayload,
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
