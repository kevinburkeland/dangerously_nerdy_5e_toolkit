import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_connection_telemetry.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';
import '../test_doubles/fake_room_document_port.dart';
import '../test_doubles/service_test_configurator.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;

  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  void seedProfile(CampaignProfile profile) {
    profiles[profile.id] = profile;
  }

  void seedActiveProfile(CampaignProfile? profile) {
    _activeProfile = profile;
  }

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current =
        profiles[id] ?? (_activeProfile?.id == id ? _activeProfile : null);
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeController.add(null);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;
}

class _BannerTestOrchestrator extends Fake implements RoomSyncOrchestrator {
  @override
  bool get isSynchronizing => false;

  @override
  void startSynchronization() {}

  @override
  void stopSynchronization() {}

  @override
  Stream<RoomConnectionTelemetry> watchTelemetry() => const Stream.empty();

  @override
  RoomConnectionTelemetry get currentTelemetry =>
      const RoomConnectionTelemetry(state: TransportState.offline, peerCount: 0);
}

class _BannerTestStarter extends Fake implements RoomSessionStarter {
  @override
  void start() {}
}

void main() {
  late ReplicaId rep;
  late StatefulHlcClock clock;
  late _InMemoryCampaignRepo repo;
  late RecordingRoomDocumentPort port;
  late PartyRoomService party;
  late DiceRoomService diceService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetTestServices();
    sl.reset();

    rep = ReplicaId('banner_rules_node');
    clock = StatefulHlcClock(replicaId: rep);
    repo = _InMemoryCampaignRepo();
    port = RecordingRoomDocumentPort();

    final transport = NoOpP2pTransportPort();
    final orchestrator = _BannerTestOrchestrator();
    final starter = _BannerTestStarter();

    sl.registerSingleton<ReplicaId>(rep);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(repo);
    sl.registerSingleton<IRoomDocumentPort>(port);
    sl.registerSingleton<IP2pTransportPort>(transport);
    sl.registerSingleton<RoomSyncOrchestrator>(orchestrator);
    sl.registerSingleton<RoomSessionStarter>(starter);

    CampaignProfileService.resetForTesting();
    configureTestServices(
      repository: repo,
      replicaId: rep,
      clock: clock,
      transport: transport,
      orchestrator: orchestrator,
      sessionStarter: starter,
    );

    diceService = DiceRoomService.newInstance()
      ..bind(
        transport: transport,
        orchestrator: orchestrator,
        sessionStarter: starter,
      );

    party = PartyRoomService(
      replicaId: rep,
      clock: clock,
      roomDocumentPort: port,
      diceRoomService: diceService,
    );
    sl.registerSingleton<PartyRoomService>(party);
  });

  tearDown(() {
    resetTestServices();
    sl.reset();
  });

  Widget buildBanner() {
    return MaterialApp(
      home: Scaffold(
        body: RoomBannerWidget(roomService: diceService),
      ),
    );
  }

  group('RoomBannerWidget real campaign rules — Fix 1.2', () {
    testWidgets('(a) A new dice room: no SnackBar, no profile, active unchanged', (tester) async {
      await tester.pumpWidget(buildBanner());

      diceService.joinRoom('ROOM-AAA111', 'Valen');
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(repo.allProfiles, isEmpty);
      expect(repo.activeProfileId, isNull);
    });

    testWidgets('(b) An existing dice room document, with cmp_home active: no SnackBar, cmp_home still active, profile count unchanged', (tester) async {
      final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      final home = CampaignProfile.placeholder(
        id: 'cmp_home',
        roomCode: 'ROOM-HOME01',
        name: 'Home Campaign',
        stagingTitle: 'Home Campaign Staging',
        createdAt: now,
        lastPlayedAt: now,
      );
      repo.seedProfile(home);
      repo.seedActiveProfile(home);

      port.roomDataByCode['ROOM-BBB222'] = {
        'roomCode': 'ROOM-BBB222',
        'code': 'ROOM-BBB222',
        'campaignName': 'Dice Room ROOM-BBB222',
        'activePlayers': ['Valen'],
        'lastUpdated': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      };

      await tester.pumpWidget(buildBanner());

      diceService.joinRoom('ROOM-BBB222', 'Valen');
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(repo.activeProfileId, equals('cmp_home'));
      expect(repo.allProfiles, hasLength(1));
    });

    testWidgets('(c) A campaign document: that campaign is active and there is no SnackBar', (tester) async {
      final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      port.roomDataByCode['ROOM-CCC333'] = {
        'roomCode': 'ROOM-CCC333',
        'code': 'ROOM-CCC333',
        'campaignId': 'cmp_abc',
        'campaignName': 'Dragon Heist',
        'hostKeyHash': 'a' * 64,
        'activePlayers': ['Valen'],
        'lastUpdated': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      };

      await tester.pumpWidget(buildBanner());

      diceService.joinRoom('ROOM-CCC333', 'Valen');
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(repo.activeProfileId, equals('cmp_abc'));
      expect(repo.allProfiles.map((p) => p.id).toList(), equals(['cmp_abc']));
    });

    testWidgets('(d) A port read error: one SnackBar, no profile written', (tester) async {
      port.shouldThrowOnGet = Exception('Firestore read failure');

      await tester.pumpWidget(buildBanner());

      diceService.joinRoom('ROOM-DDD444', 'Valen');
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(repo.allProfiles, isEmpty);
      expect(repo.activeProfileId, isNull);
    });
  });
}
