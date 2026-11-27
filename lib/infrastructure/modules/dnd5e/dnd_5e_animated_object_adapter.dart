import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/spells/animate_objects_preset.dart';

/// Concrete D&D 5e Ruleset Adapter supplying standard Animate Objects baseline metrics.
class Dnd5eAnimatedObjectAdapter {
  const Dnd5eAnimatedObjectAdapter();

  static const Map<ObjectSize, AnimatedObjectStats> baselines = {
    ObjectSize.tiny: AnimatedObjectStats(
      pointCost: 1,
      statBlock: AnimateObjectsSummon.tinyObject,
      defaultExample: 'Silver Coin / Needle',
    ),
    ObjectSize.small: AnimatedObjectStats(
      pointCost: 1,
      statBlock: AnimateObjectsSummon.smallObject,
      defaultExample: 'Dagger / Chair',
    ),
    ObjectSize.medium: AnimatedObjectStats(
      pointCost: 2,
      statBlock: AnimateObjectsSummon.mediumObject,
      defaultExample: 'Sword / Table',
    ),
    ObjectSize.large: AnimatedObjectStats(
      pointCost: 4,
      statBlock: AnimateObjectsSummon.largeObject,
      defaultExample: 'Cart / Statue',
    ),
    ObjectSize.huge: AnimatedObjectStats(
      pointCost: 8,
      statBlock: AnimateObjectsSummon.hugeObject,
      defaultExample: 'Bouldering Pillar / Wagon',
    ),
  };

  static AnimatedObjectStats getStats(ObjectSize size) {
    return baselines[size] ?? baselines[ObjectSize.medium]!;
  }
}
