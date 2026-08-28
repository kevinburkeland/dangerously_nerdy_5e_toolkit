import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampaignRegistryService & Passkey Delegation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves, orders, and loads multiple campaign memberships', () async {
      final registry = CampaignRegistryService.newInstance();

      final c1 = CampaignMembership(
        roomCode: 'ROOM-111111',
        campaignName: 'Campaign One',
        role: CampaignRole.player,
        lastPlayed: DateTime.now().subtract(const Duration(days: 2)),
      );

      final c2 = CampaignMembership(
        roomCode: 'ROOM-222222',
        campaignName: 'Campaign Two',
        role: CampaignRole.host,
        hostKey: 'test-host-key-uuid',
        lastPlayed: DateTime.now(),
      );

      await registry.saveMembership(c1);
      await registry.saveMembership(c2);

      final loaded = await registry.loadMemberships();
      expect(loaded.length, equals(2));
      // c2 was played more recently, so it should be first
      expect(loaded.first.roomCode, equals('ROOM-222222'));
      expect(loaded.first.isHost, isTrue);
      expect(loaded.last.roomCode, equals('ROOM-111111'));
    });

    test('Removes a membership from persistent registry', () async {
      final registry = CampaignRegistryService.newInstance();

      final c1 = CampaignMembership(
        roomCode: 'ROOM-AAA111',
        campaignName: 'Campaign A',
        lastPlayed: DateTime.now(),
      );

      await registry.saveMembership(c1);
      expect(registry.getMembership('ROOM-AAA111'), isNotNull);

      await registry.removeMembership('ROOM-AAA111');
      expect(registry.getMembership('ROOM-AAA111'), isNull);
      expect(registry.memberships.isEmpty, isTrue);
    });

    test('6-Word Mnemonic Passkey Export and Import', () async {
      final registry = CampaignRegistryService.newInstance();
      const hostKey = 'c9a0b123-4567-489a-bcde-f0123456789a';

      final hostMembership = CampaignMembership(
        roomCode: 'ROOM-DM9999',
        campaignName: 'Tomb of Annihilation',
        role: CampaignRole.host,
        hostKey: hostKey,
        lastPlayed: DateTime.now(),
      );

      await registry.saveMembership(hostMembership);

      final mnemonic = registry.exportPasskeyMnemonic('ROOM-DM9999');
      expect(mnemonic, isNotNull);
      final words = mnemonic!.split(' ');
      expect(words.length, equals(6));
      expect(CryptoUtils.isValidMnemonic(mnemonic), isTrue);

      // Co-DM imports on secondary device
      final coDmMembership = await registry.importPasskey(
        roomCode: 'ROOM-DM9999',
        campaignName: 'Tomb of Annihilation',
        passkeyOrMnemonic: mnemonic,
        playerName: 'Co-DM Jane',
      );

      expect(coDmMembership.role, equals(CampaignRole.coDm));
      expect(coDmMembership.isDmOrCoDm, isTrue);
      expect(coDmMembership.characterId, equals('Co-DM Jane'));
    });

    test('CryptoUtils room code generator generates unguessable codes', () {
      final code1 = CryptoUtils.generateRoomCode();
      final code2 = CryptoUtils.generateRoomCode();

      expect(code1, startsWith('ROOM-'));
      expect(code1.length, equals(11)); // ROOM- + 6 chars
      expect(code1, isNot(equals(code2)));
    });

    test('CryptoUtils SHA-256 hex digest computation', () {
      final hash1 = CryptoUtils.sha256Hex('hello world');
      expect(hash1, equals('b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'));

      final hostKey = CryptoUtils.generateHostKey();
      final hostHash = CryptoUtils.sha256Hex(hostKey);
      expect(hostHash.length, equals(64));
    });
  });
}
