import '../srd_summons/srd_summons_library.dart';

class MonsterSourceEntry {
  final SummonPreset preset;
  final MinionStatBlock statBlock;

  const MonsterSourceEntry({
    required this.preset,
    required this.statBlock,
  });
}

class SrdMonsterLists {
  SrdMonsterLists._();

  /// SRD creatures sourced from summon spells and spell-like companion presets.
  static const List<MonsterSourceEntry> spellSummonEntries = [
    // Animate Objects
    MonsterSourceEntry(
      preset: AnimateObjectsSummon.preset,
      statBlock: AnimateObjectsSummon.tinyObject,
    ),
    MonsterSourceEntry(
      preset: AnimateObjectsSummon.preset,
      statBlock: AnimateObjectsSummon.smallObject,
    ),
    MonsterSourceEntry(
      preset: AnimateObjectsSummon.preset,
      statBlock: AnimateObjectsSummon.mediumObject,
    ),
    MonsterSourceEntry(
      preset: AnimateObjectsSummon.preset,
      statBlock: AnimateObjectsSummon.largeObject,
    ),
    MonsterSourceEntry(
      preset: AnimateObjectsSummon.preset,
      statBlock: AnimateObjectsSummon.hugeObject,
    ),

    // Conjure Animals
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.wolf,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.boar,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.panther,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantBadger,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantPoisonousSnake,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.ape,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.blackBear,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.crocodile,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.direWolf,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantHyena,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantSpider,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantEagle,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.brownBear,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.lion,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.tiger,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantToad,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.rhinoceros,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.polarBear,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantBoar,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.saberToothedTiger,
    ),
    MonsterSourceEntry(
      preset: BeastSummons.conjureAnimalsPreset,
      statBlock: BeastSummons.giantConstrictorSnake,
    ),

    // Animate Dead
    MonsterSourceEntry(
      preset: UndeadSummons.animateDeadPreset,
      statBlock: UndeadSummons.skeleton,
    ),
    MonsterSourceEntry(
      preset: UndeadSummons.animateDeadPreset,
      statBlock: UndeadSummons.zombie,
    ),

    // Create Undead
    MonsterSourceEntry(
      preset: UndeadSummons.createUndeadPreset,
      statBlock: UndeadSummons.ghoul,
    ),
    MonsterSourceEntry(
      preset: UndeadSummons.createUndeadPreset,
      statBlock: UndeadSummons.ghast,
    ),
    MonsterSourceEntry(
      preset: UndeadSummons.createUndeadPreset,
      statBlock: UndeadSummons.wight,
    ),
    MonsterSourceEntry(
      preset: UndeadSummons.createUndeadPreset,
      statBlock: UndeadSummons.mummy,
    ),

    // Conjure Elemental
    MonsterSourceEntry(
      preset: ElementalSummons.conjureElementalPreset,
      statBlock: ElementalSummons.airElemental,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureElementalPreset,
      statBlock: ElementalSummons.earthElemental,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureElementalPreset,
      statBlock: ElementalSummons.fireElemental,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureElementalPreset,
      statBlock: ElementalSummons.waterElemental,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureElementalPreset,
      statBlock: ElementalSummons.salamander,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureElementalPreset,
      statBlock: ElementalSummons.xorn,
    ),

    // Conjure Minor Elementals
    MonsterSourceEntry(
      preset: ElementalSummons.conjureMinorElementalsPreset,
      statBlock: ElementalSummons.gargoyle,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureMinorElementalsPreset,
      statBlock: ElementalSummons.fireSnake,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureMinorElementalsPreset,
      statBlock: ElementalSummons.dustMephit,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureMinorElementalsPreset,
      statBlock: ElementalSummons.iceMephit,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureMinorElementalsPreset,
      statBlock: ElementalSummons.magmaMephit,
    ),
    MonsterSourceEntry(
      preset: ElementalSummons.conjureMinorElementalsPreset,
      statBlock: ElementalSummons.steamMephit,
    ),

    // Giant Insect
    MonsterSourceEntry(
      preset: InsectSummons.giantInsectPreset,
      statBlock: InsectSummons.giantCentipede,
    ),
    MonsterSourceEntry(
      preset: InsectSummons.giantInsectPreset,
      statBlock: InsectSummons.giantWasp,
    ),
    MonsterSourceEntry(
      preset: InsectSummons.giantInsectPreset,
      statBlock: BeastSummons.giantSpider,
    ),
    MonsterSourceEntry(
      preset: InsectSummons.giantInsectPreset,
      statBlock: InsectSummons.giantScorpion,
    ),
  ];

  /// SRD creatures sourced from magic item summon tables and figurines.
  static const List<MonsterSourceEntry> magicItemEntries = [
    // Bag of Tricks (Gray)
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BagOfTricksSummons.weasel,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BagOfTricksSummons.giantRat,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BagOfTricksSummons.badger,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BeastSummons.boar,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BeastSummons.panther,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BeastSummons.giantBadger,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BeastSummons.direWolf,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.grayBagPreset,
      statBlock: BagOfTricksSummons.giantElk,
    ),

    // Bag of Tricks (Rust)
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BagOfTricksSummons.rat,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BagOfTricksSummons.owl,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BagOfTricksSummons.mastiff,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BagOfTricksSummons.goat,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BagOfTricksSummons.giantGoat,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BeastSummons.giantBoar,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BeastSummons.lion,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.rustBagPreset,
      statBlock: BeastSummons.brownBear,
    ),

    // Bag of Tricks (Tan)
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BagOfTricksSummons.jackal,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BeastSummons.ape,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BagOfTricksSummons.baboon,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BagOfTricksSummons.axeBeak,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BeastSummons.blackBear,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BagOfTricksSummons.giantWeasel,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BeastSummons.giantHyena,
    ),
    MonsterSourceEntry(
      preset: BagOfTricksSummons.tanBagPreset,
      statBlock: BeastSummons.tiger,
    ),

    // Horn of Valhalla
    MonsterSourceEntry(
      preset: ValhallaSummons.hornOfValhallaPreset,
      statBlock: ValhallaSummons.berserker,
    ),

    // Figurines of Wondrous Power
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.bronzeGriffon,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.ebonyFly,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.goldenLion,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.ivoryGoatTraveling,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.ivoryGoatTravail,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.ivoryGoatTerror,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.marbleElephant,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.obsidianSteed,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.onyxDog,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.serpentineOwl,
    ),
    MonsterSourceEntry(
      preset: FigurinesSummons.figurinesPreset,
      statBlock: FigurinesSummons.silverRaven,
    ),
  ];

  static const List<MonsterSourceEntry> allSourceEntries = [
    ...spellSummonEntries,
    ...magicItemEntries,
  ];
}
