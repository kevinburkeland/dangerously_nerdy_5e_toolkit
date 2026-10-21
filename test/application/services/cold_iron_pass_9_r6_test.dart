import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';

void main() {
  group('Cold Iron Pass 9 — R6: Legacy Scalar Purses (Keep Max)', () {
    test('Loads two legacy records through DTO: identical balances merge to same, different to per-denomination max, later CRDT credits add normally', () {
      final legacyPayloadA = <String, dynamic>{
        'id': 'camp_legacy_purse',
        'name': 'Legacy Coins Campaign',
        'edition': 'v2024',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastPlayedAt': '2025-01-01T00:00:00.000Z',
        'partyPurse': {
          'gp': 50,
          'sp': 30,
        },
      };

      final legacyPayloadB = <String, dynamic>{
        'id': 'camp_legacy_purse',
        'name': 'Legacy Coins Campaign',
        'edition': 'v2024',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastPlayedAt': '2025-01-01T00:00:00.000Z',
        'partyPurse': {
          'gp': 30,
          'sp': 70,
        },
      };

      final profileA = CampaignProfileDto.fromMap(legacyPayloadA).toDomain();
      final profileB = CampaignProfileDto.fromMap(legacyPayloadB).toDomain();

      // Case 1: Identical legacy balances merge to that exact balance
      final profileA2 = CampaignProfileDto.fromMap(legacyPayloadA).toDomain();
      final mergedIdentical = CampaignProfile.join(profileA, profileA2);
      expect(mergedIdentical.partyPurse.getBalance('gp'), equals(50));
      expect(mergedIdentical.partyPurse.getBalance('sp'), equals(30));

      // Case 2: Differing legacy balances merge to the per-denomination max
      final mergedDiffering = CampaignProfile.join(profileA, profileB);
      expect(mergedDiffering.partyPurse.getBalance('gp'), equals(50), reason: 'max(50, 30) = 50 gp');
      expect(mergedDiffering.partyPurse.getBalance('sp'), equals(70), reason: 'max(30, 70) = 70 sp');

      // Case 3: Later CRDT credit on top adds normally
      final repC = ReplicaId('node_replica_c');
      final creditedPurse = mergedDiffering.partyPurse.modifyDenomination('gp', 25, replicaId: repC);
      expect(creditedPurse.getBalance('gp'), equals(75), reason: '50 gp baseline + 25 gp credit = 75 gp');
      expect(creditedPurse.getBalance('sp'), equals(70), reason: 'sp balance remains 70 sp');

      // Merging credited replica with uncredited replica converges to 75 gp
      final creditedProfile = mergedDiffering.copyWith(partyPurse: creditedPurse);
      final finalMerged = CampaignProfile.join(mergedDiffering, creditedProfile);
      expect(finalMerged.partyPurse.getBalance('gp'), equals(75));
      expect(finalMerged.partyPurse.getBalance('sp'), equals(70));
    });
  });
}
