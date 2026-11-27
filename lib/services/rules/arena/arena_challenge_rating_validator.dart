import '../../../models/arena/arena_combatant.dart';

/// Thrown before an arena match or Monte Carlo run begins when a combatant's
/// parsed challenge rating is outside the supported SRD range (0–30).
class InvalidArenaChallengeRatingException implements Exception {
  final String combatantName;
  final String challengeRatingText;
  final double parsedChallengeRating;

  const InvalidArenaChallengeRatingException({
    required this.combatantName,
    required this.challengeRatingText,
    required this.parsedChallengeRating,
  });

  String get message =>
      'Cannot start arena match: "$combatantName" has unsupported challenge '
      'rating "$challengeRatingText" (must be between 0 and 30).';

  @override
  String toString() => message;
}

/// Validates that every combatant has a challenge rating within SRD bounds
/// (0–30 inclusive). Throws [InvalidArenaChallengeRatingException] naming the
/// offending creature and its CR text if any combatant is out of range.
void validateArenaCombatantsChallengeRatings(
  Iterable<ArenaCombatant> combatants,
) {
  for (final combatant in combatants) {
    final cr = combatant.monster.challengeRatingValue;
    if (cr.isNaN || cr < 0 || cr > 30) {
      throw InvalidArenaChallengeRatingException(
        combatantName: combatant.displayName,
        challengeRatingText: combatant.monster.crDisplay,
        parsedChallengeRating: cr,
      );
    }
  }
}
