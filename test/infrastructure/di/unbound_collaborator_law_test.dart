import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';

import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/service_test_configurator.dart';

class _RecordingBlobStore extends FakeBlobStore {
  final List<String> releasedCampaignIds = [];

  @override
  Future<void> releaseCampaign(String campaignId) async {
    releasedCampaignIds.add(campaignId);
    await super.releaseCampaign(campaignId);
  }
}

class _RecordingCampaignRepository extends FakeCampaignRepository {
  int updateProfileCalls = 0;
  int putProfileCalls = 0;

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    updateProfileCalls++;
    return super.updateProfile(id, transform);
  }

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    putProfileCalls++;
    await super.putProfile(profile);
  }
}

class _RecordingTransport implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final List<({String roomCode, String localNodeId})> initializedRooms = [];
  int disconnectCalls = 0;

  @override
  TransportState get currentState => TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      true;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    initializedRooms.add((roomCode: roomCode, localNodeId: localNodeId));
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => const Stream.empty();

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

class UnboundLawRow {
  final String service;
  final String member;
  final String collaboratorType;
  final bool isNewInstance;
  final FutureOr<Object?> Function(DiceRoomService? instance) call;

  const UnboundLawRow({
    required this.service,
    required this.member,
    required this.collaboratorType,
    this.isNewInstance = false,
    required this.call,
  });
}

/// Strips comments and string literals while preserving line structure and braces.
String _stripCommentsAndStrings(String source) {
  final buf = StringBuffer();
  int i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        buf.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      buf.write('  ');
      i += 2;
      while (i < n && !(source[i] == '*' && i + 1 < n && source[i + 1] == '/')) {
        buf.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < n) {
        buf.write('  ');
        i += 2;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      if (isTriple) {
        buf.write('   ');
        i += 3;
        while (i < n &&
            !(i + 2 < n &&
                source[i] == quote &&
                source[i + 1] == quote &&
                source[i + 2] == quote)) {
          if (source[i] == r'\' && i + 1 < n) {
            buf.write('  ');
            i += 2;
            continue;
          }
          buf.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
        if (i < n) {
          buf.write('   ');
          i += 3;
        }
      } else {
        buf.write(' ');
        i++;
        while (i < n && source[i] != quote && source[i] != '\n') {
          if (source[i] == r'\' && i + 1 < n) {
            buf.write('  ');
            i += 2;
            continue;
          }
          buf.write(' ');
          i++;
        }
        if (i < n && source[i] == quote) {
          buf.write(' ');
          i++;
        }
      }
      continue;
    }
    buf.write(c);
    i++;
  }
  return buf.toString();
}

/// Finds every public member (not starting with `_`) of [className] in [source]
/// whose body calls a `_require...()` getter.
Set<(String, String)> extractPublicMembersCallingRequire(
  String source,
  String className,
) {
  final stripped = _stripCommentsAndStrings(source);
  final classMatch = RegExp('\\bclass\\s+$className\\b').firstMatch(stripped);
  if (classMatch == null) {
    throw StateError('Class $className not found');
  }
  int idx = stripped.indexOf('{', classMatch.end);
  if (idx == -1) {
    throw StateError('Opening brace for $className not found');
  }
  final classStart = idx + 1;
  int depth = 1;
  int p = classStart;
  while (p < stripped.length && depth > 0) {
    final ch = stripped[p];
    if (ch == '{') depth++;
    if (ch == '}') depth--;
    p++;
  }
  final classBody = stripped.substring(classStart, p - 1);

  final results = <(String, String)>{};
  int i = 0;
  final len = classBody.length;
  int braceDepth = 0;
  int parenDepth = 0;
  int stmtStart = 0;

  while (i < len) {
    final ch = classBody[i];
    if (ch == '(' && braceDepth == 0) {
      parenDepth++;
      i++;
      continue;
    }
    if (ch == ')' && braceDepth == 0) {
      if (parenDepth > 0) parenDepth--;
      i++;
      continue;
    }
    if (ch == ';' && braceDepth == 0 && parenDepth == 0) {
      final stmt = classBody.substring(stmtStart, i + 1);
      final arrowIdx = stmt.indexOf('=>');
      if (arrowIdx != -1) {
        final header = stmt.substring(0, arrowIdx);
        final body = stmt.substring(arrowIdx + 2);
        final name = _extractPublicMemberName(header, className);
        if (name != null && RegExp(r'\b_require\w+\s*\(').hasMatch(body)) {
          results.add((className, name));
        }
      }
      stmtStart = i + 1;
      i++;
      continue;
    }
    if (ch == '{' && parenDepth == 0) {
      if (braceDepth == 0) {
        final header = classBody.substring(stmtStart, i);
        final bodyStart = i + 1;
        braceDepth = 1;
        i++;
        while (i < len && braceDepth > 0) {
          if (classBody[i] == '{') braceDepth++;
          if (classBody[i] == '}') braceDepth--;
          i++;
        }
        final body = classBody.substring(bodyStart, i - 1);
        final name = _extractPublicMemberName(header, className);
        if (name != null && RegExp(r'\b_require\w+\s*\(').hasMatch(body)) {
          results.add((className, name));
        }
        stmtStart = i;
        continue;
      }
    }
    i++;
  }

  return results;
}

String? _extractPublicMemberName(String header, String className) {
  final clean = header.trim();
  if (clean.isEmpty) return null;
  if (clean.contains('=')) {
    // Field initializer like `final x = () { ... }`
    final eqIdx = clean.indexOf('=');
    final beforeEq = clean.substring(0, eqIdx);
    if (!beforeEq.contains('(')) return null;
  }

  // Getter: `Type get foo`
  final getterMatch = RegExp(r'\bget\s+([A-Za-z_]\w*)\s*$').firstMatch(clean);
  if (getterMatch != null) {
    final name = getterMatch.group(1)!;
    if (name.startsWith('_')) return null;
    return name;
  }

  // Method or constructor: `... foo(...)`
  final parenIdx = clean.indexOf('(');
  if (parenIdx == -1) return null;
  final beforeParen = clean.substring(0, parenIdx).trim();
  final tokens = beforeParen.split(RegExp(r'\s+'));
  if (tokens.isEmpty) return null;
  final lastToken = tokens.last;
  // Ignore constructors (`ClassName`, `ClassName.named`, `factory ClassName`)
  if (lastToken == className || lastToken.startsWith('$className.')) {
    return null;
  }
  final nameMatch = RegExp(r'^([A-Za-z_]\w*)').firstMatch(lastToken);
  if (nameMatch == null) return null;
  final name = nameMatch.group(1)!;
  if (name.startsWith('_')) return null;
  return name;
}

/// Checks completeness between source files and the law table; returns error message or null.
String? checkUnboundLawCompleteness({
  required Map<String, String> sourceByClassName,
  required Set<(String, String)> tableSet,
}) {
  final sourceSet = <(String, String)>{};
  for (final entry in sourceByClassName.entries) {
    sourceSet.addAll(
      extractPublicMembersCallingRequire(entry.value, entry.key),
    );
  }
  if (sourceSet.length != tableSet.length || !sourceSet.containsAll(tableSet)) {
    final missingFromTable = sourceSet.difference(tableSet);
    final extraInTable = tableSet.difference(sourceSet);
    return 'Unbound collaborator law table mismatch!\n'
        'Source set (${sourceSet.length}): $sourceSet\n'
        'Table set (${tableSet.length}): $tableSet\n'
        'Missing from table: $missingFromTable\n'
        'Extra in table: $extraInTable';
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyTimestamp = HybridLogicalClock(
    physicalTime: 1000,
    logicalCounter: 0,
    nodeId: 'test_node',
  );
  final sampleProfile = CampaignProfile.defaultProfile(
    id: 'camp_law_1',
    name: 'Law Test Campaign',
    edition: DmRulesEdition.v2024,
    nodeId: 'test_node',
    timestamp: dummyTimestamp,
  ).copyWith(
    partyCharacterIds: const ['hero_law_1'],
    roomState: RoomNodeState.fromLists(
      roomId: 'room_law_1',
      roomCode: 'LAW1',
      title: 'Law Room',
      description: 'Desc',
    ),
  );

  final sampleRoll = RoomRoll(
    id: 'roll_law_1',
    roomCode: 'LAW1',
    playerName: 'Tester',
    formulaString: '1d20',
    total: 15,
    individualRolls: const [15],
    isCrit: false,
    isFumble: false,
    timestamp: DateTime.utc(2026),
  );

  final validProfileSnapshotJson = jsonEncode({
    'schemaVersion': 1,
    'appVersion': '1.0.0',
    'type': 'campaign_profile',
    'campaign': CampaignProfileDto.fromDomain(sampleProfile).toMap(),
  });

  final validSystemSnapshotJson = jsonEncode({
    'schemaVersion': 1,
    'appVersion': '1.0.0',
    'type': 'full_system_snapshot',
    'campaignProfiles': [
      CampaignProfileDto.fromDomain(sampleProfile).toMap(),
    ],
  });

  final List<UnboundLawRow> lawRows = [
    // CampaignProfileService (17 public members)
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'activeProfileId',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().activeProfileId,
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'activeProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().activeProfile,
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'repo',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().repo,
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'allProfiles',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().allProfiles,
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'loadAllProfiles',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().loadAllProfiles(),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'getProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().getProfile('camp_law_1'),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'getActiveProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().getActiveProfile(),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'createProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().createProfile(name: 'New Camp'),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'updateProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().updateProfile(
        'camp_law_1',
        (c) => c.copyWith(
          name: 'Updated Name',
          nameTimestamp: dummyTimestamp,
        ),
      ),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'putProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().putProfile(sampleProfile),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'updateActiveProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().updateActiveProfile(
        (c) => c.copyWith(
          name: 'Active Updated',
          nameTimestamp: dummyTimestamp,
        ),
      ),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'saveProfileImmediate',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().saveProfileImmediate(sampleProfile),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'switchProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().switchProfile('camp_law_1'),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'setActiveProfileId',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().setActiveProfileId('camp_law_1'),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'cloneProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) =>
          CampaignProfileService().cloneProfile('camp_law_1', 'Cloned'),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'deleteProfile',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().deleteProfile('camp_law_1'),
    ),
    UnboundLawRow(
      service: 'CampaignProfileService',
      member: 'logCampaignEvent',
      collaboratorType: 'ICampaignRepository',
      call: (_) => CampaignProfileService().logCampaignEvent(
        characterId: 'hero_law_1',
        characterName: 'Hero',
        type: 'test_event',
        details: 'Event details',
        roomCode: 'LAW1',
      ),
    ),

    // DmBackupService (2 public members)
    UnboundLawRow(
      service: 'DmBackupService',
      member: 'validateAndImportProfile',
      collaboratorType: 'StatefulHlcClock',
      call: (_) =>
          DmBackupService().validateAndImportProfile(validProfileSnapshotJson),
    ),
    UnboundLawRow(
      service: 'DmBackupService',
      member: 'restoreFullSystemSnapshot',
      collaboratorType: 'StatefulHlcClock',
      call: (_) =>
          DmBackupService().restoreFullSystemSnapshot(validSystemSnapshotJson),
    ),

    // DiceRoomService singleton (5 public members)
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'restorePersistedSession',
      collaboratorType: 'IP2pTransportPort',
      call: (_) => DiceRoomService().restorePersistedSession(),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'joinRoom',
      collaboratorType: 'IP2pTransportPort',
      call: (_) => DiceRoomService().joinRoom('LAW1', 'Tester', remember: false),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'leaveRoom',
      collaboratorType: 'RoomSyncOrchestrator',
      call: (_) => DiceRoomService().leaveRoom(),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'leaveRoomAsync',
      collaboratorType: 'RoomSyncOrchestrator',
      call: (_) => DiceRoomService().leaveRoomAsync(),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'broadcastRoll',
      collaboratorType: 'IP2pTransportPort',
      call: (_) => DiceRoomService().broadcastRoll(sampleRoll),
    ),

    // DiceRoomService.newInstance() (5 public members — singleton configured first!)
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'restorePersistedSession',
      collaboratorType: 'IP2pTransportPort',
      isNewInstance: true,
      call: (inst) => inst!.restorePersistedSession(),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'joinRoom',
      collaboratorType: 'IP2pTransportPort',
      isNewInstance: true,
      call: (inst) => inst!.joinRoom('LAW1', 'Tester', remember: false),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'leaveRoom',
      collaboratorType: 'RoomSyncOrchestrator',
      isNewInstance: true,
      call: (inst) => inst!.leaveRoom(),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'leaveRoomAsync',
      collaboratorType: 'RoomSyncOrchestrator',
      isNewInstance: true,
      call: (inst) => inst!.leaveRoomAsync(),
    ),
    UnboundLawRow(
      service: 'DiceRoomService',
      member: 'broadcastRoll',
      collaboratorType: 'IP2pTransportPort',
      isNewInstance: true,
      call: (inst) => inst!.broadcastRoll(sampleRoll),
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'dice_room_persisted_remember': true,
      'dice_room_persisted_code': 'LAW1',
      'dice_room_persisted_player_name': 'Tester',
    });
    resetTestServices();
  });

  tearDown(() {
    resetTestServices();
  });

  group('Unbound Collaborator Law', () {
    test('Source completeness check matches law table and in-memory control fails on missing member', () {
      // 1. In-memory control: class with 2 public methods calling _requireFoo() and 1 that does not
      const sampleClassSource = '''
class SampleService {
  Foo? _foo;
  Foo _requireFoo() {
    final f = _foo;
    if (f != null) return f;
    throw StateError('SampleService has no Foo bound. Call initServiceLocator().');
  }
  void alpha() {
    final f = _requireFoo();
    f.doWork();
  }
  Future<void> beta() async {
    final f = _requireFoo();
    await f.doAsync();
  }
  int gamma() {
    return 42;
  }
  void _privateHelper() {
    _requireFoo();
  }
}
''';
      final controlError = checkUnboundLawCompleteness(
        sourceByClassName: {'SampleService': sampleClassSource},
        tableSet: {('SampleService', 'alpha')},
      );
      expect(controlError, isNotNull);
      expect(controlError, contains('beta'));

      final controlClean = checkUnboundLawCompleteness(
        sourceByClassName: {'SampleService': sampleClassSource},
        tableSet: {
          ('SampleService', 'alpha'),
          ('SampleService', 'beta'),
        },
      );
      expect(controlClean, isNull);

      // 2. Real service files check
      final campaignProfileSource =
          File('lib/services/persistence/campaign_profile_service.dart')
              .readAsStringSync();
      final dmBackupSource =
          File('lib/services/persistence/dm_backup_service.dart')
              .readAsStringSync();
      final diceRoomSource =
          File('lib/services/dice_room_service.dart').readAsStringSync();

      final tableSet = <(String, String)>{
        for (final row in lawRows) (row.service, row.member),
      };

      final realMismatch = checkUnboundLawCompleteness(
        sourceByClassName: {
          'CampaignProfileService': campaignProfileSource,
          'DmBackupService': dmBackupSource,
          'DiceRoomService': diceRoomSource,
        },
        tableSet: tableSet,
      );
      if (realMismatch != null) {
        fail(realMismatch);
      }

      debugPrint('=== Unbound Collaborator Law Table (${lawRows.length} rows, ${tableSet.length} unique (service, member) pairs) ===');
      for (final row in lawRows) {
        final target = row.isNewInstance ? '${row.service}.newInstance()' : row.service;
        debugPrint('  $target.${row.member} -> requires ${row.collaboratorType}');
      }
    });

    for (final row in lawRows) {
      final targetLabel =
          row.isNewInstance ? '${row.service}.newInstance()' : row.service;
      test(
          'Row: $targetLabel.${row.member} throws StateError naming ${row.collaboratorType} and initServiceLocator when unbound, and succeeds when bound',
          () async {
        // 1. Unbound check
        resetTestServices();
        DiceRoomService? unboundInstance;
        if (row.isNewInstance) {
          // Configure singleton with fakes first so borrowing from _instance would NOT throw!
          configureTestDiceRoomService(transport: _RecordingTransport());
          unboundInstance = DiceRoomService.newInstance();
        }

        Object? caughtError;
        try {
          await row.call(unboundInstance);
        } catch (e) {
          caughtError = e;
        }

        expect(
          caughtError,
          isA<StateError>(),
          reason:
              '$targetLabel.${row.member} must throw StateError when ${row.collaboratorType} is unbound',
        );
        final message = (caughtError as StateError).message;
        expect(message, contains(row.service));
        expect(message, contains(row.collaboratorType));
        expect(message, contains('initServiceLocator'));

        // 2. Control check (bound with fakes)
        resetTestServices();
        final fakeRepo = _RecordingCampaignRepository();
        await fakeRepo.putProfile(sampleProfile);
        await fakeRepo.setActiveProfileId(sampleProfile.id);
        fakeRepo.putProfileCalls = 0;
        fakeRepo.updateProfileCalls = 0;

        final repId = ReplicaId('law_control_node');
        final clock = StatefulHlcClock(
          replicaId: repId,
          timeProvider: () => 1700000000000,
        );
        final fakeBlobStore = _RecordingBlobStore();
        final fakeRegistry = CampaignRegistryService.newInstance();
        final fakeTransport = _RecordingTransport();
        final fakeOrch = NoOpRoomSyncOrchestrator();
        final fakeStarter = NoOpRoomSessionStarter(fakeOrch);

        CampaignProfileService.configure(
          repository: fakeRepo,
          clock: clock,
          replicaId: repId,
          registryService: fakeRegistry,
          blobStoreProvider: () => fakeBlobStore,
        );
        DmBackupService.configure(clock: clock);

        DiceRoomService? boundInstance;
        if (row.isNewInstance) {
          boundInstance = DiceRoomService.newInstance()
            ..bind(
              transport: fakeTransport,
              orchestrator: fakeOrch,
              sessionStarter: fakeStarter,
            );
        } else {
          DiceRoomService.configure(
            transport: fakeTransport,
            orchestrator: fakeOrch,
            sessionStarter: fakeStarter,
          );
        }

        await row.call(boundInstance);

        // Verify work reached the fake for representative rows per service
        if (row.service == 'CampaignProfileService' &&
            row.member == 'updateProfile') {
          expect(fakeRepo.updateProfileCalls, equals(1));
        }
        if (row.service == 'CampaignProfileService' &&
            row.member == 'logCampaignEvent') {
          expect(fakeRepo.updateProfileCalls, equals(1));
        }
        if (row.service == 'CampaignProfileService' &&
            row.member == 'deleteProfile') {
          expect(fakeBlobStore.releasedCampaignIds, contains('camp_law_1'));
        }
        if (row.service == 'DmBackupService' &&
            row.member == 'validateAndImportProfile') {
          expect(fakeRepo.putProfileCalls, greaterThanOrEqualTo(1));
        }
        if (row.service == 'DiceRoomService' &&
            row.member == 'broadcastRoll') {
          expect(fakeTransport.broadcastedPayloads.length, equals(1));
        }
      });
    }

    test('Secondary collaborator checks on CampaignProfileService (StatefulHlcClock, ReplicaId, CampaignRegistryService, BlobStorePort)', () async {
      final fakeRepo = _RecordingCampaignRepository();
      await fakeRepo.putProfile(sampleProfile);
      await fakeRepo.setActiveProfileId(sampleProfile.id);
      final repId = ReplicaId('law_secondary_node');
      final clock = StatefulHlcClock(replicaId: repId);
      final fakeRegistry = CampaignRegistryService.newInstance();
      final fakeBlobStore = _RecordingBlobStore();

      // Configure all, then resetForTesting clears _clock and _replicaId while leaving _repository bound
      CampaignProfileService.configure(
        repository: fakeRepo,
        clock: clock,
        replicaId: repId,
        registryService: fakeRegistry,
        blobStoreProvider: () => fakeBlobStore,
      );
      CampaignProfileService.resetForTesting();

      expect(
        () => CampaignProfileService().createProfile(name: 'Test'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('CampaignProfileService'),
              contains('StatefulHlcClock'),
              contains('initServiceLocator'),
            ),
          ),
        ),
      );
    });
  });
}
