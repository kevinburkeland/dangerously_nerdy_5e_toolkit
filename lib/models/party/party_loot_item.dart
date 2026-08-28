import 'dart:convert';

/// Represents a single loot item, gem, art piece, or magic item in the shared party vault.
class PartyLootItem {
  final String id;
  final String name;
  final String category; // 'currency', 'gem', 'art', 'magicItem', 'gear'
  final int count;
  final double gpValue;
  final String? description;
  final String? claimedByPlayer;
  final bool isIdentified;
  final bool requiresAttunement;
  final bool isAttuned;
  final bool isArchived;
  final String? archivedBy;
  final DateTime? archivedAt;
  final bool hasConflict;
  final Map<String, dynamic>? conflictPayload;
  final String? sourceTableOrMonster;
  final DateTime createdAt;
  final DateTime expiresAt;

  const PartyLootItem({
    required this.id,
    required this.name,
    this.category = 'gear',
    this.count = 1,
    this.gpValue = 0.0,
    this.description,
    this.claimedByPlayer,
    this.isIdentified = true,
    this.requiresAttunement = false,
    this.isAttuned = false,
    this.isArchived = false,
    this.archivedBy,
    this.archivedAt,
    this.hasConflict = false,
    this.conflictPayload,
    this.sourceTableOrMonster,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isClaimed => claimedByPlayer != null && claimedByPlayer!.trim().isNotEmpty;
  double get totalGpValue => gpValue * count;

  String get categoryLabel {
    switch (category) {
      case 'magicItem':
        return 'Magic Item';
      case 'gem':
        return 'Gemstone';
      case 'art':
        return 'Art Object';
      case 'currency':
        return 'Currency / Ingot';
      default:
        return 'Adventuring Gear';
    }
  }

  PartyLootItem copyWith({
    String? id,
    String? name,
    String? category,
    int? count,
    double? gpValue,
    String? description,
    String? claimedByPlayer,
    bool clearClaimedByPlayer = false,
    bool? isIdentified,
    bool? requiresAttunement,
    bool? isAttuned,
    bool? isArchived,
    String? archivedBy,
    DateTime? archivedAt,
    bool? hasConflict,
    Map<String, dynamic>? conflictPayload,
    bool clearConflict = false,
    String? sourceTableOrMonster,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return PartyLootItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      count: count ?? this.count,
      gpValue: gpValue ?? this.gpValue,
      description: description ?? this.description,
      claimedByPlayer: clearClaimedByPlayer ? null : (claimedByPlayer ?? this.claimedByPlayer),
      isIdentified: isIdentified ?? this.isIdentified,
      requiresAttunement: requiresAttunement ?? this.requiresAttunement,
      isAttuned: isAttuned ?? this.isAttuned,
      isArchived: isArchived ?? this.isArchived,
      archivedBy: archivedBy ?? this.archivedBy,
      archivedAt: archivedAt ?? this.archivedAt,
      hasConflict: clearConflict ? false : (hasConflict ?? this.hasConflict),
      conflictPayload: clearConflict ? null : (conflictPayload ?? this.conflictPayload),
      sourceTableOrMonster: sourceTableOrMonster ?? this.sourceTableOrMonster,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'count': count,
      'gpValue': gpValue,
      'description': description,
      'claimedByPlayer': claimedByPlayer,
      'isIdentified': isIdentified,
      'requiresAttunement': requiresAttunement,
      'isAttuned': isAttuned,
      'isArchived': isArchived,
      'archivedBy': archivedBy,
      'archivedAt': archivedAt?.toIso8601String(),
      'hasConflict': hasConflict,
      'conflictPayload': conflictPayload,
      'sourceTableOrMonster': sourceTableOrMonster,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory PartyLootItem.fromMap(Map<String, dynamic> map) {
    return PartyLootItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Item',
      category: map['category'] as String? ?? 'gear',
      count: (map['count'] as num?)?.toInt() ?? 1,
      gpValue: (map['gpValue'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      claimedByPlayer: map['claimedByPlayer'] as String?,
      isIdentified: map['isIdentified'] as bool? ?? true,
      requiresAttunement: map['requiresAttunement'] as bool? ?? false,
      isAttuned: map['isAttuned'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      archivedBy: map['archivedBy'] as String?,
      archivedAt: map['archivedAt'] != null ? DateTime.tryParse(map['archivedAt'] as String) : null,
      hasConflict: map['hasConflict'] as bool? ?? false,
      conflictPayload: map['conflictPayload'] is Map<String, dynamic>
          ? map['conflictPayload'] as Map<String, dynamic>
          : (map['conflictPayload'] is Map
              ? Map<String, dynamic>.from(map['conflictPayload'] as Map)
              : null),
      sourceTableOrMonster: map['sourceTableOrMonster'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'] as String) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PartyLootItem.fromJson(String source) => PartyLootItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
