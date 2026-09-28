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

/// Evidence-based detector that identifies candidate boundaries and classifies object types.
class CandidateDetector {
  const CandidateDetector();

  // --- Monster Clue Patterns ---
  static final _monsterSubtitlePattern = RegExp(
    r'\b(Tiny|Small|Medium|Large|Huge|Gargantuan)\s+(humanoid|beast|dragon|fiend|undead|construct|monstrosity|aberration|elemental|fey|giant|ooze|plant|celestial)\b',
    caseSensitive: false,
  );
  static final _armorClassPattern =
      RegExp(r'\b(?:armor\s*class|ac)\s*[:]?\s*(\d+|[^\n]+)', caseSensitive: false);
  static final _hitPointsPattern =
      RegExp(r'\b(?:hit\s*points|hp)\s*[:]?\s*(\d+|[^\n]+)', caseSensitive: false);
  static final _speedPattern =
      RegExp(r'\bspeed\s*[:]?\s*\d+', caseSensitive: false);
  static final _abilityScoresPattern = RegExp(
    r'\b(STR|DEX|CON|INT|WIS|CHA)\b.*?\b(STR|DEX|CON|INT|WIS|CHA)\b',
    caseSensitive: false,
  );
  static final _crPattern = RegExp(
    r'\b(?:challenge|cr)\s*[:]?\s*(\d+/\d+|\d+|[^\n]+)',
    caseSensitive: false,
  );
  static final _actionsHeaderPattern = RegExp(
    r'^(?:actions|bonus actions|reactions|legendary actions)$',
    caseSensitive: false,
  );

  // --- Spell Clue Patterns ---
  static final _spellLevelSchoolPattern = RegExp(
    r'\b(?:(\d+)(?:st|nd|rd|th)[- ]level\s+(\w+)|(abjuration|conjuration|divination|enchantment|evocation|illusion|necromancy|transmutation)\s+cantrip|cantrip(?:\s+(abjuration|conjuration|divination|enchantment|evocation|illusion|necromancy|transmutation))?)\b',
    caseSensitive: false,
  );
  static final _castingTimePattern =
      RegExp(r'\bcasting\s*time\s*:', caseSensitive: false);
  static final _rangePattern = RegExp(r'\brange\s*:', caseSensitive: false);
  static final _componentsPattern =
      RegExp(r'\bcomponents\s*:', caseSensitive: false);
  static final _durationPattern =
      RegExp(r'\bduration\s*:', caseSensitive: false);

  /// Segments [doc] into candidate object clusters and unassigned prose blocks.
  List<CandidateBlockCluster> detectClusters(SourceDocument doc) {
    if (doc.blocks.isEmpty) return const [];

    final rawClusters = _partitionIntoClusters(doc.blocks);
    final results = <CandidateBlockCluster>[];

    for (final clusterBlocks in rawClusters) {
      final identification = identifyCluster(clusterBlocks);

      // A cluster is treated as a candidate if it was identified as a known type,
      // is ambiguous between known types, or has heading with structured stats.
      final totalEvidence = identification.evidence.length;
      final isCandidate = (!identification.isUnknown &&
              (totalEvidence >= 2 || identification.confidence >= 0.6)) ||
          (clusterBlocks.isNotEmpty &&
              clusterBlocks.first.type == SourceBlockType.heading &&
              clusterBlocks.length > 2 &&
              _containsAnyKeyClue(clusterBlocks));

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

    double monsterScore = 0.0;
    double spellScore = 0.0;

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
        monsterScore += 0.20;
        monsterEvidence.add(
          CandidateEvidence(
            category: 'Combat Actions Header',
            description: 'Found standard Actions heading',
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
        spellScore += 0.25;
        spellEvidence.add(
          CandidateEvidence(
            category: 'Casting Time',
            description: 'Found Casting Time field',
            weight: 0.25,
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
    }

    final clampedMonster = math.min(1.0, monsterScore);
    final clampedSpell = math.min(1.0, spellScore);

    // Decision Logic
    const minThreshold = 0.35;
    const distinctMargin = 0.15;

    if (clampedMonster >= minThreshold &&
        clampedMonster - clampedSpell >= distinctMargin) {
      return CandidateIdentification(
        identifiedTypeKey: 'monster',
        confidence: clampedMonster,
        evidence: monsterEvidence,
      );
    }

    if (clampedSpell >= minThreshold &&
        clampedSpell - clampedMonster >= distinctMargin) {
      return CandidateIdentification(
        identifiedTypeKey: 'spell',
        confidence: clampedSpell,
        evidence: spellEvidence,
      );
    }

    if (clampedMonster >= minThreshold && clampedSpell >= minThreshold) {
      return CandidateIdentification.ambiguous(
        plausibleTypes: ['monster', 'spell'],
        evidence: [...monsterEvidence, ...spellEvidence],
        confidence: (clampedMonster + clampedSpell) / 2,
      );
    }

    return const CandidateIdentification.unknown();
  }

  /// Partitions blocks into candidate clusters based on Markdown headings, dividers,
  /// or strong stat block start indicators.
  List<List<SourceBlock>> _partitionIntoClusters(List<SourceBlock> blocks) {
    final clusters = <List<SourceBlock>>[];
    var currentCluster = <SourceBlock>[];

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      final isDivider = block.type == SourceBlockType.divider;
      // H1/H2 headings always indicate a new object boundary.
      // H3+ headings only start a new object if followed by an entity subtitle clue.
      final isHeadingBoundary = block.type == SourceBlockType.heading &&
          (block.headingLevel <= 2 ||
              _isStandAloneTitle(block, i, blocks) ||
              currentCluster.isEmpty);

      // Look ahead to check if the next block is a strong entity start clue
      // (e.g. line 1: "Goblin", line 2: "Small humanoid...")
      final isStatBlockTitle = _isStandAloneTitle(block, i, blocks);

      if ((isDivider || isHeadingBoundary || isStatBlockTitle) &&
          currentCluster.isNotEmpty) {
        clusters.add(currentCluster);
        currentCluster = [];
        if (isDivider) {
          // Dividers act as boundaries; do not include them in candidates
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

    // Must be short (like a name), not a long paragraph
    if (currentText.length > 50 || currentText.contains('.')) return false;

    // Must not be a stat line (AC, HP, Speed, Challenge, STR, etc.)
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
        lower.startsWith('duration:')) {
      return false;
    }

    // Followed by Monster subtitle or Spell school line
    return _monsterSubtitlePattern.hasMatch(nextText) ||
        _spellLevelSchoolPattern.hasMatch(nextText);
  }

  bool _containsAnyKeyClue(List<SourceBlock> blocks) {
    for (final b in blocks) {
      final t = b.normalizedText;
      if (_monsterSubtitlePattern.hasMatch(t) ||
          _armorClassPattern.hasMatch(t) ||
          _hitPointsPattern.hasMatch(t) ||
          _spellLevelSchoolPattern.hasMatch(t) ||
          _castingTimePattern.hasMatch(t)) {
        return true;
      }
    }
    return false;
  }
}
