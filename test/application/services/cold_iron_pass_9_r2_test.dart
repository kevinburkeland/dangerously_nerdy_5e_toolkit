import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/room_code_relink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReplicaId rep;
  late StatefulHlcClock clock;

  setUp(() {
    rep = ReplicaId('test_node_r2');
    clock = StatefulHlcClock(replicaId: rep);
  });

  group('Part A: R2 - Changing profile room code via RoomCodeRelink', () {
    test('Relink from empty roomCode sets roomCode and roomId: room_<CODE>', () {
      final nowTs = clock.nextTimestamp();
      final profile = CampaignProfile.raw(
        id: 'campaign_empty',
        nameRegister: CrdtLwwRegister<String>(value: 'Empty Test', timestamp: nowTs),
        edition: RulesetEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_OLD',
          roomCode: '',
          title: 'Staging',
          titleTimestamp: nowTs,
          description: '',
          descriptionTimestamp: nowTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: CrdtLwwRegister<String>(value: '', timestamp: nowTs),
        changeLog: const [],
      );

      final relinked = RoomCodeRelink.relink(profile, 'NEWROOM', clock);
      expect(relinked.roomState.roomCode, equals('NEWROOM'));
      expect(relinked.roomState.roomId, equals('room_NEWROOM'));
      expect(relinked.roomState.titleRegister.timestamp, equals(profile.roomState.titleRegister.timestamp));
    });

    test('Relink from different roomCode updates roomCode and roomId', () {
      final nowTs = clock.nextTimestamp();
      final profile = CampaignProfile.raw(
        id: 'campaign_123',
        nameRegister: CrdtLwwRegister<String>(value: 'Campaign 123', timestamp: nowTs),
        edition: RulesetEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_OLDROOM',
          roomCode: 'OLDROOM',
          title: 'Campaign OLDROOM Staging',
          titleTimestamp: nowTs,
          description: '',
          descriptionTimestamp: nowTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: CrdtLwwRegister<String>(value: '', timestamp: nowTs),
        changeLog: const [],
      );

      final relinked = RoomCodeRelink.relink(profile, 'DIFFCODE', clock);
      expect(relinked.roomState.roomCode, equals('DIFFCODE'));
      expect(relinked.roomState.roomId, equals('room_DIFFCODE'));
      expect(relinked.roomState.titleRegister.timestamp, equals(profile.roomState.titleRegister.timestamp));
    });

    test('Relink to same roomCode returns profile unchanged without advancing clock or restamping', () {
      final nowTs = clock.nextTimestamp();
      final profile = CampaignProfile.raw(
        id: 'campaign_same',
        nameRegister: CrdtLwwRegister<String>(value: 'Campaign Same', timestamp: nowTs),
        edition: RulesetEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_SAMEROOM',
          roomCode: 'SAMEROOM',
          title: 'Campaign SAMEROOM Staging',
          titleTimestamp: nowTs,
          description: '',
          descriptionTimestamp: nowTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: CrdtLwwRegister<String>(value: '', timestamp: nowTs),
        changeLog: const [],
      );

      final clockBefore = clock.latest;
      final relinked = RoomCodeRelink.relink(profile, 'SAMEROOM', clock);
      expect(identical(relinked, profile) || relinked == profile, isTrue);
      expect(clock.latest, equals(clockBefore));
    });

    test('Relink with stampStagingTitle = true updates staging title and stamps with clock', () {
      final nowTs = clock.nextTimestamp();
      final profile = CampaignProfile.raw(
        id: 'campaign_staging',
        nameRegister: CrdtLwwRegister<String>(value: 'Campaign Staging', timestamp: nowTs),
        edition: RulesetEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_OLDROOM',
          roomCode: 'OLDROOM',
          title: 'Old Title',
          titleTimestamp: nowTs,
          description: '',
          descriptionTimestamp: nowTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: CrdtLwwRegister<String>(value: '', timestamp: nowTs),
        changeLog: const [],
      );

      final relinked = RoomCodeRelink.relink(
        profile,
        'STAGEROOM',
        clock,
        stampStagingTitle: true,
      );

      expect(relinked.roomState.roomCode, equals('STAGEROOM'));
      expect(relinked.roomState.roomId, equals('room_STAGEROOM'));
      expect(relinked.roomState.title, equals('Campaign STAGEROOM Staging'));
      expect(relinked.roomState.titleRegister.timestamp.compareTo(nowTs), greaterThan(0));
    });
  });
}
