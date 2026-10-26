import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/value_objects/map_token.dart';

import '../../models/domain/minion_instance.dart';
import 'map_token_rules.dart';

final class MapTokenCandidate {
  final MapTokenKind kind;
  final String refId;
  final String name; // what the picker shows
  final bool onThisMap; // an active token of this kind and refId is on this map
  final String suggestedLabel;

  const MapTokenCandidate({
    required this.kind,
    required this.refId,
    required this.name,
    required this.onThisMap,
    required this.suggestedLabel,
  });
}

List<MapTokenCandidate> tokenCandidates(
  CampaignProfile profile,
  String mapSha256Hex,
  Map<String, String> characterNames,
) {
  final activeTokensOnMap = profile.tokensOnMap(mapSha256Hex);
  final activeLabelsOnMap = activeTokensOnMap.map((t) => t.token.label).toList();

  bool isOnThisMap(MapTokenKind kind, String refId) {
    return activeTokensOnMap.any((t) => t.token.kind == kind && t.token.refId == refId);
  }

  // 1. Characters: one per active partyRoster value; name is characterNames[slug] trimmed if non-empty, else the slug.
  final characterCandidates = <MapTokenCandidate>[];
  for (final slug in profile.partyRoster.activeValues) {
    final rawName = characterNames[slug]?.trim();
    final name = (rawName != null && rawName.isNotEmpty) ? rawName : slug;
    final suggested = uniqueTokenLabel(tokenInitials(name), activeLabelsOnMap);
    characterCandidates.add(MapTokenCandidate(
      kind: MapTokenKind.character,
      refId: slug,
      name: name,
      onThisMap: isOnThisMap(MapTokenKind.character, slug),
      suggestedLabel: suggested,
    ));
  }
  characterCandidates.sort((a, b) {
    final nameComp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameComp != 0) return nameComp;
    return a.refId.compareTo(b.refId);
  });

  // 2. Combatants: one per active activeEncounter participant; name is its entityLink.displayName trimmed if non-empty, else the participant id.
  final combatantCandidates = <MapTokenCandidate>[];
  for (final participant in profile.roomState.activeEncounter.activeValues) {
    final trimmedName = participant.entityLink.displayName.trim();
    final name = trimmedName.isNotEmpty ? trimmedName : participant.participantId;
    final suggested = uniqueTokenLabel(tokenInitials(name), activeLabelsOnMap);
    combatantCandidates.add(MapTokenCandidate(
      kind: MapTokenKind.monster,
      refId: participant.participantId,
      name: name,
      onThisMap: isOnThisMap(MapTokenKind.monster, participant.participantId),
      suggestedLabel: suggested,
    ));
  }
  combatantCandidates.sort((a, b) {
    final nameComp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameComp != 0) return nameComp;
    return a.refId.compareTo(b.refId);
  });

  // 3. Minions: one per active activeMinions entry; name is the MinionInstance's name trimmed if non-empty, else the id. An entry whose value isn't a MinionInstance is listed with its id as the name.
  final minionCandidates = <MapTokenCandidate>[];
  for (final entry in profile.roomState.activeMinions.items.entries) {
    final id = entry.key;
    final val = entry.value.value;
    final String name;
    if (val is MinionInstance) {
      final trimmed = val.name.trim();
      name = trimmed.isNotEmpty ? trimmed : id;
    } else {
      name = id;
    }
    final suggested = uniqueTokenLabel(tokenInitials(name), activeLabelsOnMap);
    minionCandidates.add(MapTokenCandidate(
      kind: MapTokenKind.minion,
      refId: id,
      name: name,
      onThisMap: isOnThisMap(MapTokenKind.minion, id),
      suggestedLabel: suggested,
    ));
  }
  minionCandidates.sort((a, b) {
    final nameComp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameComp != 0) return nameComp;
    return a.refId.compareTo(b.refId);
  });

  return List<MapTokenCandidate>.unmodifiable([
    ...characterCandidates,
    ...combatantCandidates,
    ...minionCandidates,
  ]);
}
