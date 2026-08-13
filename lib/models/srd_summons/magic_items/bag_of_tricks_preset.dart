import '../minion_stat_block.dart';
import '../summon_preset.dart';
import '../spells/beast_presets.dart';

class BagOfTricksSummons {
  static const bagOfTricksPreset = SummonPreset(
    id: 'bag_of_tricks',
    name: 'Bag of Tricks (Gray/Rust/Tan)',
    category: SummonCategory.magicItem,
    levelDisplay: 'Wondrous Item (Uncommon)',
    castingTime: '1 Action',
    range: '20 feet',
    components: 'Action (Pull fuzzy object and throw)',
    duration: 'Until killed or next dawn',
    description: 'Pull a random fuzzy object from the bag and throw it up to 20 feet. Roll a d8 on the bag table to determine which animal appears! Up to 3 creatures per day.',
    upcastRules: '3 uses per day per bag.',
    statBlocks: [
      BeastSummons.wolf,
      BeastSummons.boar,
      BeastSummons.giantHyena,
      BeastSummons.ape,
      BeastSummons.direWolf,
      BeastSummons.giantSpider,
    ],
    isRandomTable: true,
  );
}
