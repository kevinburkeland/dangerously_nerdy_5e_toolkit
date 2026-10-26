import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/value_objects/map_token.dart';

sealed class MapTokenActor {
  const MapTokenActor();
  const factory MapTokenActor.dm() = DmActor;
  const factory MapTokenActor.player(String? rosterSlug) = PlayerActor;
}

final class DmActor extends MapTokenActor {
  const DmActor();
}

final class PlayerActor extends MapTokenActor {
  final String? rosterSlug;
  const PlayerActor(this.rosterSlug);
}

/// Returns whether [actor] is permitted to move [token] on [profile].
bool canMoveToken(CampaignProfile profile, MapToken token, MapTokenActor actor) {
  switch (actor) {
    case DmActor():
      return true;
    case PlayerActor(:final rosterSlug):
      if (rosterSlug == null || !profile.partyRoster.activeValues.contains(rosterSlug)) {
        return false;
      }
      switch (token.kind) {
        case MapTokenKind.character:
          return token.refId == rosterSlug;
        case MapTokenKind.minion:
          final isMinionActive = profile.roomState.activeMinions.items.containsKey(token.refId);
          return isMinionActive && profile.minionOwner(token.refId) == rosterSlug;
        case MapTokenKind.monster:
          return false;
      }
  }
}

/// Returns true only for DM actors. Placing, removing, and setting owners need it.
bool canEditTokens(MapTokenActor actor) {
  return actor is DmActor;
}

/// Resolves a player's active roster slug based on membership ID or local character matching.
String? myRosterSlug({
  required Iterable<String> rosterSlugs,
  required String? membershipCharacterId,
  required String playerName,
  required Iterable<({String slug, String name})> localCharacters,
}) {
  final rosterSet = rosterSlugs.toSet();
  if (membershipCharacterId != null && rosterSet.contains(membershipCharacterId)) {
    return membershipCharacterId;
  }
  final trimmedPlayer = playerName.trim().toLowerCase();
  final isGenericOrEmpty = trimmedPlayer.isEmpty || trimmedPlayer == 'dm' || trimmedPlayer == 'adventurer';
  for (final char in localCharacters) {
    if (rosterSet.contains(char.slug)) {
      if (membershipCharacterId != null && char.slug == membershipCharacterId) {
        return char.slug;
      }
      if (!isGenericOrEmpty && char.name.trim().toLowerCase() == trimmedPlayer) {
        return char.slug;
      }
    }
  }
  return null;
}

final _tokenInitialsSplit = RegExp(r'[\s\-_]+');
final _asciiAlphaNumeric = RegExp(r'[A-Za-z0-9]');

/// Extracts 1 to 2 uppercase ASCII initials from [name], or 'X'.
String tokenInitials(String name) {
  final words = name.split(_tokenInitialsSplit).where((w) => w.isNotEmpty).toList();
  final buffer = StringBuffer();
  for (int i = 0; i < words.length && buffer.length < 2; i++) {
    final word = words[i];
    for (int c = 0; c < word.length; c++) {
      final ch = word[c];
      if (_asciiAlphaNumeric.hasMatch(ch)) {
        buffer.write(ch.toUpperCase());
        break;
      }
    }
  }
  return buffer.isEmpty ? 'X' : buffer.toString();
}

/// Generates a unique label from [base] by suffixing digits 2..9 if [base] is taken.
String uniqueTokenLabel(String base, Iterable<String> taken) {
  final takenSet = taken.toSet();
  if (!takenSet.contains(base)) {
    return base;
  }
  final prefix = base.length > 2 ? base.substring(0, 2) : base;
  for (int digit = 2; digit <= 9; digit++) {
    final candidate = '$prefix$digit';
    if (!takenSet.contains(candidate)) {
      return candidate;
    }
  }
  return base;
}
