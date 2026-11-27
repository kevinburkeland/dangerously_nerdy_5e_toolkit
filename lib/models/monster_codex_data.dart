import 'arena/monster_combat_profile.dart';
import 'dm_screen_data.dart';
import 'dpr/dpr_models.dart';
import 'monster_codex/bestiary/bestiary_cr_0_to_quarter.dart';
import 'monster_codex/bestiary/bestiary_cr_five_to_eight.dart';
import 'monster_codex/bestiary/bestiary_cr_half_to_one.dart';
import 'monster_codex/bestiary/bestiary_cr_nine_plus.dart';
import 'monster_codex/bestiary/bestiary_cr_two_to_four.dart';
import 'monster_codex/srd_monster_2024_diffs.dart';
import 'monster_codex/srd_monster_cr_bands.dart';
import 'visual/app_icon.dart';
import '../services/rules/dpr_calculator_engine.dart';

export 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'
    show CreatureAction, CreatureTrait, EntityId, Monster, MonsterStatBlock, RulesetVersion, SummonCategory;

enum MonsterSortMode {
  crAscending('CR: Low to High', AppIcon.sort),
  crDescending('CR: High to Low', AppIcon.sort),
  dprDescending('DPR: High to Low', AppIcon.localFireDepartmentOutlined),
  nameAscending('Name: A to Z', AppIcon.sortByAlpha);

  final String label;
  final AppIcon iconKey;
  const MonsterSortMode(this.label, this.iconKey);
}

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

Expando<Map<DmRulesEdition, MonsterCombatProfile>> _combatProfileCache =
    Expando<Map<DmRulesEdition, MonsterCombatProfile>>('Monster.combatProfile');
final Map<String, double> _dprCache = {};

/// App-layer codex, combat profile, DPR, and search extensions on canonical
/// ruleset [Monster].
extension MonsterCodexItemExt on Monster {
  MonsterStatBlock getStatBlock(
      [DmRulesEdition edition = DmRulesEdition.v2024]) {
    return edition == DmRulesEdition.v2014 ? statBlock2014 : statBlock2024;
  }

  String getName([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (edition == DmRulesEdition.v2014 && name2014 != null) return name2014!;
    if (edition == DmRulesEdition.v2024 && name2024 != null) return name2024!;
    return name;
  }

  String? get type => sourceStatBlock.typeDisplay;
  String? get crDisplay => sourceStatBlock.crDisplay;
  double? get challengeRatingValue {
    final raw = sourceStatBlock.crDisplay;
    if (raw == null) return null;
    return parseChallengeRating(raw);
  }
  int? get ac => sourceStatBlock.ac;
  int? get hp => sourceStatBlock.maxHp;
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

  /// Lazily builds and caches one strongly typed [MonsterCombatProfile] per
  /// [DmRulesEdition] for this immutable [Monster] instance.
  MonsterCombatProfile getCombatProfile(
      [DmRulesEdition edition = DmRulesEdition.v2024]) {
    var byEdition = _combatProfileCache[this];
    if (byEdition == null) {
      byEdition = <DmRulesEdition, MonsterCombatProfile>{};
      _combatProfileCache[this] = byEdition;
    }
    return byEdition.putIfAbsent(
      edition,
      () => MonsterCombatProfile.fromStatBlock(
        getStatBlock(edition),
        challengeRating: challengeRatingValue,
      ),
    );
  }

  /// Returns `null` when required combat facts (AC, HP, or readable CR) are
  /// unknown for the active edition.
  double? calculateBaselineDpr([
    DmRulesEdition edition = DmRulesEdition.v2024,
    int targetAc = 15,
  ]) {
    final sb = getStatBlock(edition);
    final rawCr = sb.crDisplay;
    final parsedCr = rawCr == null ? null : parseChallengeRating(rawCr);
    if (sb.ac == null || sb.maxHp == null || parsedCr == null) {
      return null;
    }

    final cacheKey = '${id.slug}_${edition.name}_$targetAc';
    final cached = _dprCache[cacheKey];
    if (cached != null) return cached;

    final allAttacks = sb.extractDprAttacks();
    final adv =
        sb.hasPackTactics ? AdvantageType.advantage : AdvantageType.normal;

    final turnAttacks = allAttacks.where((a) => !a.isLegendaryAction).toList();
    final legAttacks = allAttacks.where((a) => a.isLegendaryAction).toList();

    // 1. Calculate standard Multiattack / Turn DPR
    double multiattackDpr = 0.0;
    for (final attack in turnAttacks) {
      if (attack.rechargeRoll == null && attack.attacksPerRound > 0) {
        final pt = DprCalculatorEngine.calculateSingleAttackDpr(
          attack.copyWith(attacksPerRound: 1),
          targetAc,
          adv,
        );
        multiattackDpr += pt.dpr * attack.attacksPerRound;
      }
    }

    // 2. Check for recharge actions (e.g. Dragon Breath Recharge 5-6 or Recharge 6)
    final rechargeActions =
        turnAttacks.where((a) => a.rechargeRoll != null).toList();
    double turnDpr = multiattackDpr;

    if (rechargeActions.isNotEmpty) {
      DprAttackAction? bestRecharge;
      double maxRechargeDpr = 0.0;
      for (final r in rechargeActions) {
        final pt = DprCalculatorEngine.calculateSingleAttackDpr(
          r.copyWith(attacksPerRound: 1),
          targetAc,
          adv,
        );
        if (pt.dpr > maxRechargeDpr) {
          maxRechargeDpr = pt.dpr;
          bestRecharge = r;
        }
      }

      if (bestRecharge != null && maxRechargeDpr > multiattackDpr) {
        // 3-round amortization (55.6% for Recharge 5-6, 44.4% for Recharge 6)
        final freq =
            bestRecharge.rechargeRoll == 5 ? (1.667 / 3.0) : (1.333 / 3.0);
        turnDpr = (maxRechargeDpr * freq) + (multiattackDpr * (1.0 - freq));
      }
    }

    // 3. Evaluate Legendary Actions (3 actions per round budget)
    double legendaryDpr = 0.0;
    if (legAttacks.isNotEmpty) {
      final scoredLeg = <({DprAttackAction attack, double dpr, int cost})>[];
      for (final la in legAttacks) {
        final pt = DprCalculatorEngine.calculateSingleAttackDpr(
          la.copyWith(attacksPerRound: 1),
          targetAc,
          adv,
        );
        scoredLeg.add((
          attack: la,
          dpr: pt.dpr,
          cost: la.legendaryCost > 0 ? la.legendaryCost : 1
        ));
      }

      double bestLegSum = 0.0;
      for (final option in scoredLeg) {
        final uses = 3 ~/ option.cost;
        final sum = option.dpr * uses;
        if (sum > bestLegSum) bestLegSum = sum;
      }
      for (int i = 0; i < scoredLeg.length; i++) {
        for (int j = 0; j < scoredLeg.length; j++) {
          if (i == j) continue;
          final a = scoredLeg[i];
          final b = scoredLeg[j];
          for (int countA = 0; countA * a.cost <= 3; countA++) {
            final remaining = 3 - (countA * a.cost);
            final countB = remaining ~/ b.cost;
            final sum = (countA * a.dpr) + (countB * b.dpr);
            if (sum > bestLegSum) bestLegSum = sum;
          }
        }
      }
      legendaryDpr = bestLegSum;
    }

    final total = turnDpr + legendaryDpr;
    _dprCache[cacheKey] = total;
    return total;
  }

  String _getCorpus([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final sb = getStatBlock(edition);
    final buffer = StringBuffer()
      ..write('${getName(edition)} ');
    if (sb.sizeDisplay != null) buffer.write('${sb.sizeDisplay} ');
    if (sb.typeDisplay != null) buffer.write('${sb.typeDisplay} ');
    if (sb.alignment != null) buffer.write('${sb.alignment} ');
    if (sb.crDisplay != null) buffer.write('${sb.crDisplay} ');
    buffer.write('${sb.speed} ');
    if (sb.ac != null) buffer.write('${sb.ac} ');
    if (sb.maxHp != null) buffer.write('${sb.maxHp} ');
    buffer
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

    return buffer.toString().toLowerCase();
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
    final rawCr = sb.crDisplay;
    final crVal = rawCr == null ? null : parseChallengeRating(rawCr);

    if (typeFilter != null &&
        (sb.typeDisplay == null ||
            sb.typeDisplay!.toLowerCase() != typeFilter.toLowerCase())) {
      return false;
    }

    if (sizeFilter != null &&
        (sb.sizeDisplay == null ||
            sb.sizeDisplay!.toLowerCase() != sizeFilter.toLowerCase())) {
      return false;
    }

    if (maxCr != null && (crVal == null || crVal > maxCr)) {
      return false;
    }

    if (minCr != null && (crVal == null || crVal < minCr)) {
      return false;
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    return _getCorpus(edition).contains(trimmed.toLowerCase());
  }
}

/// Compares two [Monster] entries by challenge rating, placing unknown (`null`)
/// challenge ratings AFTER every known challenge rating in both ascending and
/// descending order, breaking ties by name (case-insensitive).
int compareMonstersByCr(
  Monster a,
  Monster b, {
  bool ascending = true,
}) {
  final crA = a.challengeRatingValue;
  final crB = b.challengeRatingValue;
  if (crA == null && crB == null) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
  if (crA == null) return 1;
  if (crB == null) return -1;
  final crCompare = ascending ? crA.compareTo(crB) : crB.compareTo(crA);
  if (crCompare != 0) return crCompare;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Compares two [Monster] entries by baseline DPR descending, placing unknown
/// (`null`) DPR entries LAST, breaking ties by edition name.
int compareMonstersByDprDescending(
  Monster a,
  Monster b,
  DmRulesEdition edition,
) {
  final dprA = a.calculateBaselineDpr(edition);
  final dprB = b.calculateBaselineDpr(edition);
  if (dprA == null && dprB == null) {
    return a.getName(edition).toLowerCase().compareTo(b.getName(edition).toLowerCase());
  }
  if (dprA == null) return 1;
  if (dprB == null) return -1;
  final cmp = dprB.compareTo(dprA);
  if (cmp != 0) return cmp;
  return a.getName(edition).compareTo(b.getName(edition));
}

class MonsterCodexLibrary {
  MonsterCodexLibrary._();

  static final List<Monster> _baseMonsters = _buildAllMonsters();
  static List<Monster> _homebrewMonsters = [];

  static void clearCaches() {
    _dprCache.clear();
    _combatProfileCache =
        Expando<Map<DmRulesEdition, MonsterCombatProfile>>(
            'Monster.combatProfile');
  }

  static List<Monster> get allMonsters => [
        ..._baseMonsters,
        ..._homebrewMonsters,
      ];

  static List<Monster> get homebrewMonsters =>
      List.unmodifiable(_homebrewMonsters);

  static Monster _asHomebrewEntry(Monster monster) {
    if (monster.isHomebrew &&
        monster.sourcePresetName == 'Homebrew & Custom Creatures') {
      return monster;
    }
    return monster.copyWith(
      sourcePresetId: 'homebrew',
      sourcePresetName: 'Homebrew & Custom Creatures',
      sourceCategory: SummonCategory.spell,
    );
  }

  static void setHomebrewMonsters(List<Monster> monsters) {
    _homebrewMonsters = monsters.map(_asHomebrewEntry).toList()
      ..sort((a, b) => compareMonstersByCr(a, b, ascending: true));
  }

  static void addHomebrewMonster(Monster monster) {
    final entry = _asHomebrewEntry(monster);
    _homebrewMonsters.removeWhere((m) => m.id.slug == entry.id.slug);
    _homebrewMonsters.add(entry);
    _homebrewMonsters.sort((a, b) => compareMonstersByCr(a, b, ascending: true));
  }

  static void removeHomebrewMonster(String slug) {
    _homebrewMonsters.removeWhere((m) => m.id.slug == slug);
  }

  static void clearHomebrewMonsters() {
    _homebrewMonsters.clear();
  }

  static Monster? getMonsterById(String id) {
    for (final m in allMonsters) {
      if (m.id.slug == id) return m;
    }
    return null;
  }

  static Monster? getMonsterByName(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return null;

    // 1. Exact equality match takes strict precedence
    for (final m in allMonsters) {
      if (m.name.toLowerCase() == lower || m.id.slug.toLowerCase() == lower) {
        return m;
      }
    }

    // 2. Strict word-boundary fallback regex matching
    final wordRegex =
        RegExp(r'\b' + RegExp.escape(lower) + r'\b', caseSensitive: false);
    for (final m in allMonsters) {
      final mLower = m.name.toLowerCase();
      if (wordRegex.hasMatch(mLower)) {
        // Enforce word-boundary anti-collision: prevent generic 'dragon' from matching 'Dragon Turtle'
        if (lower == 'dragon' &&
            (mLower.contains('turtle') || mLower == 'dragon turtle')) {
          continue;
        }
        return m;
      }
    }
    return null;
  }

  static List<Monster> getMonstersByType(String type) {
    final normalized = type.trim().toLowerCase();
    return allMonsters
        .where((m) => m.type != null && m.type!.toLowerCase() == normalized)
        .toList();
  }

  static List<Monster> getMonstersBySize(String size) {
    final normalized = size.trim().toLowerCase();
    return allMonsters
        .where((m) => m.size != null && m.size!.toLowerCase() == normalized)
        .toList();
  }

  static List<Monster> getMonstersByCrRange({
    double minCr = 0,
    double maxCr = double.infinity,
  }) {
    return allMonsters.where((m) {
      final cr = m.challengeRatingValue ?? 0.0;
      return cr >= minCr && cr <= maxCr;
    }).toList();
  }

  static List<Monster> getSpellSummonedMonsters() {
    return allMonsters
        .where((m) => m.sourceCategory == SummonCategory.spell)
        .toList();
  }

  static List<Monster> getMagicItemMonsters() {
    return allMonsters
        .where((m) => m.sourceCategory == SummonCategory.magicItem)
        .toList();
  }

  static List<Monster> getMonstersBySourcePreset(String presetId) {
    final normalized = presetId.trim().toLowerCase();
    return allMonsters
        .where((m) => m.sourcePresetId.toLowerCase() == normalized)
        .toList();
  }

  static List<Monster> getCr0ToQuarterMonsters() {
    return getMonstersByCrRange(minCr: 0, maxCr: 0.25);
  }

  static List<Monster> getCrHalfToOneMonsters() {
    return getMonstersByCrRange(minCr: 0.5, maxCr: 1);
  }

  static List<Monster> getCrTwoToFourMonsters() {
    return getMonstersByCrRange(minCr: 2, maxCr: 4);
  }

  static List<Monster> getCrFiveToEightMonsters() {
    return getMonstersByCrRange(minCr: 5, maxCr: 8);
  }

  static List<Monster> getCrNinePlusMonsters() {
    return getMonstersByCrRange(minCr: 9);
  }

  static List<Monster> search(
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

  static List<Monster> _buildAllMonsters() {
    final byNormalizedKey = <String, Monster>{};

    String normalizeKey(String id, String name) {
      return name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    // 1. Ingest modular bestiary catalogs (definitive SRD stats)
    for (final item in [
      ...BestiaryCr0ToQuarter.entries,
      ...BestiaryCrHalfToOne.entries,
      ...BestiaryCrTwoToFour.entries,
      ...BestiaryCrFiveToEight.entries,
      ...BestiaryCrNinePlus.entries,
    ]) {
      final key = normalizeKey(item.id.slug, item.name);
      byNormalizedKey[key] = item;
    }

    // 2. Ingest spell-summoned & companion minions (augment with spell preset if matching, or add if unique)
    for (final sourceEntry in SrdMonsterCrBands.allEntriesByCrBand) {
      final preset = sourceEntry.preset;
      final statBlock = sourceEntry.statBlock;
      final key = normalizeKey(statBlock.id, statBlock.name);

      final existing = byNormalizedKey[key];
      if (existing != null) {
        if (existing.sourceSpellId == null && preset.spellId != null) {
          byNormalizedKey[key] = existing.copyWith(
            sourcePresetId: preset.id,
            sourcePresetName: preset.name,
            sourceSpellId: preset.spellId,
            sourceCategory: preset.category,
          );
        }
      } else {
        byNormalizedKey[key] = Monster.simple(
          id: EntityId(slug: statBlock.id, ruleset: RulesetVersion.v2014),
          name: statBlock.name,
          statBlock: statBlock,
          sourcePresetId: preset.id,
          sourcePresetName: preset.name,
          sourceSpellId: preset.spellId,
          sourceCategory: preset.category,
        );
      }
    }

    final monsters = byNormalizedKey.values.map((item) {
      final diffInfo = SrdMonster2024Diffs.getDiff(item.id.slug, item.name);
      if (diffInfo != null) {
        return item.copyWith(
          isChangedIn2024: true,
          diffSummary: diffInfo.summary,
          diffHighlights: diffInfo.highlights,
        );
      }
      return item;
    }).toList()
      ..sort((a, b) => compareMonstersByCr(a, b, ascending: true));

    return monsters;
  }
}
