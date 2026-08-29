import '../monster_codex_data.dart';
import 'minion_stat_block.dart';
import 'summon_preset.dart';
import 'spells/animate_objects_preset.dart';
import 'spells/undead_presets.dart';
import 'spells/beast_presets.dart';
import 'spells/elemental_presets.dart';
import 'spells/insect_preset.dart';
import 'magic_items/valhalla_preset.dart';
import 'magic_items/bag_of_tricks_preset.dart';
import 'magic_items/figurines_preset.dart';

export 'minion_stat_block.dart';
export 'summon_preset.dart';
export 'spells/animate_objects_preset.dart';
export 'spells/undead_presets.dart';
export 'spells/beast_presets.dart';
export 'spells/elemental_presets.dart';
export 'spells/insect_preset.dart';
export 'magic_items/valhalla_preset.dart';
export 'magic_items/bag_of_tricks_preset.dart';
export 'magic_items/figurines_preset.dart';

class SrdSummonsLibrary {
  // Stat block backward compatibility getters
  static const tinyObject = AnimateObjectsSummon.tinyObject;
  static const smallObject = AnimateObjectsSummon.smallObject;
  static const mediumObject = AnimateObjectsSummon.mediumObject;
  static const largeObject = AnimateObjectsSummon.largeObject;
  static const hugeObject = AnimateObjectsSummon.hugeObject;

  static const skeleton = UndeadSummons.skeleton;
  static const zombie = UndeadSummons.zombie;
  static const ghoul = UndeadSummons.ghoul;
  static const ghast = UndeadSummons.ghast;
  static const wight = UndeadSummons.wight;
  static const mummy = UndeadSummons.mummy;

  static const wolf = BeastSummons.wolf;
  static const direWolf = BeastSummons.direWolf;
  static const giantHyena = BeastSummons.giantHyena;
  static const giantSpider = BeastSummons.giantSpider;
  static const giantEagle = BeastSummons.giantEagle;
  static const ape = BeastSummons.ape;
  static const boar = BeastSummons.boar;

  static const airElemental = ElementalSummons.airElemental;
  static const earthElemental = ElementalSummons.earthElemental;
  static const fireElemental = ElementalSummons.fireElemental;
  static const waterElemental = ElementalSummons.waterElemental;
  static const salamander = ElementalSummons.salamander;
  static const xorn = ElementalSummons.xorn;
  static const fireSnake = ElementalSummons.fireSnake;
  static const dustMephit = ElementalSummons.dustMephit;
  static const iceMephit = ElementalSummons.iceMephit;
  static const magmaMephit = ElementalSummons.magmaMephit;
  static const steamMephit = ElementalSummons.steamMephit;
  static const gargoyle = ElementalSummons.gargoyle;

  static const giantCentipede = InsectSummons.giantCentipede;
  static const giantWasp = InsectSummons.giantWasp;
  static const giantScorpion = InsectSummons.giantScorpion;

  static const rhinoceros = BeastSummons.rhinoceros;
  static const polarBear = BeastSummons.polarBear;
  static const giantBoar = BeastSummons.giantBoar;
  static const saberToothedTiger = BeastSummons.saberToothedTiger;
  static const giantConstrictorSnake = BeastSummons.giantConstrictorSnake;
  static const brownBear = BeastSummons.brownBear;
  static const lion = BeastSummons.lion;
  static const tiger = BeastSummons.tiger;
  static const giantToad = BeastSummons.giantToad;
  static const blackBear = BeastSummons.blackBear;
  static const crocodile = BeastSummons.crocodile;
  static const giantPoisonousSnake = BeastSummons.giantPoisonousSnake;

  static const berserker = ValhallaSummons.berserker;
  static const bronzeGriffon = FigurinesSummons.bronzeGriffon;
  static const ebonyFly = FigurinesSummons.ebonyFly;
  static const goldenLion = FigurinesSummons.goldenLion;
  static const ivoryGoatTraveling = FigurinesSummons.ivoryGoatTraveling;
  static const ivoryGoatTravail = FigurinesSummons.ivoryGoatTravail;
  static const ivoryGoatTerror = FigurinesSummons.ivoryGoatTerror;
  static const marbleElephant = FigurinesSummons.marbleElephant;
  static const obsidianSteed = FigurinesSummons.obsidianSteed;
  static const onyxDog = FigurinesSummons.onyxDog;
  static const serpentineOwl = FigurinesSummons.serpentineOwl;
  static const silverRaven = FigurinesSummons.silverRaven;

  static SummonPreset get homebrewPreset => SummonPreset(
        id: 'homebrew_minions',
        name: 'Homebrew Creatures',
        category: SummonCategory.spell,
        levelDisplay: 'Custom Compendium',
        castingTime: 'Special',
        range: '60 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 hour',
        description:
            'Summon any custom homebrew creatures created in the Homebrew Studio.',
        upcastRules: 'Adjust point capacity with spell slot level.',
        statBlocks: MonsterCodexLibrary.homebrewMonsters
            .map((m) => m.sourceStatBlock)
            .toList(),
      );

  // Decoupled Spell Presets
  static const _baseSpellPresets = <SummonPreset>[
    AnimateObjectsSummon.preset,
    BeastSummons.conjureAnimalsPreset,
    UndeadSummons.animateDeadPreset,
    UndeadSummons.createUndeadPreset,
    ElementalSummons.conjureElementalPreset,
    ElementalSummons.conjureMinorElementalsPreset,
    InsectSummons.giantInsectPreset,
  ];

  static List<SummonPreset> get spellPresets => [
        ..._baseSpellPresets,
        if (MonsterCodexLibrary.homebrewMonsters.isNotEmpty) homebrewPreset,
      ];

  // Decoupled Magic Item Presets
  static const magicItemPresets = <SummonPreset>[
    BagOfTricksSummons.grayBagPreset,
    BagOfTricksSummons.rustBagPreset,
    BagOfTricksSummons.tanBagPreset,
    ValhallaSummons.silverHornPreset,
    ValhallaSummons.brassHornPreset,
    ValhallaSummons.bronzeHornPreset,
    ValhallaSummons.ironHornPreset,
    FigurinesSummons.figurinesPreset,
  ];

  static List<SummonPreset> get allPresets => [
        ...spellPresets,
        ...magicItemPresets,
      ];

  static MinionStatBlock? findStatBlockById(String id) {
    for (final preset in allPresets) {
      for (final sb in preset.effectiveStatBlocks) {
        if (sb.id == id) return sb;
      }
    }
    for (final m in MonsterCodexLibrary.homebrewMonsters) {
      if (m.id == id || m.sourceStatBlock.id == id) {
        return m.sourceStatBlock;
      }
    }
    return null;
  }

  static MinionStatBlock? findStatBlockByName(String name) {
    final lower = name.trim().toLowerCase();
    for (final preset in allPresets) {
      for (final sb in preset.effectiveStatBlocks) {
        if (sb.name.toLowerCase() == lower) return sb;
      }
    }
    for (final m in MonsterCodexLibrary.homebrewMonsters) {
      if (m.name.toLowerCase() == lower ||
          m.sourceStatBlock.name.toLowerCase() == lower) {
        return m.sourceStatBlock;
      }
    }
    return null;
  }
}
