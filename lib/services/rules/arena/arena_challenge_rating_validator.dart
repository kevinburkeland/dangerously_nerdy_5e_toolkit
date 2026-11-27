import '../../../models/arena/arena_combatant.dart';
import '../../../models/dm_screen_data.dart';

/// Thrown before an arena match or Monte Carlo run begins when a combatant is
/// missing required combat facts (armor class, hit points, challenge rating) or
/// its parsed challenge rating is unreadable / outside the supported SRD range (0–30).
class InvalidArenaChallengeRatingException implements Exception {
  final String combatantName;
  final String challengeRatingText;
  final double? parsedChallengeRating;
  final List<String> missingFacts;

  const InvalidArenaChallengeRatingException({
    required this.combatantName,
    required this.challengeRatingText,
    required this.parsedChallengeRating,
    this.missingFacts = const [],
  });

  String get message {
    if (missingFacts.isNotEmpty) {
      return 'Cannot start arena match: "$combatantName" is missing required '
          'stat block facts (${missingFacts.join(', ')}).';
    }
    return 'Cannot start arena match: "$combatantName" has unsupported challenge '
        'rating "$challengeRatingText" (must be between 0 and 30).';
  }

  @override
  String toString() => message;
}

/// Validates that every combatant has known armor class, hit points, and a
/// readable challenge rating within SRD bounds (0–30 inclusive). Throws
/// [InvalidArenaChallengeRatingException] naming the offending creature and
/// missing facts or CR text before any match or Monte Carlo simulation starts.
void validateArenaCombatantsChallengeRatings(
  Iterable<ArenaCombatant> combatants, {
  DmRulesEdition edition = DmRulesEdition.v2024,
}) {
  for (final combatant in combatants) {
    final sb = combatant.monster.getStatBlock(edition);
    final missing = <String>[];
    if (sb.ac == null && !combatant.hasExplicitAcOverride) {
      missing.add('armor class');
    }
    if (sb.maxHp == null && !combatant.hasExplicitHpOverride) {
      missing.add('hit points');
    }
    if (sb.crDisplay == null || sb.crDisplay!.trim().isEmpty) {
      missing.add('challenge rating');
    }
    if (missing.isNotEmpty) {
      throw InvalidArenaChallengeRatingException(
        combatantName: combatant.displayName,
        challengeRatingText: sb.crDisplay ?? '—',
        parsedChallengeRating: null,
        missingFacts: missing,
      );
    }

    final cr = combatant.monster.challengeRatingValue;
    if (cr == null || cr.isNaN || cr < 0 || cr > 30) {
      throw InvalidArenaChallengeRatingException(
        combatantName: combatant.displayName,
        challengeRatingText: sb.crDisplay ?? '—',
        parsedChallengeRating: cr,
      );
    }
  }
}
