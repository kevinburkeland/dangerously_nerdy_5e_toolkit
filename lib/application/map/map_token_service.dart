import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/value_objects/blob_ref.dart';
import 'package:vtt_engine_core/models/value_objects/map_token.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'grid_geometry.dart';
import 'map_token_rules.dart';

enum MapTokenWriteResult {
  written,
  unchanged,
  notAllowed,
  notFound,
  duplicate,
  noGrid,
  offMap,
  unknownRef,
}

final _labelRegex = RegExp(r'^[A-Z0-9]{1,3}$');

class MapTokenService {
  final ICampaignRepository _campaignRepo;
  final StatefulHlcClock _clock;
  final String Function() _newTokenId;

  /// Creates a [MapTokenService].
  /// newTokenId: generates a unique token id.
  MapTokenService({
    required ICampaignRepository campaignRepo,
    required StatefulHlcClock clock,
    required String Function() newTokenId,
  })  : _campaignRepo = campaignRepo,
        _clock = clock,
        _newTokenId = newTokenId;

  Future<MapTokenWriteResult> placeToken(
    String campaignId,
    BlobRef map,
    MapTokenActor actor, {
    required MapTokenKind kind,
    required String refId,
    required String label,
    required MapTokenCell cell,
  }) async {
    if (!_labelRegex.hasMatch(label)) {
      throw ArgumentError.value(label, 'label', 'Label must be 1 to 3 uppercase alphanumeric characters');
    }

    var result = MapTokenWriteResult.unchanged;
    await _campaignRepo.updateProfile(campaignId, (profile) {
      if (!canEditTokens(actor)) {
        result = MapTokenWriteResult.notAllowed;
        return profile;
      }

      final grid = profile.mapGrid;
      if (grid == null || grid.mapSha256Hex != map.sha256Hex) {
        result = MapTokenWriteResult.noGrid;
        return profile;
      }

      final bool refExists;
      switch (kind) {
        case MapTokenKind.character:
          refExists = profile.partyRoster.activeValues.contains(refId);
        case MapTokenKind.monster:
          refExists = profile.roomState.activeEncounter.items.containsKey(refId);
        case MapTokenKind.minion:
          refExists = profile.roomState.activeMinions.items.containsKey(refId);
      }
      if (!refExists) {
        result = MapTokenWriteResult.unknownRef;
        return profile;
      }

      final activeTokens = profile.tokensOnMap(map.sha256Hex);
      if (activeTokens.any((t) => t.token.kind == kind && t.token.refId == refId)) {
        result = MapTokenWriteResult.duplicate;
        return profile;
      }

      if (!isCellOnMap(grid, map.width, map.height, cell)) {
        result = MapTokenWriteResult.offMap;
        return profile;
      }

      final token = MapToken(
        id: _newTokenId(),
        mapSha256Hex: map.sha256Hex,
        kind: kind,
        refId: refId,
        label: label,
      );

      result = MapTokenWriteResult.written;
      return profile.withTokenPlaced(token, cell, _clock.nextTimestamp());
    });

    return result;
  }

  Future<MapTokenWriteResult> moveToken(
    String campaignId,
    BlobRef map,
    MapTokenActor actor,
    String tokenId,
    MapTokenCell cell,
  ) async {
    var result = MapTokenWriteResult.unchanged;
    await _campaignRepo.updateProfile(campaignId, (profile) {
      final token = profile.activeToken(tokenId);
      if (token == null || token.mapSha256Hex != map.sha256Hex) {
        result = MapTokenWriteResult.notFound;
        return profile;
      }

      if (!canMoveToken(profile, token, actor)) {
        result = MapTokenWriteResult.notAllowed;
        return profile;
      }

      final grid = profile.mapGrid;
      if (grid == null || grid.mapSha256Hex != map.sha256Hex) {
        result = MapTokenWriteResult.noGrid;
        return profile;
      }

      if (!isCellOnMap(grid, map.width, map.height, cell)) {
        result = MapTokenWriteResult.offMap;
        return profile;
      }

      final currentCell = profile.tokenCell(tokenId);
      if (currentCell == cell) {
        result = MapTokenWriteResult.unchanged;
        return profile;
      }

      result = MapTokenWriteResult.written;
      return profile.withTokenMoved(tokenId, cell, _clock.nextTimestamp());
    });

    return result;
  }

  Future<MapTokenWriteResult> removeToken(
    String campaignId,
    MapTokenActor actor,
    String tokenId,
  ) async {
    var result = MapTokenWriteResult.unchanged;
    await _campaignRepo.updateProfile(campaignId, (profile) {
      if (!canEditTokens(actor)) {
        result = MapTokenWriteResult.notAllowed;
        return profile;
      }

      if (profile.activeToken(tokenId) == null) {
        result = MapTokenWriteResult.notFound;
        return profile;
      }

      result = MapTokenWriteResult.written;
      return profile.withTokenRemoved(tokenId, _clock.nextTimestamp());
    });

    return result;
  }

  Future<MapTokenWriteResult> setMinionOwner(
    String campaignId,
    MapTokenActor actor,
    String minionId,
    String? ownerSlug,
  ) async {
    var result = MapTokenWriteResult.unchanged;
    await _campaignRepo.updateProfile(campaignId, (profile) {
      if (!canEditTokens(actor)) {
        result = MapTokenWriteResult.notAllowed;
        return profile;
      }

      if (!profile.roomState.activeMinions.items.containsKey(minionId)) {
        result = MapTokenWriteResult.unknownRef;
        return profile;
      }

      if (ownerSlug != null && !profile.partyRoster.activeValues.contains(ownerSlug)) {
        result = MapTokenWriteResult.unknownRef;
        return profile;
      }

      final currentOwner = profile.minionOwner(minionId);
      if (currentOwner == ownerSlug) {
        result = MapTokenWriteResult.unchanged;
        return profile;
      }

      result = MapTokenWriteResult.written;
      return profile.withMinionOwner(minionId, ownerSlug, _clock.nextTimestamp());
    });

    return result;
  }
}
