import 'dm_screen_data.dart';
import 'monster_codex/bestiary/bestiary_cr_0_to_quarter.dart';
import 'monster_codex/bestiary/bestiary_cr_five_to_eight.dart';
import 'monster_codex/bestiary/bestiary_cr_half_to_one.dart';
import 'monster_codex/bestiary/bestiary_cr_nine_plus.dart';
import 'monster_codex/bestiary/bestiary_cr_two_to_four.dart';
import 'monster_codex/srd_monster_cr_bands.dart';
import 'srd_summons/srd_summons_library.dart';

enum MonsterCrBand {
  all('All CR'),
  cr0ToQuarter('CR 0-1/4'),
  crHalfToOne('CR 1/2-1'),
  crTwoToFour('CR 2-4'),
  crFiveToEight('CR 5-8'),
  crNinePlus('CR 9+');

  final String label;
  const MonsterCrBand(this.label);
}

class MonsterItem {
  final String id;
  final String name;
  final String? name2014;
  final String? name2024;
  final MinionStatBlock statBlock2014;
  final MinionStatBlock statBlock2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final String sourcePresetId;
  final String sourcePresetName;
  final String? sourceSpellId;
  final SummonCategory sourceCategory;

  const MonsterItem({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.statBlock2014,
    required this.statBlock2024,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.sourcePresetId = 'srd_bestiary',
    this.sourcePresetName = '5e SRD Bestiary',
    this.sourceSpellId,
    this.sourceCategory = SummonCategory.spell,
  });

  factory MonsterItem.simple({
    required String id,
    required String name,
    String? name2014,
    String? name2024,
    required MinionStatBlock statBlock,
    bool isChangedIn2024 = false,
    String? diffSummary,
    List<String> diffHighlights = const [],
    String sourcePresetId = 'srd_bestiary',
    String sourcePresetName = '5e SRD Bestiary',
    String? sourceSpellId,
    SummonCategory sourceCategory = SummonCategory.spell,
  }) {
    return MonsterItem(
      id: id,
      name: name,
      name2014: name2014,
      name2024: name2024,
      statBlock2014: statBlock,
      statBlock2024: statBlock,
      isChangedIn2024: isChangedIn2024,
      diffSummary: diffSummary,
      diffHighlights: diffHighlights,
      sourcePresetId: sourcePresetId,
      sourcePresetName: sourcePresetName,
      sourceSpellId: sourceSpellId,
      sourceCategory: sourceCategory,
    );
  }

  MinionStatBlock getStatBlock([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return edition == DmRulesEdition.v2014 ? statBlock2014 : statBlock2024;
  }

  String getName([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (edition == DmRulesEdition.v2014 && name2014 != null) return name2014!;
    if (edition == DmRulesEdition.v2024 && name2024 != null) return name2024!;
    return name;
  }

  MinionStatBlock get sourceStatBlock => statBlock2024;

  String get size => sourceStatBlock.sizeDisplay;
  String get type => sourceStatBlock.typeDisplay;
  String get alignment => sourceStatBlock.alignment;
  String get crDisplay => sourceStatBlock.crDisplay;
  double get challengeRating => _parseChallengeRating(sourceStatBlock.crDisplay);
  int get ac => sourceStatBlock.ac;
  int get hp => sourceStatBlock.maxHp;
  String get speed => sourceStatBlock.speed;
  int get strScore => sourceStatBlock.strScore;
  int get dexScore => sourceStatBlock.dexScore;
  int get conScore => sourceStatBlock.conScore;
  int get intScore => sourceStatBlock.intScore;
  int get wisScore => sourceStatBlock.wisScore;
  int get chaScore => sourceStatBlock.chaScore;
  String get senses => sourceStatBlock.senses;
  String get languages => sourceStatBlock.languages;
  String? get savingThrows => sourceStatBlock.savingThrows;
  String? get skills => sourceStatBlock.skills;
  String? get damageVulnerabilities => sourceStatBlock.damageVulnerabilities;
  String? get damageResistances => sourceStatBlock.damageResistances;
  String? get damageImmunities => sourceStatBlock.damageImmunities;
  String? get conditionImmunities => sourceStatBlock.conditionImmunities;
  List<CreatureTrait> get traits => sourceStatBlock.traits;
  List<CreatureAction> get actions => sourceStatBlock.actions;
  List<CreatureAction> get reactions => sourceStatBlock.reactions;
  int? get xp => sourceStatBlock.xp;

  static final Map<String, String> _corpusCache = {};

  String _getCorpus([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final cacheKey = '${id}_${edition.name}';
    final cached = _corpusCache[cacheKey];
    if (cached != null) return cached;

    final sb = getStatBlock(edition);
    final buffer = StringBuffer()
      ..write('${getName(edition)} ')
      ..write('${sb.sizeDisplay} ')
      ..write('${sb.typeDisplay} ')
      ..write('${sb.alignment} ')
      ..write('${sb.crDisplay} ')
      ..write('${sb.speed} ')
      ..write('${sb.ac} ')
      ..write('${sb.maxHp} ')
      ..write('${sb.savingThrows ?? ''} ')
      ..write('${sb.skills ?? ''} ')
      ..write('${sb.damageVulnerabilities ?? ''} ')
      ..write('${sb.damageResistances ?? ''} ')
      ..write('${sb.damageImmunities ?? ''} ')
      ..write('${sb.conditionImmunities ?? ''} ')
      ..write('${sb.senses} ')
      ..write('${sb.languages} ')
      ..write('$sourcePresetName ');

    for (final trait in sb.traits) {
      buffer
        ..write('${trait.name} ')
        ..write('${trait.description} ');
    }

    for (final action in sb.actions) {
      buffer
        ..write('${action.name} ')
        ..write('${action.description} ')
        ..write('${action.attackType ?? ''} ')
        ..write('${action.reach ?? ''} ')
        ..write('${action.hitDamage ?? ''} ');
    }

    for (final reaction in sb.reactions) {
      buffer
        ..write('${reaction.name} ')
        ..write('${reaction.description} ');
    }

    final corpus = buffer.toString().toLowerCase();
    _corpusCache[cacheKey] = corpus;
    return corpus;
  }

  bool matches(
    String query, {
    String? typeFilter,
    String? sizeFilter,
    double? maxCr,
    double? minCr,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final sb = getStatBlock(edition);
    final crVal = _parseChallengeRating(sb.crDisplay);

    if (typeFilter != null && sb.typeDisplay.toLowerCase() != typeFilter.toLowerCase()) {
      return false;
    }

    if (sizeFilter != null && sb.sizeDisplay.toLowerCase() != sizeFilter.toLowerCase()) {
      return false;
    }

    if (maxCr != null && crVal > maxCr) {
      return false;
    }

    if (minCr != null && crVal < minCr) {
      return false;
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    return _getCorpus(edition).contains(trimmed.toLowerCase());
  }

  static double _parseChallengeRating(String crDisplay) {
    final cleaned = crDisplay.replaceAll(RegExp(r'[^0-9/]'), '');
    if (cleaned.isEmpty) return 0;

    if (cleaned.contains('/')) {
      final pieces = cleaned.split('/');
      if (pieces.length != 2) return 0;
      final numerator = double.tryParse(pieces[0]) ?? 0;
      final denominator = double.tryParse(pieces[1]) ?? 1;
      if (denominator == 0) return 0;
      return numerator / denominator;
    }

    return double.tryParse(cleaned) ?? 0;
  }
}

class MonsterCodexLibrary {
  MonsterCodexLibrary._();

  static final List<MonsterItem> allMonsters = _buildAllMonsters();

  static MonsterItem? getMonsterById(String id) {
    try {
      return allMonsters.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  static MonsterItem? getMonsterByName(String name) {
    final lower = name.trim().toLowerCase();
    try {
      return allMonsters.firstWhere((m) => m.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  static List<MonsterItem> getMonstersByType(String type) {
    final normalized = type.trim().toLowerCase();
    return allMonsters.where((m) => m.type.toLowerCase() == normalized).toList();
  }

  static List<MonsterItem> getMonstersBySize(String size) {
    final normalized = size.trim().toLowerCase();
    return allMonsters.where((m) => m.size.toLowerCase() == normalized).toList();
  }

  static List<MonsterItem> getMonstersByCrRange({
    double minCr = 0,
    double maxCr = double.infinity,
  }) {
    return allMonsters
        .where((m) => m.challengeRating >= minCr && m.challengeRating <= maxCr)
        .toList();
  }

  static List<MonsterItem> getSpellSummonedMonsters() {
    return allMonsters
        .where((m) => m.sourceCategory == SummonCategory.spell)
        .toList();
  }

  static List<MonsterItem> getMagicItemMonsters() {
    return allMonsters
        .where((m) => m.sourceCategory == SummonCategory.magicItem)
        .toList();
  }

  static List<MonsterItem> getMonstersBySourcePreset(String presetId) {
    final normalized = presetId.trim().toLowerCase();
    return allMonsters
        .where((m) => m.sourcePresetId.toLowerCase() == normalized)
        .toList();
  }

  static List<MonsterItem> getCr0ToQuarterMonsters() {
    return getMonstersByCrRange(minCr: 0, maxCr: 0.25);
  }

  static List<MonsterItem> getCrHalfToOneMonsters() {
    return getMonstersByCrRange(minCr: 0.5, maxCr: 1);
  }

  static List<MonsterItem> getCrTwoToFourMonsters() {
    return getMonstersByCrRange(minCr: 2, maxCr: 4);
  }

  static List<MonsterItem> getCrFiveToEightMonsters() {
    return getMonstersByCrRange(minCr: 5, maxCr: 8);
  }

  static List<MonsterItem> getCrNinePlusMonsters() {
    return getMonstersByCrRange(minCr: 9);
  }

  static List<MonsterItem> search(
    String query, {
    String? typeFilter,
    String? sizeFilter,
    double? maxCr,
    double? minCr,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    return allMonsters
        .where(
          (m) => m.matches(
            query,
            typeFilter: typeFilter,
            sizeFilter: sizeFilter,
            maxCr: maxCr,
            minCr: minCr,
            edition: edition,
          ),
        )
        .toList();
  }

  static List<MonsterItem> _buildAllMonsters() {
    final byId = <String, MonsterItem>{};

    // 1. Ingest spell-summoned & companion minions
    for (final sourceEntry in SrdMonsterCrBands.allEntriesByCrBand) {
      final preset = sourceEntry.preset;
      final statBlock = sourceEntry.statBlock;
      byId.putIfAbsent(
        statBlock.id,
        () => MonsterItem.simple(
          id: statBlock.id,
          name: statBlock.name,
          statBlock: statBlock,
          sourcePresetId: preset.id,
          sourcePresetName: preset.name,
          sourceSpellId: preset.spellId,
          sourceCategory: preset.category,
        ),
      );
    }

    // 2. Ingest modular bestiary catalogs
    for (final item in BestiaryCr0ToQuarter.entries) {
      byId.putIfAbsent(item.id, () => item);
    }
    for (final item in BestiaryCrHalfToOne.entries) {
      byId.putIfAbsent(item.id, () => item);
    }
    for (final item in BestiaryCrTwoToFour.entries) {
      byId.putIfAbsent(item.id, () => item);
    }
    for (final item in BestiaryCrFiveToEight.entries) {
      byId.putIfAbsent(item.id, () => item);
    }
    for (final item in BestiaryCrNinePlus.entries) {
      byId.putIfAbsent(item.id, () => item);
    }

    final monsters = byId.values.toList()
      ..sort((a, b) {
        final crCompare = a.challengeRating.compareTo(b.challengeRating);
        if (crCompare != 0) return crCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return monsters;
  }
}
