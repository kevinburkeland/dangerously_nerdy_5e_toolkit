import 'dart:convert';
import 'dpr_models.dart';

extension DprAttackActionSerialization on DprAttackAction {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'attackBonus': attackBonus,
      'diceCount': diceCount,
      'diceSides': diceSides,
      'damageBonus': damageBonus,
      'damageType': damageType,
      'secondaryDiceCount': secondaryDiceCount,
      'secondaryDiceSides': secondaryDiceSides,
      'secondaryDamageBonus': secondaryDamageBonus,
      'secondaryDamageType': secondaryDamageType,
      'gwmMode': gwmMode.name,
      'gwfVersion': gwfVersion.name,
      'hasDueling': hasDueling,
      'hasArchery': hasArchery,
      'hasThrownWeapon': hasThrownWeapon,
      'isOffhandWithoutTwf': isOffhandWithoutTwf,
      'hasAgonizingBlast': hasAgonizingBlast,
      'abilityModForAgonizing': abilityModForAgonizing,
      'hasHalflingLuck': hasHalflingLuck,
      'weaponMastery': weaponMastery.name,
      'abilityModForGraze': abilityModForGraze,
      'critThreshold': critThreshold,
      'extraCritDiceCount': extraCritDiceCount,
      'extraCritDiceSides': extraCritDiceSides,
      'attackBuffDiceSides': attackBuffDiceSides,
      'attackBuffFlat': attackBuffFlat,
      'attacksPerRound': attacksPerRound,
      'isBonusActionAttack': isBonusActionAttack,
    };
  }

  static DprAttackAction fromMap(Map<String, dynamic> map) {
    return DprAttackAction(
      id: map['id']?.toString() ?? 'att_${DateTime.now().microsecondsSinceEpoch}',
      name: map['name']?.toString() ?? 'Attack Action',
      attackBonus: (map['attackBonus'] as num?)?.toInt() ?? 5,
      diceCount: (map['diceCount'] as num?)?.toInt() ?? 1,
      diceSides: (map['diceSides'] as num?)?.toInt() ?? 8,
      damageBonus: (map['damageBonus'] as num?)?.toInt() ?? 3,
      damageType: map['damageType']?.toString() ?? 'slashing',
      secondaryDiceCount: (map['secondaryDiceCount'] as num?)?.toInt() ?? 0,
      secondaryDiceSides: (map['secondaryDiceSides'] as num?)?.toInt() ?? 0,
      secondaryDamageBonus: (map['secondaryDamageBonus'] as num?)?.toInt() ?? 0,
      secondaryDamageType: map['secondaryDamageType']?.toString(),
      gwmMode: GwmMode.values.firstWhere(
        (e) => e.name == map['gwmMode'],
        orElse: () => GwmMode.none,
      ),
      gwfVersion: GwfVersion.values.firstWhere(
        (e) => e.name == map['gwfVersion'],
        orElse: () => GwfVersion.none,
      ),
      hasDueling: map['hasDueling'] as bool? ?? false,
      hasArchery: map['hasArchery'] as bool? ?? false,
      hasThrownWeapon: map['hasThrownWeapon'] as bool? ?? false,
      isOffhandWithoutTwf: map['isOffhandWithoutTwf'] as bool? ?? false,
      hasAgonizingBlast: map['hasAgonizingBlast'] as bool? ?? false,
      abilityModForAgonizing: (map['abilityModForAgonizing'] as num?)?.toInt() ?? 0,
      hasHalflingLuck: map['hasHalflingLuck'] as bool? ?? false,
      weaponMastery: WeaponMastery.values.firstWhere(
        (e) => e.name == map['weaponMastery'],
        orElse: () => WeaponMastery.none,
      ),
      abilityModForGraze: (map['abilityModForGraze'] as num?)?.toInt() ?? 0,
      critThreshold: (map['critThreshold'] as num?)?.toInt() ?? 20,
      extraCritDiceCount: (map['extraCritDiceCount'] as num?)?.toInt() ?? 0,
      extraCritDiceSides: (map['extraCritDiceSides'] as num?)?.toInt() ?? 0,
      attackBuffDiceSides: (map['attackBuffDiceSides'] as num?)?.toInt() ?? 0,
      attackBuffFlat: (map['attackBuffFlat'] as num?)?.toInt() ?? 0,
      attacksPerRound: (map['attacksPerRound'] as num?)?.toInt() ?? 1,
      isBonusActionAttack: map['isBonusActionAttack'] as bool? ?? false,
    );
  }
}

extension DprCombatantProfileSerialization on DprCombatantProfile {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': level,
      'abilityScore': abilityScore,
      'proficiencyBonus': proficiencyBonus,
      'defaultAdvantage': defaultAdvantage.name,
      'sneakAttackDiceCount': sneakAttackDiceCount,
      'sneakAttackDiceSides': sneakAttackDiceSides,
      'hasHalflingLuck': hasHalflingLuck,
      'attacks': attacks.map((a) => a.toMap()).toList(),
    };
  }

  static DprCombatantProfile fromMap(Map<String, dynamic> map) {
    final rawAttacks = map['attacks'];
    List<DprAttackAction> parsedAttacks = [];
    if (rawAttacks is List) {
      parsedAttacks = rawAttacks
          .whereType<Map>()
          .map((a) => DprAttackActionSerialization.fromMap(Map<String, dynamic>.from(a)))
          .toList();
    }

    return DprCombatantProfile(
      id: map['id']?.toString() ?? 'custom',
      name: map['name']?.toString() ?? 'Custom Hero',
      description: map['description']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 5,
      abilityScore: (map['abilityScore'] as num?)?.toInt() ?? 18,
      proficiencyBonus: (map['proficiencyBonus'] as num?)?.toInt() ?? 3,
      defaultAdvantage: AdvantageType.values.firstWhere(
        (e) => e.name == map['defaultAdvantage'],
        orElse: () => AdvantageType.normal,
      ),
      sneakAttackDiceCount: (map['sneakAttackDiceCount'] as num?)?.toInt() ?? 0,
      sneakAttackDiceSides: (map['sneakAttackDiceSides'] as num?)?.toInt() ?? 6,
      hasHalflingLuck: map['hasHalflingLuck'] as bool? ?? false,
      attacks: parsedAttacks.isNotEmpty ? parsedAttacks : const [
        DprAttackAction(
          id: 'attack_default',
          name: 'Primary Weapon',
          attackBonus: 5,
          diceCount: 1,
          diceSides: 8,
          damageBonus: 3,
          damageType: 'slashing',
        ),
      ],
    );
  }

  String toJson() => json.encode(toMap());

  static DprCombatantProfile fromJson(String source) =>
      fromMap(json.decode(source) as Map<String, dynamic>);
}
