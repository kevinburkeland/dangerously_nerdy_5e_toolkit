import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';

void main() {
  group('Fix 5.1 Law: Legacy room state carries the genesis clock', () {
    test(
      'control: two legacy records with the same id and same name join cleanly',
      () {
        const dto1 = CampaignProfileDto(
          id: 'cmp_same',
          name: 'Curse of the Keep',
          edition: 'dnd5e_2024',
          createdAt: '2025-05-01T12:00:00.000Z',
          lastPlayedAt: '2025-05-01T12:00:00.000Z',
          roomState: {},
        );
        const dto2 = CampaignProfileDto(
          id: 'cmp_same',
          name: 'Curse of the Keep',
          edition: 'dnd5e_2024',
          createdAt: '2025-05-01T12:00:00.000Z',
          lastPlayedAt: '2025-05-01T12:00:00.000Z',
          roomState: {},
        );

        final p1 = dto1.toDomain();
        final p2 = dto2.toDomain();
        final j12 = CampaignProfile.join(p1, p2);
        final j21 = CampaignProfile.join(p2, p1);
        expect(j12.roomState.title, equals(j21.roomState.title));
      },
    );

    test(
      '220 seeded legacy records: every made-up timestamp is genesis and joining differing names converges without CRDT Collision',
      () {
        final rng = Random(140501);
        const genesis = HybridLogicalClock.genesis;

        for (var i = 0; i < 220; i++) {
          final id = 'cmp_legacy_$i';
          final year = 2020 + rng.nextInt(7);
          final month = (1 + rng.nextInt(12)).toString().padLeft(2, '0');
          final day = (1 + rng.nextInt(28)).toString().padLeft(2, '0');
          final hour = rng.nextInt(24).toString().padLeft(2, '0');
          final min = rng.nextInt(60).toString().padLeft(2, '0');
          final createdAt = '$year-$month-${day}T$hour:$min:00.000Z';

          final nameA = 'Campaign Alpha $i';
          final nameB = 'Campaign Beta $i';

          final dtoA = CampaignProfileDto(
            id: id,
            name: nameA,
            edition: i.isEven ? 'dnd5e_2014' : 'dnd5e_2024',
            createdAt: createdAt,
            lastPlayedAt: createdAt,
            roomState: const {},
            partyCharacterIds: ['char_${i}_1'],
            notesMarkdown: i % 3 == 0 ? 'Session note $i' : '',
          );
          final dtoB = CampaignProfileDto(
            id: id,
            name: nameB,
            edition: i.isEven ? 'dnd5e_2014' : 'dnd5e_2024',
            createdAt: createdAt,
            lastPlayedAt: createdAt,
            roomState: const {},
            partyCharacterIds: ['char_${i}_1'],
            notesMarkdown: i % 3 == 0 ? 'Session note $i' : '',
          );

          final pA = dtoA.toDomain();
          final pB = dtoB.toDomain();

          // Joining two devices that upgraded the same legacy campaign under
          // different names must succeed in both orders and converge identically.
          final joinedAB = CampaignProfile.join(pA, pB);
          final joinedBA = CampaignProfile.join(pB, pA);
          expect(
            joinedAB.roomState.title,
            equals(joinedBA.roomState.title),
            reason: 'seed=$i join must be commutative on roomState.title',
          );
          expect(
            joinedAB.roomState.titleRegister.timestamp,
            equals(joinedBA.roomState.titleRegister.timestamp),
            reason: 'seed=$i join must be commutative on titleTimestamp',
          );

          // Every made-up timestamp must be HybridLogicalClock.genesis.
          expect(
            pA.roomState.titleRegister.timestamp,
            equals(genesis),
            reason: 'seed=$i roomState.titleRegister.timestamp must be genesis',
          );
          expect(
            pA.notesRegister.timestamp,
            equals(genesis),
            reason: 'seed=$i notesRegister.timestamp must be genesis',
          );
          for (final ts in pA.partyRoster.items.values.map((e) => e.timestamp)) {
            expect(
              ts,
              equals(genesis),
              reason: 'seed=$i partyRoster entry timestamp must be genesis',
            );
          }
        }
      },
    );
  });
}
