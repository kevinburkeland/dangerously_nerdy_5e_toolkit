import 'dart:ui';
import 'srd_summons.dart';

/// Represents standard 5e animated object size classifications and combat metrics.
enum ObjectSize {
  tiny(
    displayName: 'Tiny',
    pointCost: 1,
    maxHp: 20,
    ac: 18,
    attackBonus: 8,
    damageDiceCount: 1,
    damageDiceSides: 4,
    damageBonus: 4,
    strScore: 4,
    dexScore: 18,
    accentColor: Color(0xFF4CAF50), // Green
    defaultExample: 'Silver Coin / Needle',
  ),
  small(
    displayName: 'Small',
    pointCost: 1,
    maxHp: 25,
    ac: 16,
    attackBonus: 6,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 2,
    strScore: 6,
    dexScore: 14,
    accentColor: Color(0xFF03A9F4), // Light Blue
    defaultExample: 'Dagger / Chair',
  ),
  medium(
    displayName: 'Medium',
    pointCost: 2,
    maxHp: 40,
    ac: 13,
    attackBonus: 5,
    damageDiceCount: 2,
    damageDiceSides: 6,
    damageBonus: 1,
    strScore: 10,
    dexScore: 12,
    accentColor: Color(0xFFFF9800), // Amber
    defaultExample: 'Sword / Table',
  ),
  large(
    displayName: 'Large',
    pointCost: 4,
    maxHp: 50,
    ac: 10,
    attackBonus: 6,
    damageDiceCount: 2,
    damageDiceSides: 10,
    damageBonus: 2,
    strScore: 14,
    dexScore: 10,
    accentColor: Color(0xFFE91E63), // Pink/Red
    defaultExample: 'Cart / Statue',
  ),
  huge(
    displayName: 'Huge',
    pointCost: 8,
    maxHp: 80,
    ac: 10,
    attackBonus: 8,
    damageDiceCount: 2,
    damageDiceSides: 12,
    damageBonus: 4,
    strScore: 18,
    dexScore: 6,
    accentColor: Color(0xFF9C27B0), // Purple
    defaultExample: 'Bouldering Pillar / Wagon',
  );

  final String displayName;
  final int pointCost;
  final int maxHp;
  final int ac;
  final int attackBonus;
  final int damageDiceCount;
  final int damageDiceSides;
  final int damageBonus;
  final int strScore;
  final int dexScore;
  final Color accentColor;
  final String defaultExample;

  const ObjectSize({
    required this.displayName,
    required this.pointCost,
    required this.maxHp,
    required this.ac,
    required this.attackBonus,
    required this.damageDiceCount,
    required this.damageDiceSides,
    required this.damageBonus,
    required this.strScore,
    required this.dexScore,
    required this.accentColor,
    required this.defaultExample,
  });

  int get armorClass => ac;

  String get damageFormula =>
      '${damageDiceCount}d$damageDiceSides${damageBonus > 0 ? "+$damageBonus" : damageBonus < 0 ? "$damageBonus" : ""}';

  /// Safe parser mapping raw string inputs to [ObjectSize] with fallback.
  static ObjectSize fromString(String rawSize) {
    final normalized = rawSize.trim().toLowerCase();
    for (final size in ObjectSize.values) {
      if (normalized.contains(size.name)) {
        return size;
      }
    }
    return ObjectSize.medium;
  }
}

/// Represents an individual active summon or animated object instance.
class AnimatedObjectInstance {
  final String id;
  String name;
  final ObjectSize size;
  int _currentHp;
  final int maxHp;
  int _tempHp;
  String damageType; // Bludgeoning, Piercing, Slashing, Fire, etc.
  bool isSilvered;

  // Optional custom stat block overrides for generic minion summons
  final int? customAc;
  final int? customAttackBonus;
  final int? customDamageDiceCount;
  final int? customDamageDiceSides;
  final int? customDamageBonus;
  final int secondaryDamageDiceCount;
  final int secondaryDamageDiceSides;
  final String? secondaryDamageType;
  final bool hasPackTactics;
  final String? specialTrait;
  final String? statBlockId;
  final MinionStatBlock? originalStatBlock;
  final Color? customAccentColor;

  AnimatedObjectInstance({
    required this.id,
    required this.name,
    required this.size,
    required int currentHp,
    required int maxHp,
    int tempHp = 0,
    this.damageType = 'Bludgeoning',
    this.isSilvered = false,
    this.statBlockId,
    this.originalStatBlock,
    this.customAc,
    this.customAttackBonus,
    this.customDamageDiceCount,
    this.customDamageDiceSides,
    this.customDamageBonus,
    this.secondaryDamageDiceCount = 0,
    this.secondaryDamageDiceSides = 0,
    this.secondaryDamageType,
    this.hasPackTactics = false,
    this.specialTrait,
    this.customAccentColor,
  })  : maxHp = maxHp < 1 ? 1 : maxHp,
        _currentHp = currentHp.clamp(0, maxHp < 1 ? 1 : maxHp),
        _tempHp = tempHp < 0 ? 0 : tempHp;

  int get currentHp => _currentHp;
  set currentHp(int value) {
    _currentHp = value.clamp(0, maxHp);
  }

  int get tempHp => _tempHp;
  set tempHp(int value) {
    _tempHp = value < 0 ? 0 : value;
  }

  /// Resolves the full 5e SRD MinionStatBlock for this creature instance.
  MinionStatBlock get statBlock {
    if (originalStatBlock != null) return originalStatBlock!;
    if (statBlockId != null) {
      final found = SrdSummonsLibrary.findStatBlockById(statBlockId!);
      if (found != null) return found;
    }
    final byName = SrdSummonsLibrary.findStatBlockByName(name);
    if (byName != null) return byName;

    // Fallback to synthetic Animate Object stat block matching size
    switch (size) {
      case ObjectSize.tiny:
        return SrdSummonsLibrary.tinyObject;
      case ObjectSize.small:
        return SrdSummonsLibrary.smallObject;
      case ObjectSize.medium:
        return SrdSummonsLibrary.mediumObject;
      case ObjectSize.large:
        return SrdSummonsLibrary.largeObject;
      case ObjectSize.huge:
        return SrdSummonsLibrary.hugeObject;
    }
  }

  /// Factory constructor to generate an instance from an SRD MinionStatBlock.
  factory AnimatedObjectInstance.fromStatBlock(
    MinionStatBlock statBlock, {
    required String id,
    String? customName,
    int tempHp = 0,
  }) {
    return AnimatedObjectInstance(
      id: id,
      name: customName ?? statBlock.name,
      size: ObjectSize.fromString(statBlock.sizeDisplay),
      currentHp: statBlock.maxHp,
      maxHp: statBlock.maxHp,
      tempHp: tempHp,
      damageType: statBlock.damageType,
      statBlockId: statBlock.id,
      originalStatBlock: statBlock,
      customAc: statBlock.ac,
      customAttackBonus: statBlock.attackBonus,
      customDamageDiceCount: statBlock.damageDiceCount,
      customDamageDiceSides: statBlock.damageDiceSides,
      customDamageBonus: statBlock.damageBonus,
      secondaryDamageDiceCount: statBlock.secondaryDamageDiceCount,
      secondaryDamageDiceSides: statBlock.secondaryDamageDiceSides,
      secondaryDamageType: statBlock.secondaryDamageType,
      hasPackTactics: statBlock.hasPackTactics,
      specialTrait: statBlock.specialTrait,
      customAccentColor: statBlock.accentColor,
    );
  }

  // Effective Stat Getters
  int get ac => customAc ?? size.ac;
  int get attackBonus => customAttackBonus ?? size.attackBonus;
  int get damageDiceCount => customDamageDiceCount ?? size.damageDiceCount;
  int get damageDiceSides => customDamageDiceSides ?? size.damageDiceSides;
  int get damageBonus => customDamageBonus ?? size.damageBonus;
  Color get accentColor => customAccentColor ?? size.accentColor;

  /// Formatted damage formula string (e.g., "1d4+4 Bludgeoning").
  String get damageFormula {
    final bonusStr = damageBonus > 0
        ? '+$damageBonus'
        : damageBonus < 0
            ? '$damageBonus'
            : '';
    final base = '${damageDiceCount}d$damageDiceSides$bonusStr';
    if (secondaryDamageDiceCount > 0 && secondaryDamageType != null && secondaryDamageType!.isNotEmpty) {
      return '$base $damageType + ${secondaryDamageDiceCount}d$secondaryDamageDiceSides $secondaryDamageType';
    }
    return '$base $damageType';
  }

  bool get isDead => _currentHp <= 0;

  /// Safe calculation of remaining HP percentage, strictly protected against NaN / division-by-zero.
  double get hpPercent => maxHp <= 0 ? 0.0 : (_currentHp / maxHp).clamp(0.0, 1.0);

  /// Mutating damage application with Temporary HP absorption (5e RAW).
  void takeDamage(int amount) {
    if (amount <= 0) return;
    int remaining = amount;
    if (_tempHp > 0) {
      if (remaining <= _tempHp) {
        _tempHp -= remaining;
        return;
      } else {
        remaining -= _tempHp;
        _tempHp = 0;
      }
    }
    _currentHp = (_currentHp - remaining).clamp(0, maxHp);
  }

  /// Mutating healing application clamped to [0, maxHp] (does not affect Temp HP).
  void heal(int amount) {
    if (amount <= 0) return;
    _currentHp = (_currentHp + amount).clamp(0, maxHp);
  }

  /// Sets Temporary HP (non-stacking, overrides if positive).
  void grantTempHp(int amount) {
    _tempHp = amount < 0 ? 0 : amount;
  }

  /// Pure state mutation returning a new instance with updated HP (with Temp HP absorption).
  AnimatedObjectInstance applyDamage(int amount) {
    if (amount <= 0) return this;
    int updatedTemp = _tempHp;
    int remaining = amount;
    if (updatedTemp > 0) {
      if (remaining <= updatedTemp) {
        updatedTemp -= remaining;
        return copyWith(tempHp: updatedTemp);
      } else {
        remaining -= updatedTemp;
        updatedTemp = 0;
      }
    }
    final updatedHp = (_currentHp - remaining).clamp(0, maxHp);
    return copyWith(currentHp: updatedHp, tempHp: updatedTemp);
  }

  /// Pure state mutation returning a new instance with replenished HP.
  AnimatedObjectInstance applyHealing(int amount) {
    if (amount <= 0) return this;
    final updated = (_currentHp + amount).clamp(0, maxHp);
    return copyWith(currentHp: updated);
  }

  AnimatedObjectInstance copyWith({
    String? id,
    String? name,
    ObjectSize? size,
    int? currentHp,
    int? maxHp,
    int? tempHp,
    String? damageType,
    bool? isSilvered,
    int? customAc,
    int? customAttackBonus,
    int? customDamageDiceCount,
    int? customDamageDiceSides,
    int? customDamageBonus,
    int? secondaryDamageDiceCount,
    int? secondaryDamageDiceSides,
    String? secondaryDamageType,
    bool? hasPackTactics,
    String? specialTrait,
    Color? customAccentColor,
  }) {
    return AnimatedObjectInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      currentHp: currentHp ?? _currentHp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? _tempHp,
      damageType: damageType ?? this.damageType,
      isSilvered: isSilvered ?? this.isSilvered,
      customAc: customAc ?? this.customAc,
      customAttackBonus: customAttackBonus ?? this.customAttackBonus,
      customDamageDiceCount: customDamageDiceCount ?? this.customDamageDiceCount,
      customDamageDiceSides: customDamageDiceSides ?? this.customDamageDiceSides,
      customDamageBonus: customDamageBonus ?? this.customDamageBonus,
      secondaryDamageDiceCount: secondaryDamageDiceCount ?? this.secondaryDamageDiceCount,
      secondaryDamageDiceSides: secondaryDamageDiceSides ?? this.secondaryDamageDiceSides,
      secondaryDamageType: secondaryDamageType ?? this.secondaryDamageType,
      hasPackTactics: hasPackTactics ?? this.hasPackTactics,
      specialTrait: specialTrait ?? this.specialTrait,
      customAccentColor: customAccentColor ?? this.customAccentColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'size': size.name,
      'currentHp': _currentHp,
      'maxHp': maxHp,
      'tempHp': _tempHp,
      'damageType': damageType,
      'isSilvered': isSilvered,
      'customAc': customAc,
      'customAttackBonus': customAttackBonus,
      'customDamageDiceCount': customDamageDiceCount,
      'customDamageDiceSides': customDamageDiceSides,
      'customDamageBonus': customDamageBonus,
      'secondaryDamageDiceCount': secondaryDamageDiceCount,
      'secondaryDamageDiceSides': secondaryDamageDiceSides,
      'secondaryDamageType': secondaryDamageType,
      'hasPackTactics': hasPackTactics,
      'specialTrait': specialTrait,
      'customAccentColor': customAccentColor?.toARGB32(),
    };
  }

  factory AnimatedObjectInstance.fromMap(Map<String, dynamic> map) {
    return AnimatedObjectInstance(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Summon',
      size: ObjectSize.fromString(map['size'] as String? ?? 'medium'),
      currentHp: map['currentHp'] as int? ?? 10,
      maxHp: map['maxHp'] as int? ?? 10,
      tempHp: map['tempHp'] as int? ?? 0,
      damageType: map['damageType'] as String? ?? 'Bludgeoning',
      isSilvered: map['isSilvered'] as bool? ?? false,
      customAc: map['customAc'] as int?,
      customAttackBonus: map['customAttackBonus'] as int?,
      customDamageDiceCount: map['customDamageDiceCount'] as int?,
      customDamageDiceSides: map['customDamageDiceSides'] as int?,
      customDamageBonus: map['customDamageBonus'] as int?,
      secondaryDamageDiceCount: map['secondaryDamageDiceCount'] as int? ?? 0,
      secondaryDamageDiceSides: map['secondaryDamageDiceSides'] as int? ?? 0,
      secondaryDamageType: map['secondaryDamageType'] as String?,
      hasPackTactics: map['hasPackTactics'] as bool? ?? false,
      specialTrait: map['specialTrait'] as String?,
      customAccentColor: map['customAccentColor'] != null
          ? Color(map['customAccentColor'] as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimatedObjectInstance &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          size == other.size &&
          _currentHp == other._currentHp &&
          maxHp == other.maxHp &&
          _tempHp == other._tempHp &&
          damageType == other.damageType &&
          isSilvered == other.isSilvered &&
          customAc == other.customAc &&
          customAttackBonus == other.customAttackBonus &&
          customDamageDiceCount == other.customDamageDiceCount &&
          customDamageDiceSides == other.customDamageDiceSides &&
          customDamageBonus == other.customDamageBonus &&
          secondaryDamageDiceCount == other.secondaryDamageDiceCount &&
          secondaryDamageDiceSides == other.secondaryDamageDiceSides &&
          secondaryDamageType == other.secondaryDamageType &&
          hasPackTactics == other.hasPackTactics &&
          specialTrait == other.specialTrait &&
          customAccentColor == other.customAccentColor;

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        size,
        _currentHp,
        maxHp,
        _tempHp,
        damageType,
        isSilvered,
        customAc,
        customAttackBonus,
        customDamageDiceCount,
        customDamageDiceSides,
        customDamageBonus,
        secondaryDamageDiceCount,
        secondaryDamageDiceSides,
        secondaryDamageType,
        hasPackTactics,
        specialTrait,
        customAccentColor,
      ]);

  @override
  String toString() =>
      'AnimatedObjectInstance(id: $id, name: $name, size: ${size.displayName}, HP: $_currentHp/$maxHp, AC: $ac)';
}
