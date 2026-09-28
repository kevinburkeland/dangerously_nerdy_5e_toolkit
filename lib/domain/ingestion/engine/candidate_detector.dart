import 'dart:math' as math;
import '../models/candidate_evidence.dart';
import '../models/candidate_identification.dart';
import '../models/source_block.dart';
import '../models/source_document.dart';
import '../models/source_span.dart';

/// Cluster of source blocks representing a single candidate object or unassigned text.
class CandidateBlockCluster {
  final List<SourceBlock> blocks;
  final CandidateIdentification identification;
  final bool isCandidate;

  const CandidateBlockCluster({
    required this.blocks,
    required this.identification,
    required this.isCandidate,
  });

  SourceSpan get span {
    if (blocks.isEmpty) return const SourceSpan.empty();
    final first = blocks.first.span;
    final last = blocks.last.span;
    return SourceSpan(
      startOffset: first.startOffset,
      endOffset: last.endOffset,
      startLine: first.startLine,
      startColumn: first.startColumn,
      endLine: last.endLine,
      endColumn: last.endColumn,
      text: blocks.map((b) => b.rawText).join('\n'),
    );
  }
}

class _TypeEvaluation {
  final String typeKey;
  final double score;
  final List<CandidateEvidence> evidence;

  const _TypeEvaluation({
    required this.typeKey,
    required this.score,
    required this.evidence,
  });
}

/// Evidence-based detector that identifies candidate boundaries and classifies object types.
class CandidateDetector {
  const CandidateDetector();

  // --- 1. Monster Clue Patterns ---
  static final _monsterSubtitlePattern = RegExp(
    r'\b(Tiny|Small|Medium|Large|Huge|Gargantuan)\s+(humanoid|beast|dragon|fiend|undead|construct|monstrosity|aberration|elemental|fey|giant|ooze|plant|celestial)\b',
    caseSensitive: false,
  );
  static final _armorClassPattern =
      RegExp(r'\b(?:armor\s*class|ac)\b\s*[:]?\s*(\d+|[^\n]+)', caseSensitive: false);
  static final _hitPointsPattern =
      RegExp(r'\b(?:hit\s*points|hp)\b\s*[:]?\s*(\d+|[^\n]+)', caseSensitive: false);
  static final _speedPattern =
      RegExp(r'\bspeed\b\s*[:]?\s*\d+', caseSensitive: false);
  static final _abilityScoresPattern = RegExp(
    r'\b(STR|DEX|CON|INT|WIS|CHA)\b.*?\b(STR|DEX|CON|INT|WIS|CHA)\b',
    caseSensitive: false,
  );
  static final _crPattern = RegExp(
    r'\b(?:challenge(?:\s+rating)?|cr)\b\s*[:]?\s*(\d+/\d+|\d+|[^\n]+)',
    caseSensitive: false,
  );
  static final _actionsHeaderPattern = RegExp(
    r'^(?:actions|bonus actions|reactions|legendary actions)$',
    caseSensitive: false,
  );

  // --- 2. Spell Clue Patterns ---
  static final _spellLevelSchoolPattern = RegExp(
    r'\b(?:(\d+)(?:st|nd|rd|th)[- ]level\s+(abjuration|conjuration|divination|enchantment|evocation|illusion|necromancy|transmutation)|(abjuration|conjuration|divination|enchantment|evocation|illusion|necromancy|transmutation)\s+cantrip|cantrip(?:\s+(abjuration|conjuration|divination|enchantment|evocation|illusion|necromancy|transmutation))?)\b',
    caseSensitive: false,
  );
  static final _castingTimePattern =
      RegExp(r'\bcasting\s*time\s*:', caseSensitive: false);
  static final _rangePattern = RegExp(r'\brange\s*:', caseSensitive: false);
  static final _componentsPattern =
      RegExp(r'\bcomponents\s*:', caseSensitive: false);
  static final _durationPattern =
      RegExp(r'\bduration\s*:', caseSensitive: false);

  // --- 3. Item / Equipment Clue Patterns ---
  static final _itemRarityPattern = RegExp(
    r'\b(common|uncommon|rare|very\s+rare|legendary|artifact)\b',
    caseSensitive: false,
  );
  static final _itemCategoryPattern = RegExp(
    r'\b(wondrous\s+item|weapon|armor|potion|ring|rod|staff|wand|scroll)\b',
    caseSensitive: false,
  );
  static final _itemAttunementPattern = RegExp(
    r'\b(?:requires\s+attunement|attunement)\b',
    caseSensitive: false,
  );
  static final _itemSubtitleCombinedPattern = RegExp(
    r'^([^,]+),\s*(common|uncommon|rare|very\s+rare|legendary|artifact|varies)',
    caseSensitive: false,
  );

  // --- 4. Feat Clue Patterns ---
  static final _featCategoryPattern = RegExp(
    r'\b(General\s+Feat|Origin\s+Feat|Fighting\s+Style\s+Feat|Epic\s+Boon(?:\s+Feat)?)\b',
    caseSensitive: false,
  );
  static final _featPrereqPattern = RegExp(
    r'^Prerequisite\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _featBenefitBulletPattern = RegExp(
    r'^\s*[-*•]\s+(?:You\s+gain|Increase\s+your|When\s+you|You\s+have|Your\s+speed)\b',
    caseSensitive: false,
  );

  // --- 5. Class Clue Patterns ---
  static final _classHitDiePattern = RegExp(
    r'\bHit\s+Di(?:e|ce)\s*[:]?\s*(?:1)?(d\d+)\b',
    caseSensitive: false,
  );
  static final _classPrimaryAbilityPattern = RegExp(
    r'\bPrimary\s+Ability\s*[:]?\s*(?:Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma)\b',
    caseSensitive: false,
  );
  static final _classSavingThrowsPattern = RegExp(
    r'\bSaving\s+Throws?\s*[:]?\s*(?:Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma)\b',
    caseSensitive: false,
  );
  static final _classFeaturesHeaderPattern = RegExp(
    r'^(?:Core\s+Traits|Class\s+Features|Class\s+Table)\b',
    caseSensitive: false,
  );

  // --- 6. Subclass Clue Patterns ---
  static final _subclassParentPattern = RegExp(
    r'\b(?:Subclass\s+for|Archetype\s+for|Option\s+for)\s+(?:Barbarian|Bard|Cleric|Druid|Fighter|Monk|Paladin|Ranger|Rogue|Sorcerer|Warlock|Wizard)\b|^(?:Barbarian|Bard|Cleric|Druid|Fighter|Monk|Paladin|Ranger|Rogue|Sorcerer|Warlock|Wizard)\s+(?:Archetype|Subclass|Domain|Circle|College|Path|Tradition|Patron|Sacred\s+Oath|Oath|Origin)\b',
    caseSensitive: false,
  );
  static final _subclassLevelGatePattern = RegExp(
    r'^(?:Level\s+\d+|3rd-Level|6th-Level|10th-Level|14th-Level|7th-Level|11th-Level|15th-Level|18th-Level|20th-Level)\s*[:]?\s*.+$',
    caseSensitive: false,
  );

  // --- 7. Species / Race Clue Patterns ---
  static final _speciesHeaderPattern = RegExp(
    r'\b(?:Creature\s+Type\s*[:]?\s*(?:Humanoid|Fey|Fiend|Celestial|Dragonborn|Elf|Dwarf)|Species\s+Traits|Racial\s+Traits)\b',
    caseSensitive: false,
  );
  static final _speciesSizePattern = RegExp(
    r'^Size\s*[:]?\s*(Small|Medium|Tiny|Large|Small\s+or\s+Medium|Medium\s+or\s+Small)\b',
    caseSensitive: false,
  );
  static final _speciesTraitsPattern = RegExp(
    r'^(?:Darkvision|Fey\s+Ancestry|Keen\s+Senses|Dwarven\s+Resilience|Stonecunning|Breath\s+Weapon|Gnome\s+Cunning|Relentless\s+Endurance|Savage\s+Attacks|Hellish\s+Resistance|Infernal\s+Legacy)\b',
    caseSensitive: false,
  );

  // --- 8. Background Clue Patterns ---
  static final _bgSkillsPattern = RegExp(
    r'\b(?:Skill\s+Proficiencies|Skills)\s*[:]?\s*.*?\b(?:Acrobatics|Animal\s+Handling|Arcana|Athletics|Deception|History|Insight|Intimidation|Investigation|Medicine|Nature|Perception|Performance|Persuasion|Religion|Sleight\s+of\s+Hand|Stealth|Survival)\b',
    caseSensitive: false,
  );
  static final _bgToolsLangPattern = RegExp(
    r'\b(?:Tool\s+Proficiencies|Tools|Languages|Equipment)\s*[:]?\s*.+$',
    caseSensitive: false,
  );
  static final _bgFeatureFeatPattern = RegExp(
    r'\b(?:Feature\s*[:]?\s*.+|Origin\s+Feat\s*[:]?\s*.+)\b',
    caseSensitive: false,
  );

  /// Segments [doc] into candidate object clusters and unassigned prose blocks.
  List<CandidateBlockCluster> detectClusters(SourceDocument doc) {
    if (doc.blocks.isEmpty) return const [];

    final rawClusters = _partitionIntoClusters(doc.blocks);
    final results = <CandidateBlockCluster>[];

    for (final clusterBlocks in rawClusters) {
      final identification = identifyCluster(clusterBlocks);

      final totalEvidence = identification.evidence.length;
      final isCandidate = (!identification.isUnknown &&
              (totalEvidence >= 2 || identification.confidence >= 0.55)) ||
          (clusterBlocks.isNotEmpty &&
              clusterBlocks.first.type == SourceBlockType.heading &&
              clusterBlocks.length >= 2);

      results.add(
        CandidateBlockCluster(
          blocks: clusterBlocks,
          identification: identification,
          isCandidate: isCandidate,
        ),
      );
    }

    return results;
  }

  /// Evidence evaluation for a group of blocks.
  CandidateIdentification identifyCluster(List<SourceBlock> blocks) {
    final monsterEvidence = <CandidateEvidence>[];
    final spellEvidence = <CandidateEvidence>[];
    final itemEvidence = <CandidateEvidence>[];
    final featEvidence = <CandidateEvidence>[];
    final classEvidence = <CandidateEvidence>[];
    final subclassEvidence = <CandidateEvidence>[];
    final speciesEvidence = <CandidateEvidence>[];
    final backgroundEvidence = <CandidateEvidence>[];

    double monsterScore = 0.0;
    double spellScore = 0.0;
    double itemScore = 0.0;
    double featScore = 0.0;
    double classScore = 0.0;
    double subclassScore = 0.0;
    double speciesScore = 0.0;
    double backgroundScore = 0.0;

    bool hasAc = false;
    bool hasHp = false;
    bool hasMonsterCrOrActions = false;
    bool hasClassHitDice = false;
    bool hasClassSavingThrows = false;

    for (final block in blocks) {
      final text = block.normalizedText;

      // 1. Monster Clues
      final subMatch = _monsterSubtitlePattern.firstMatch(text);
      if (subMatch != null) {
        monsterScore += 0.35;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Size & Creature Type',
            description: 'Found "${subMatch.group(0)}"',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      final acMatch = _armorClassPattern.firstMatch(text);
      if (acMatch != null) {
        hasAc = true;
        monsterScore += 0.25;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Armor Class',
            description: 'Found "${acMatch.group(0)}"',
            weight: 0.25,
            span: block.span,
          ),
        );
      }

      final hpMatch = _hitPointsPattern.firstMatch(text);
      if (hpMatch != null) {
        hasHp = true;
        monsterScore += 0.25;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Hit Points',
            description: 'Found "${hpMatch.group(0)}"',
            weight: 0.25,
            span: block.span,
          ),
        );
      }

      if (_speedPattern.hasMatch(text)) {
        monsterScore += 0.15;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Speed',
            description: 'Found movement speed declaration',
            weight: 0.15,
            span: block.span,
          ),
        );
      }

      if (_abilityScoresPattern.hasMatch(text)) {
        monsterScore += 0.35;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Ability Scores',
            description: 'Found D&D ability score identifiers (STR, DEX, CON...)',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      final crMatch = _crPattern.firstMatch(text);
      if (crMatch != null) {
        hasMonsterCrOrActions = true;
        monsterScore += 0.25;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Challenge Rating',
            description: 'Found "${crMatch.group(0)}"',
            weight: 0.25,
            span: block.span,
          ),
        );
      }

      if (_actionsHeaderPattern.hasMatch(text)) {
        hasMonsterCrOrActions = true;
        monsterScore += 0.20;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Actions Header',
            description: 'Found Actions section',
            weight: 0.20,
            span: block.span,
          ),
        );
      }

      // 2. Spell Clues
      final schoolMatch = _spellLevelSchoolPattern.firstMatch(text);
      if (schoolMatch != null) {
        spellScore += 0.40;
        spellEvidence.add(
          CandidateEvidence(
            category: 'Spell Level & School',
            description: 'Found "${schoolMatch.group(0)}"',
            weight: 0.40,
            span: block.span,
          ),
        );
      }

      if (_castingTimePattern.hasMatch(text)) {
        spellScore += 0.30;
        spellEvidence.add(
          CandidateEvidence(
            category: 'Casting Time',
            description: 'Found Casting Time field',
            weight: 0.30,
            span: block.span,
          ),
        );
      }

      if (_rangePattern.hasMatch(text)) {
        spellScore += 0.20;
        spellEvidence.add(
          CandidateEvidence(
            category: 'Range',
            description: 'Found Range field',
            weight: 0.20,
            span: block.span,
          ),
        );
      }

      if (_componentsPattern.hasMatch(text)) {
        spellScore += 0.25;
        spellEvidence.add(
          CandidateEvidence(
            category: 'Components',
            description: 'Found Components field',
            weight: 0.25,
            span: block.span,
          ),
        );
      }

      if (_durationPattern.hasMatch(text)) {
        spellScore += 0.25;
        spellEvidence.add(
          CandidateEvidence(
            category: 'Duration',
            description: 'Found Duration field',
            weight: 0.25,
            span: block.span,
          ),
        );
      }

      // 3. Item Clues
      if (_itemSubtitleCombinedPattern.hasMatch(text)) {
        itemScore += 0.50;
        itemEvidence.add(
          CandidateEvidence(
            category: 'Item Header',
            description: 'Found item type and rarity line',
            weight: 0.50,
            span: block.span,
          ),
        );
      } else {
        if (_itemRarityPattern.hasMatch(text)) {
          itemScore += 0.35;
          itemEvidence.add(
            CandidateEvidence(
              category: 'Item Rarity',
              description: 'Found item rarity keyword',
              weight: 0.35,
              span: block.span,
            ),
          );
        }
        if (_itemCategoryPattern.hasMatch(text)) {
          itemScore += 0.35;
          itemEvidence.add(
            CandidateEvidence(
              category: 'Item Category',
              description: 'Found item category keyword',
              weight: 0.35,
              span: block.span,
            ),
          );
        }
      }

      if (_itemAttunementPattern.hasMatch(text)) {
        itemScore += 0.35;
        itemEvidence.add(
          CandidateEvidence(
            category: 'Attunement',
            description: 'Found attunement declaration',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      // 4. Feat Clues
      final featCatMatch = _featCategoryPattern.firstMatch(text);
      if (featCatMatch != null) {
        featScore += 0.45;
        featEvidence.add(
          CandidateEvidence(
            category: 'Feat Category',
            description: 'Found "${featCatMatch.group(0)}"',
            weight: 0.45,
            span: block.span,
          ),
        );
      }

      if (_featPrereqPattern.hasMatch(text)) {
        featScore += 0.40;
        featEvidence.add(
          CandidateEvidence(
            category: 'Prerequisite',
            description: 'Found Prerequisite declaration',
            weight: 0.40,
            span: block.span,
          ),
        );
      }

      if (_featBenefitBulletPattern.hasMatch(text)) {
        featScore += 0.20;
        featEvidence.add(
          CandidateEvidence(
            category: 'Feat Benefit',
            description: 'Found feat bullet benefit format',
            weight: 0.20,
            span: block.span,
          ),
        );
      }

      // 5. Class Clues
      final hdMatch = _classHitDiePattern.firstMatch(text);
      if (hdMatch != null) {
        hasClassHitDice = true;
        classScore += 0.45;
        classEvidence.add(
          CandidateEvidence(
            category: 'Hit Die',
            description: 'Found class hit die declaration',
            weight: 0.45,
            span: block.span,
          ),
        );
      }

      if (_classPrimaryAbilityPattern.hasMatch(text)) {
        classScore += 0.35;
        classEvidence.add(
          CandidateEvidence(
            category: 'Primary Ability',
            description: 'Found Primary Ability declaration',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      if (_classSavingThrowsPattern.hasMatch(text)) {
        hasClassSavingThrows = true;
        classScore += 0.35;
        classEvidence.add(
          CandidateEvidence(
            category: 'Saving Throws',
            description: 'Found Saving Throw Proficiencies declaration',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      if (_classFeaturesHeaderPattern.hasMatch(text)) {
        classScore += 0.25;
        classEvidence.add(
          CandidateEvidence(
            category: 'Class Features',
            description: 'Found Class Features section',
            weight: 0.25,
            span: block.span,
          ),
        );
      }

      // 6. Subclass Clues
      final scParentMatch = _subclassParentPattern.firstMatch(text);
      if (scParentMatch != null) {
        subclassScore += 0.50;
        subclassEvidence.add(
          CandidateEvidence(
            category: 'Parent Class Relationship',
            description: 'Found parent class indicator "${scParentMatch.group(0)}"',
            weight: 0.50,
            span: block.span,
          ),
        );
      }

      if (_subclassLevelGatePattern.hasMatch(text)) {
        subclassScore += 0.35;
        subclassEvidence.add(
          CandidateEvidence(
            category: 'Subclass Feature Level',
            description: 'Found level-gated subclass feature marker',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      // 7. Species / Race Clues
      if (_speciesHeaderPattern.hasMatch(text)) {
        speciesScore += 0.45;
        speciesEvidence.add(
          CandidateEvidence(
            category: 'Creature Type / Traits',
            description: 'Found species trait/creature type header',
            weight: 0.45,
            span: block.span,
          ),
        );
      }

      if (_speciesSizePattern.hasMatch(text)) {
        speciesScore += 0.30;
        speciesEvidence.add(
          CandidateEvidence(
            category: 'Species Size',
            description: 'Found species size declaration',
            weight: 0.30,
            span: block.span,
          ),
        );
      }

      if (_speciesTraitsPattern.hasMatch(text)) {
        speciesScore += 0.30;
        speciesEvidence.add(
          CandidateEvidence(
            category: 'Innate Trait',
            description: 'Found canonical species lineage trait',
            weight: 0.30,
            span: block.span,
          ),
        );
      }

      // 8. Background Clues
      if (_bgSkillsPattern.hasMatch(text)) {
        backgroundScore += 0.45;
        backgroundEvidence.add(
          CandidateEvidence(
            category: 'Skill Proficiencies',
            description: 'Found background skill proficiencies declaration',
            weight: 0.45,
            span: block.span,
          ),
        );
      }

      if (_bgToolsLangPattern.hasMatch(text)) {
        backgroundScore += 0.35;
        backgroundEvidence.add(
          CandidateEvidence(
            category: 'Tools / Equipment / Languages',
            description: 'Found background tools or equipment line',
            weight: 0.35,
            span: block.span,
          ),
        );
      }

      if (_bgFeatureFeatPattern.hasMatch(text)) {
        backgroundScore += 0.30;
        backgroundEvidence.add(
          CandidateEvidence(
            category: 'Background Feature',
            description: 'Found background feature or origin feat',
            weight: 0.30,
            span: block.span,
          ),
        );
      }
    }

    // --- Disambiguation Rules ---
    // Rule A: Monster vs Species
    // If an entity has AC + HP + (CR or Actions), it is a Monster, NOT a Species!
    if (hasAc && hasHp && (hasMonsterCrOrActions || monsterScore >= 0.5)) {
      speciesScore = 0.0;
      speciesEvidence.clear();
    }
    // If an entity has no AC and no HP, but has species creature type/size/traits, it is NOT a monster!
    if (!hasAc && !hasHp && speciesScore >= 0.35) {
      monsterScore = 0.0;
      monsterEvidence.clear();
    }

    // Rule B: Class vs Subclass
    // If an entity has base Hit Dice and Saving Throws, it is a Class, NOT a Subclass!
    if (hasClassHitDice && hasClassSavingThrows) {
      subclassScore = 0.0;
      subclassEvidence.clear();
    }

    final evaluations = <_TypeEvaluation>[
      _TypeEvaluation(typeKey: 'monster', score: math.min(1.0, monsterScore), evidence: monsterEvidence),
      _TypeEvaluation(typeKey: 'spell', score: math.min(1.0, spellScore), evidence: spellEvidence),
      _TypeEvaluation(typeKey: 'item', score: math.min(1.0, itemScore), evidence: itemEvidence),
      _TypeEvaluation(typeKey: 'feat', score: math.min(1.0, featScore), evidence: featEvidence),
      _TypeEvaluation(typeKey: 'class', score: math.min(1.0, classScore), evidence: classEvidence),
      _TypeEvaluation(typeKey: 'subclass', score: math.min(1.0, subclassScore), evidence: subclassEvidence),
      _TypeEvaluation(typeKey: 'species', score: math.min(1.0, speciesScore), evidence: speciesEvidence),
      _TypeEvaluation(typeKey: 'background', score: math.min(1.0, backgroundScore), evidence: backgroundEvidence),
    ];

    const minThreshold = 0.35;
    const distinctMargin = 0.15;

    final qualifying = evaluations.where((e) => e.score >= minThreshold).toList();
    if (qualifying.isEmpty) {
      return const CandidateIdentification.unknown();
    }

    qualifying.sort((a, b) => b.score.compareTo(a.score));

    final top = qualifying[0];

    // Check for ambiguity: if runner-up is within distinct margin
    if (qualifying.length >= 2) {
      final runnerUp = qualifying[1];
      if ((top.score - runnerUp.score) < distinctMargin) {
        final plausibleKeys = qualifying
            .where((e) => (top.score - e.score) < distinctMargin)
            .map((e) => e.typeKey)
            .toList();
        final combinedEvidence = qualifying
            .where((e) => (top.score - e.score) < distinctMargin)
            .expand((e) => e.evidence)
            .toList();
        return CandidateIdentification.ambiguous(
          plausibleTypes: plausibleKeys,
          evidence: combinedEvidence,
          confidence: top.score,
        );
      }
    }

    return CandidateIdentification(
      identifiedTypeKey: top.typeKey,
      confidence: top.score,
      evidence: top.evidence,
    );
  }

  /// Partitions blocks into candidate clusters based on Markdown headings, dividers,
  /// or strong stat block start indicators.
  List<List<SourceBlock>> _partitionIntoClusters(List<SourceBlock> blocks) {
    final clusters = <List<SourceBlock>>[];
    var currentCluster = <SourceBlock>[];

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      final isDivider = block.type == SourceBlockType.divider;
      final currentHasHeading = currentCluster.any((b) => b.type == SourceBlockType.heading && b.headingLevel <= 3);

      final isHeadingBoundary = block.type == SourceBlockType.heading &&
          (block.headingLevel <= 2 ||
              _isStandAloneTitle(block, i, blocks) ||
              currentCluster.isEmpty);

      final isStatBlockTitle = (!currentHasHeading && block.type != SourceBlockType.heading) && _isStandAloneTitle(block, i, blocks);

      if ((isDivider || isHeadingBoundary || isStatBlockTitle) &&
          currentCluster.isNotEmpty) {
        clusters.add(currentCluster);
        currentCluster = [];
        if (isDivider) {
          continue;
        }
      }

      currentCluster.add(block);
    }

    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    return clusters;
  }

  bool _isStandAloneTitle(SourceBlock current, int index, List<SourceBlock> all) {
    if (index + 1 >= all.length) return false;
    final nextText = all[index + 1].normalizedText;
    final currentText = current.normalizedText;

    if (currentText.length > 50 || currentText.contains('.')) return false;

    // Reject subtitles, attributes, or features from being treated as standalone titles
    if (_featCategoryPattern.hasMatch(currentText) ||
        _monsterSubtitlePattern.hasMatch(currentText) ||
        _spellLevelSchoolPattern.hasMatch(currentText) ||
        _itemSubtitleCombinedPattern.hasMatch(currentText) ||
        _itemCategoryPattern.hasMatch(currentText) ||
        _itemRarityPattern.hasMatch(currentText) ||
        _subclassParentPattern.hasMatch(currentText) ||
        _subclassLevelGatePattern.hasMatch(currentText) ||
        _speciesSizePattern.hasMatch(currentText) ||
        _speciesHeaderPattern.hasMatch(currentText) ||
        _bgSkillsPattern.hasMatch(currentText) ||
        _bgToolsLangPattern.hasMatch(currentText) ||
        _bgFeatureFeatPattern.hasMatch(currentText)) {
      return false;
    }

    final lower = currentText.toLowerCase();
    if (lower.startsWith('armor class') ||
        lower.startsWith('ac ') ||
        lower.startsWith('hit points') ||
        lower.startsWith('hp ') ||
        lower.startsWith('speed ') ||
        lower.startsWith('str ') ||
        lower.startsWith('challenge') ||
        lower.startsWith('cr ') ||
        lower.startsWith('actions') ||
        lower.startsWith('bonus actions') ||
        lower.startsWith('reactions') ||
        lower.startsWith('casting time') ||
        lower.startsWith('range:') ||
        lower.startsWith('components:') ||
        lower.startsWith('duration:') ||
        lower.startsWith('prerequisite') ||
        lower.startsWith('hit dice') ||
        lower.startsWith('primary ability') ||
        lower.startsWith('saving throw') ||
        lower.startsWith('skill proficiencies')) {
      return false;
    }

    return _monsterSubtitlePattern.hasMatch(nextText) ||
        _spellLevelSchoolPattern.hasMatch(nextText) ||
        _itemSubtitleCombinedPattern.hasMatch(nextText) ||
        _featCategoryPattern.hasMatch(nextText) ||
        _featPrereqPattern.hasMatch(nextText) ||
        _classHitDiePattern.hasMatch(nextText) ||
        _subclassParentPattern.hasMatch(nextText) ||
        _speciesHeaderPattern.hasMatch(nextText) ||
        _bgSkillsPattern.hasMatch(nextText);
  }
}
