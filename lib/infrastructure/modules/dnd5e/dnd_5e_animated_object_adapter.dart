import 'package:vtt_engine_core/models/animated_object.dart';

/// Concrete D&D 5e Ruleset Adapter supplying standard Animate Objects baseline metrics.
class Dnd5eAnimatedObjectAdapter {
  const Dnd5eAnimatedObjectAdapter();

  static const Map<ObjectSize, AnimatedObjectStats> baselines = {
    ObjectSize.tiny: AnimatedObjectStats(
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
    ObjectSize.small: AnimatedObjectStats(
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
    ObjectSize.medium: AnimatedObjectStats(
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
    ObjectSize.large: AnimatedObjectStats(
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
    ObjectSize.huge: AnimatedObjectStats(
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
    ),
  };

  static AnimatedObjectStats getStats(ObjectSize size) {
    return baselines[size] ?? baselines[ObjectSize.medium]!;
  }
}
