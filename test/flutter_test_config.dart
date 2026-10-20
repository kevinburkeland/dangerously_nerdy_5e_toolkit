import 'dart:async';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'test_doubles/fake_room_document_port.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installRulesetCatalog();
  if (!sl.isRegistered<ReplicaId>()) {
    sl.registerSingleton<ReplicaId>(ReplicaId('test_runner_replica'));
  }
  if (!sl.isRegistered<StatefulHlcClock>()) {
    sl.registerSingleton<StatefulHlcClock>(
      StatefulHlcClock(replicaId: sl<ReplicaId>()),
    );
  }
  if (!sl.isRegistered<IRoomDocumentPort>()) {
    sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
  }
  await testMain();
}
