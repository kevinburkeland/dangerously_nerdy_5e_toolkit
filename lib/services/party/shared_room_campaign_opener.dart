import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import '../../application/services/room_document_port.dart';
import '../../models/party/party_room_lobby.dart';
import 'party_room_service.dart';

/// Opens a campaign profile for a shared room code only when the room is a
/// campaign (either claimed by a local profile or backed by a lobby carrying a
/// non-blank `campaignId`).
///
/// Intended behaviour change from legacy banner behaviour: if a legacy campaign
/// room (no `campaignId` on the server) is opened from the banner on a device
/// where no local profile claims its code, it is treated as a plain dice room
/// (`null`) instead of creating `campaign_<CODE>`. That room is still opened as
/// a campaign through the Party Room screen and the join/rehydrate campaign
/// paths, exactly as before.
class SharedRoomCampaignOpener {
  final PartyRoomService party;
  final ICampaignRepository campaignRepo;
  final IRoomDocumentPort roomDocPort;

  const SharedRoomCampaignOpener({
    required this.party,
    required this.campaignRepo,
    required this.roomDocPort,
  });

  Future<CampaignProfile?> openIfCampaign(String roomCode) async {
    final code = roomCode.trim().toUpperCase();
    final allProfiles = await campaignRepo.loadAllProfiles();
    final hasLocalClaimant = allProfiles.any(
      (p) => p.roomState.roomCode.trim().toUpperCase() == code,
    );
    if (hasLocalClaimant) {
      return party.openRoomProfile(code);
    }

    PartyRoomLobby? lobby = party.getCachedLobby(code);
    if (lobby == null) {
      final doc = await roomDocPort.getRoomDocument(roomCode: code);
      if (doc != null) {
        lobby = PartyRoomLobby.fromMap(doc);
      }
    }

    final campaignId = lobby?.campaignId?.trim();
    if (lobby != null && campaignId != null && campaignId.isNotEmpty) {
      return party.openRoomProfile(code, campaignId, lobby.rulesetId);
    }

    return null;
  }
}
