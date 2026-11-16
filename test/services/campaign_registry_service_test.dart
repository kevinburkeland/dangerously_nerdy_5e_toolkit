import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/join_create_room_dialog.dart';

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

    test('Host membership saves and retrieves hostKey directly', () async {
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

      final retrieved = registry.getMembership('ROOM-DM9999');
      expect(retrieved, isNotNull);
      expect(retrieved!.hostKey, equals(hostKey));
      expect(retrieved.role, equals(CampaignRole.host));
      expect(retrieved.isDmOrCoDm, isTrue);
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
      expect(
          hash1,
          equals(
              'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'));

      final hostKey = CryptoUtils.generateHostKey();
      final hostHash = CryptoUtils.sha256Hex(hostKey);
      expect(hostHash.length, equals(64));
    });

    testWidgets(
      'Reviewer case: two stored memberships with same room code do not throw in dice join dialog or loadMemberships',
      (tester) async {
        final registry = CampaignRegistryService.newInstance();
        final older = CampaignMembership(
          roomCode: 'ROOM-DUPE1',
          campaignName: 'Older Campaign',
          lastPlayed: DateTime.utc(2026, 1, 1),
        );
        final newer = CampaignMembership(
          roomCode: 'room-dupe1',
          campaignName: 'Newer Campaign',
          lastPlayed: DateTime.utc(2026, 11, 1),
        );

        SharedPreferences.setMockInitialValues({
          'user_campaign_registry': [
            jsonEncode(older.toMap()),
            jsonEncode(newer.toMap()),
          ],
        });

        final loaded = await registry.loadMemberships();
        expect(loaded.length, equals(1));
        expect(loaded.first.campaignName, equals('Newer Campaign'));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JoinCreateRoomDialog(
                campaigns: loaded,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    test('Law: 300 seeded random stored lists produce unique codes and preserve all unique codes', () async {
      final candidateCodes = ['ROOM-AAA', 'room-aaa', 'ROOM-BBB', 'room-bbb', 'ROOM-CCC', 'room-ccc', 'room-ddd'];

      for (var seed = 0; seed < 300; seed++) {
        final rng = Random(seed);
        final listLength = rng.nextInt(15) + 1;
        final stored = <CampaignMembership>[];
        final expectedUpper = <String>{};

        for (var i = 0; i < listLength; i++) {
          final code = candidateCodes[rng.nextInt(candidateCodes.length)];
          final m = CampaignMembership(
            roomCode: code,
            campaignName: 'Camp $code $i',
            lastPlayed: DateTime.fromMillisecondsSinceEpoch(1000000000000 + rng.nextInt(10000000)),
          );
          stored.add(m);
          expectedUpper.add(code.trim().toUpperCase());
        }

        SharedPreferences.setMockInitialValues({
          'user_campaign_registry': stored.map((m) => jsonEncode(m.toMap())).toList(),
        });

        final registry = CampaignRegistryService.newInstance();
        final loaded = await registry.loadMemberships();

        final loadedUpper = loaded.map((m) => m.roomCode.trim().toUpperCase()).toList();
        final loadedUpperSet = loadedUpper.toSet();

        expect(
          loadedUpper.length,
          equals(loadedUpperSet.length),
          reason: 'Seed $seed: loaded codes must be unique',
        );
        expect(
          loadedUpperSet,
          equals(expectedUpper),
          reason: 'Seed $seed: every code in the stored list must appear once in the result',
        );

        // Verify newest lastPlayed won for each unique code
        for (final upperCode in expectedUpper) {
          final matchingStored = stored.where((m) => m.roomCode.trim().toUpperCase() == upperCode).toList()
            ..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
          final winner = loaded.firstWhere((m) => m.roomCode.trim().toUpperCase() == upperCode);
          expect(
            winner.lastPlayed,
            equals(matchingStored.first.lastPlayed),
            reason: 'Seed $seed: winning entry for $upperCode must have the newest lastPlayed',
          );
        }
      }
    });
  });
}
