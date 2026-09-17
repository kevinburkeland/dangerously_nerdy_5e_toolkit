import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import '../../../domain/models/campaign_profile.dart';
import '../../../domain/storage/ports/i_campaign_snapshot_serializer_port.dart';
import '../../dtos/campaign_profile_dto.dart';

/// Concrete infrastructure adapter implementing [ICampaignSnapshotSerializerPort]
/// using isolate-backed JSON transcoding and [CampaignProfileDto].
class CampaignSnapshotSerializerAdapter implements ICampaignSnapshotSerializerPort {
  const CampaignSnapshotSerializerAdapter();

  /// Registers [CampaignSnapshotSerializerAdapter] as the global default provider.
  static void registerDefault() {
    ICampaignSnapshotSerializerPort.defaultProvider ??=
        () => const CampaignSnapshotSerializerAdapter();
  }

  @override
  Future<Uint8List> serializeToBytes(CampaignProfile profile) async {
    final dto = CampaignProfileDto.fromDomain(profile);
    final jsonStr = await Isolate.run(() => jsonEncode(dto.toJson()));
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  @override
  Future<CampaignProfile> deserializeFromBytes(Uint8List bytes) async {
    final jsonStr = utf8.decode(bytes);
    final decoded = await Isolate.run(() => jsonDecode(jsonStr));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid campaign snapshot payload');
    }
    final inboundDto = CampaignProfileDto.fromMap(decoded);
    return inboundDto.toDomain();
  }
}

// Ensure default provider is registered when adapter library is loaded
final bool _defaultSerializerRegistered = () {
  CampaignSnapshotSerializerAdapter.registerDefault();
  return true;
}();
