import 'dart:convert';
import 'package:meta/meta.dart';
import '../../domain/models/animated_object.dart';

/// Data Transfer Object for [AnimatedObjectInstance], encapsulating JSON serialization
/// and validation bounds in the Infrastructure layer.
@immutable
class AnimatedObjectDto {
  final String id;
  final String name;
  final String size;
  final int currentHp;
  final int maxHp;
  final int tempHp;
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
  final String marker;
  final int? customAccentColor;
  final Map<String, dynamic> unparsedPayload;

  const AnimatedObjectDto({
    required this.id,
    required this.name,
    required this.size,
    required this.currentHp,
    required this.maxHp,
    this.tempHp = 0,
    this.damageType = 'Bludgeoning',
    this.isSilvered = false,
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
    this.marker = 'standard',
    this.customAccentColor,
    this.unparsedPayload = const {},
  });

  /// Factory creating a DTO from a pure domain [AnimatedObjectInstance].
  factory AnimatedObjectDto.fromDomain(AnimatedObjectInstance minion) {
    return AnimatedObjectDto(
      id: minion.id,
      name: minion.name,
      size: minion.size.name,
      currentHp: minion.currentHp,
      maxHp: minion.maxHp,
      tempHp: minion.tempHp,
      damageType: minion.damageType,
      isSilvered: minion.isSilvered,
      customAc: minion.customAc,
      customAttackBonus: minion.customAttackBonus,
      customDamageDiceCount: minion.customDamageDiceCount,
      customDamageDiceSides: minion.customDamageDiceSides,
      customDamageBonus: minion.customDamageBonus,
      secondaryDamageDiceCount: minion.secondaryDamageDiceCount,
      secondaryDamageDiceSides: minion.secondaryDamageDiceSides,
      secondaryDamageType: minion.secondaryDamageType,
      hasPackTactics: minion.hasPackTactics,
      specialTrait: minion.specialTrait,
      marker: minion.marker.name,
    );
  }

  /// Converts this DTO into a pure domain [AnimatedObjectInstance].
  AnimatedObjectInstance toDomain() {
    return AnimatedObjectInstance(
      id: id,
      name: name,
      size: ObjectSize.fromString(size),
      currentHp: currentHp,
      maxHp: maxHp,
      tempHp: tempHp,
      damageType: damageType,
      isSilvered: isSilvered,
      customAc: customAc,
      customAttackBonus: customAttackBonus,
      customDamageDiceCount: customDamageDiceCount,
      customDamageDiceSides: customDamageDiceSides,
      customDamageBonus: customDamageBonus,
      secondaryDamageDiceCount: secondaryDamageDiceCount,
      secondaryDamageDiceSides: secondaryDamageDiceSides,
      secondaryDamageType: secondaryDamageType,
      hasPackTactics: hasPackTactics,
      specialTrait: specialTrait,
      marker: MinionMarker.fromString(marker),
    );
  }

  /// Deserializes a raw Map payload into [AnimatedObjectDto] with clamping safety.
  factory AnimatedObjectDto.fromMap(Map<String, dynamic> map) {
    const knownKeys = {
      'id',
      'name',
      'size',
      'currentHp',
      'maxHp',
      'tempHp',
      'damageType',
      'isSilvered',
      'customAc',
      'customAttackBonus',
      'customDamageDiceCount',
      'customDamageDiceSides',
      'customDamageBonus',
      'secondaryDamageDiceCount',
      'secondaryDamageDiceSides',
      'secondaryDamageType',
      'hasPackTactics',
      'specialTrait',
      'marker',
      'customAccentColor',
    };

    final unparsed = <String, dynamic>{};
    map.forEach((key, value) {
      if (!knownKeys.contains(key)) {
        unparsed[key] = value;
      }
    });

    final maxHp = ((map['maxHp'] as num?)?.toInt() ?? 10).clamp(1, 9999);
    final curHp = ((map['currentHp'] as num?)?.toInt() ?? maxHp).clamp(0, maxHp);
    final tempHp = ((map['tempHp'] as num?)?.toInt() ?? 0).clamp(0, 9999);
    final customDCount = (map['customDamageDiceCount'] as num?)?.toInt().clamp(0, 50);
    final customDSides = (map['customDamageDiceSides'] as num?)?.toInt().clamp(0, 100);
    final secDCount = ((map['secondaryDamageDiceCount'] as num?)?.toInt() ?? 0).clamp(0, 50);
    final secDSides = ((map['secondaryDamageDiceSides'] as num?)?.toInt() ?? 0).clamp(0, 100);

    final rawMarker = map['marker']?.toString();
    final legacyColor = (map['customAccentColor'] as num?)?.toInt();
    final markerName = rawMarker ?? (legacyColor != null ? 'alpha' : 'standard');

    return AnimatedObjectDto(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Summon',
      size: map['size']?.toString() ?? 'medium',
      currentHp: curHp,
      maxHp: maxHp,
      tempHp: tempHp,
      damageType: map['damageType']?.toString() ?? 'Bludgeoning',
      isSilvered: map['isSilvered'] as bool? ?? false,
      customAc: (map['customAc'] as num?)?.toInt(),
      customAttackBonus: (map['customAttackBonus'] as num?)?.toInt(),
      customDamageDiceCount: customDCount,
      customDamageDiceSides: customDSides,
      customDamageBonus: (map['customDamageBonus'] as num?)?.toInt(),
      secondaryDamageDiceCount: secDCount,
      secondaryDamageDiceSides: secDSides,
      secondaryDamageType: map['secondaryDamageType']?.toString(),
      hasPackTactics: map['hasPackTactics'] as bool? ?? false,
      specialTrait: map['specialTrait']?.toString(),
      marker: markerName,
      customAccentColor: legacyColor,
      unparsedPayload: unparsed,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'size': size,
      'currentHp': currentHp,
      'maxHp': maxHp,
      'tempHp': tempHp,
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
      'marker': marker,
    };
    if (customAccentColor != null) {
      map['customAccentColor'] = customAccentColor;
    }

    unparsedPayload.forEach((key, value) {
      if (!map.containsKey(key)) {
        map[key] = value;
      }
    });

    return map;
  }

  String toJson() => json.encode(toMap());

  factory AnimatedObjectDto.fromJson(String source) =>
      AnimatedObjectDto.fromMap(Map<String, dynamic>.from(json.decode(source) as Map));
}
