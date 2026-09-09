import '../../utils/dice_formatters.dart';
import '../../models/srd_summons/srd_summons_library.dart';
import 'value_objects/hit_points.dart';

/// Represents standard 5e animated object size classifications and combat metrics.
/// Pure Dart domain model decoupled from Flutter UI dependencies.
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
    required this.defaultExample,
  });

  String get damageFormula => DiceFormatters.formatFormula(
        count: damageDiceCount,
        sides: damageDiceSides,
        bonus: damageBonus,
      );

  static final RegExp _whitespacePattern = RegExp(r'\s+');

  /// Safe parser mapping raw string inputs (e.g., 'Large Beast', 'Tiny') to [ObjectSize] with fallback.
  static ObjectSize fromString(String rawSize) {
    final normalized = rawSize.trim().toLowerCase();
    final tokens = normalized.split(_whitespacePattern);
    for (final size in ObjectSize.values) {
      if (tokens.contains(size.name) ||
          tokens.contains(size.displayName.toLowerCase())) {
        return size;
      }
    }
    return ObjectSize.medium;
  }
}
/// Pure domain representation of minion identity markers for table distinguishing.
/// Decoupled from Flutter UI colors.
enum MinionMarker {
  standard,
  alpha,
  beta,
  gamma,
  delta,
  epsilon;

  static MinionMarker fromString(String? name) {
    if (name == null) return MinionMarker.standard;
    return MinionMarker.values.firstWhere(
      (m) => m.name.toLowerCase() == name.toLowerCase(),
      orElse: () => MinionMarker.standard,
    );
  }
}

class AnimatedObjectInstance {
  final String id;
  String name;
  final ObjectSize size;
  HitPoints hitPoints;
  final String damageType;
  final bool isSilvered;
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
  final MinionMarker marker;

  AnimatedObjectInstance({
    required this.id,
    required this.name,
    required this.size,
    HitPoints? hitPoints,
    int? currentHp,
    int? maxHp,
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
    this.marker = MinionMarker.standard,
  })  : hitPoints = hitPoints ??
            HitPoints(
              currentHp: currentHp ?? (maxHp ?? 10),
              maxHp: maxHp ?? 10,
              tempHp: tempHp,
            );

  int get currentHp => hitPoints.currentHp;
  set currentHp(int value) {
    hitPoints = hitPoints.copyWith(currentHp: value);
  }

  int get maxHp => hitPoints.maxHp;

  int get tempHp => hitPoints.tempHp;
  set tempHp(int value) {
    hitPoints = hitPoints.setTempHp(value);
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
    return switch (size) {
      ObjectSize.tiny => SrdSummonsLibrary.tinyObject,
      ObjectSize.small => SrdSummonsLibrary.smallObject,
      ObjectSize.medium => SrdSummonsLibrary.mediumObject,
      ObjectSize.large => SrdSummonsLibrary.largeObject,
      ObjectSize.huge => SrdSummonsLibrary.hugeObject,
    };
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
    );
  }

  // Effective Stat Getters
  int get ac => customAc ?? size.ac;
  int get attackBonus => customAttackBonus ?? size.attackBonus;
  int get damageDiceCount => customDamageDiceCount ?? size.damageDiceCount;
  int get damageDiceSides => customDamageDiceSides ?? size.damageDiceSides;
  int get damageBonus => customDamageBonus ?? size.damageBonus;

  /// Formatted damage formula string (e.g., "1d4+4 Bludgeoning").
  String get damageFormula => DiceFormatters.formatCompositeFormula(
        primaryCount: damageDiceCount,
        primarySides: damageDiceSides,
        primaryBonus: damageBonus,
        primaryDamageType: damageType,
        secondaryCount: secondaryDamageDiceCount,
        secondarySides: secondaryDamageDiceSides,
        secondaryDamageType: secondaryDamageType,
      );

  bool get isDead => hitPoints.isDead;

  /// Safe calculation of remaining HP percentage, strictly protected against NaN / division-by-zero.
  double get hpPercent => hitPoints.hpPercent;

  /// Mutating damage application with Temporary HP absorption (5e RAW) via HitPoints Value Object.
  void takeDamage(int amount) {
    hitPoints = hitPoints.takeDamage(amount);
  }

  void applyDamage(int damage) => takeDamage(damage);

  /// Mutating healing application capped to Max HP via HitPoints Value Object.
  void heal(int amount) {
    hitPoints = hitPoints.heal(amount);
  }

  void applyHeal(int healAmount) => heal(healAmount);

  /// Mutating Temporary HP application (RAW: non-stacking, highest wins).
  void grantTempHp(int amount) {
    hitPoints = hitPoints.grantTempHp(amount);
  }

  void applyTempHp(int temp) => grantTempHp(temp);

  AnimatedObjectInstance copyWith({
    String? id,
    String? name,
    ObjectSize? size,
    HitPoints? hitPoints,
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
    MinionMarker? marker,
  }) {
    final resolvedHp = hitPoints ??
        (currentHp != null || maxHp != null || tempHp != null
            ? this.hitPoints.copyWith(
                currentHp: currentHp,
                maxHp: maxHp,
                tempHp: tempHp,
              )
            : this.hitPoints);

    return AnimatedObjectInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      hitPoints: resolvedHp,
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
      marker: marker ?? this.marker,
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
          hitPoints == other.hitPoints &&
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
          marker == other.marker;

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        size,
        hitPoints,
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
        marker,
      ]);

  @override
  String toString() =>
      'AnimatedObjectInstance(id: $id, name: $name, size: ${size.displayName}, HP: $currentHp/$maxHp, AC: $ac)';
}
