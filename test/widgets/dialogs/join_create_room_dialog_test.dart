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
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dialogs/join_create_room_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/service_test_configurator.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;

  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  void seedProfile(CampaignProfile profile) {
    profiles[profile.id] = profile;
  }

  void seedActiveId(String? id) {
    _activeProfile = id == null ? null : profiles[id];
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
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async =>
      profiles.values.toList();

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id) {
      _activeProfile = profile;
      _activeController.add(_activeProfile);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final existing = profiles[id];
    if (existing == null) {
      throw StateError('CampaignProfile not found: $id');
    }
    final next = transform(existing);
    await putProfile(next);
    return next;
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
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;

  void dispose() {
    _activeController.close();
    _allController.close();
  }
}

class _FakeP2pTransport implements IP2pTransportPort {
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();

  @override
  TransportState get currentState => TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  @override
  Future<void> disconnect() async {}

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      false;
}

class _FakeRoomSessionStarter extends Fake implements RoomSessionStarter {
  @override
  void start() {}
}

class _FakeRoomSyncOrchestrator extends Fake implements RoomSyncOrchestrator {
  @override
  bool get isSynchronizing => false;

  @override
  Stream<RoomConnectionTelemetry> watchTelemetry() => const Stream.empty();

  @override
  RoomConnectionTelemetry get currentTelemetry =>
      const RoomConnectionTelemetry(state: TransportState.offline, peerCount: 0);

  @override
  void stopSynchronization() {}
}

CampaignProfile _makeProfile({
  required String id,
  required String roomCode,
  required String name,
}) {
  final ts = DateTime.utc(2026, 11, 12, 12, 0);
  return CampaignProfile.placeholder(
    id: id,
    roomCode: roomCode,
    name: name,
    stagingTitle: '$name Staging',
    createdAt: ts,
    lastPlayedAt: ts,
  );
}

void main() {
  late ReplicaId rep;
  late StatefulHlcClock clock;
  late _InMemoryCampaignRepo repo;
  late RecordingRoomDocumentPort port;
  late PartyRoomService realParty;
  late DiceRoomService diceService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetTestServices();
    sl.reset();
    CampaignRegistryService.resetInstanceForTesting();

    rep = ReplicaId('test_dialog_node');
    clock = StatefulHlcClock(replicaId: rep);
    repo = _InMemoryCampaignRepo();
    port = RecordingRoomDocumentPort();

    final transport = _FakeP2pTransport();
    final orchestrator = _FakeRoomSyncOrchestrator();
    final starter = _FakeRoomSessionStarter();

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

    realParty = PartyRoomService(
      replicaId: rep,
      clock: clock,
      roomDocumentPort: port,
      diceRoomService: diceService,
    );
    sl.registerSingleton<PartyRoomService>(realParty);
  });

  tearDown(() {
    CampaignRegistryService.resetInstanceForTesting();
    repo.dispose();
    resetTestServices();
    sl.reset();
  });

  group('JoinCreateRoomDialog campaign dropdown — Fix 1.4', () {
    final olderCampaign = CampaignMembership(
      roomCode: 'CAMP-OLD',
      campaignName: 'Sunken Citadel',
      lastPlayed: DateTime.utc(2026, 10, 1, 12, 0),
    );
    final newerCampaign = CampaignMembership(
      roomCode: 'CAMP-NEW',
      campaignName: 'Iron Keep',
      lastPlayed: DateTime.utc(2026, 11, 1, 12, 0),
    );

    testWidgets(
      'Dialog with two memberships shows both entries in "Your campaigns", newest lastPlayed first',
      (tester) async {
        // Pass older first, newer second to verify sorting by lastPlayed descending.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JoinCreateRoomDialog(
                campaigns: [olderCampaign, newerCampaign],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Shared Dice Room'), findsOneWidget);
        expect(find.text('Your campaigns'), findsOneWidget);

        // Dropdown is above the Room Code field.
        final dropdownTop = tester.getTopLeft(find.text('Your campaigns')).dy;
        final roomCodeTop =
            tester.getTopLeft(find.widgetWithText(TextField, 'Room Code')).dy;
        expect(dropdownTop, lessThan(roomCodeTop));

        // Open dropdown and check ordering of entries (newest lastPlayed first).
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        final newestFinder = find.text('Iron Keep (CAMP-NEW)').last;
        final olderFinder = find.text('Sunken Citadel (CAMP-OLD)').last;
        expect(newestFinder, findsOneWidget);
        expect(olderFinder, findsOneWidget);
        expect(
          tester.getTopLeft(newestFinder).dy,
          lessThan(tester.getTopLeft(olderFinder).dy),
          reason: 'Newest lastPlayed campaign must appear first in dropdown',
        );
      },
    );

    testWidgets(
      'Choosing the second entry puts its code in the Room Code field',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JoinCreateRoomDialog(
                campaigns: [olderCampaign, newerCampaign],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the "Your campaigns" dropdown and select the second entry ('Sunken Citadel (CAMP-OLD)').
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sunken Citadel (CAMP-OLD)').last);
        await tester.pumpAndSettle();

        final roomCodeField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Room Code'),
        );
        expect(roomCodeField.controller?.text, equals('CAMP-OLD'));
      },
    );

    testWidgets(
      'With an empty campaigns list, there is no "Your campaigns" widget',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: JoinCreateRoomDialog(
                campaigns: [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Shared Dice Room'), findsOneWidget);
        expect(find.text('Your campaigns'), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.widgetWithText(TextField, 'Room Code'), findsOneWidget);
      },
    );

    testWidgets(
      'End to end: banner with real opener, membership Night Watch (CAMP-NW1), local profile cmp_nw claiming CAMP-NW1, and a different active profile',
      (tester) async {
        final otherProfile = _makeProfile(
          id: 'cmp_other',
          roomCode: 'CAMP-OTHER',
          name: 'Other Campaign',
        );
        final nwProfile = _makeProfile(
          id: 'cmp_nw',
          roomCode: 'CAMP-NW1',
          name: 'Night Watch',
        );
        repo.seedProfile(otherProfile);
        repo.seedProfile(nwProfile);
        repo.seedActiveId('cmp_other');

        await CampaignRegistryService().saveMembership(
          CampaignMembership(
            roomCode: 'CAMP-NW1',
            campaignName: 'Night Watch',
            lastPlayed: DateTime.utc(2026, 11, 10, 18, 0),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoomBannerWidget(roomService: diceService),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Join Room on the banner.
        await tester.tap(find.text('Join Room'));
        await tester.pumpAndSettle();

        // Choose Night Watch (CAMP-NW1) from "Your campaigns".
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Night Watch (CAMP-NW1)').last);
        await tester.pumpAndSettle();

        // Type a player name and tap Enter Room.
        await tester.enterText(
          find.widgetWithText(TextField, 'Your Display Name'),
          'Valen',
        );
        await tester.tap(find.text('Enter Room'));
        await tester.pumpAndSettle();

        expect(repo.activeProfileId, equals('cmp_nw'));
        expect(diceService.activeRoomCode, equals('CAMP-NW1'));
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
