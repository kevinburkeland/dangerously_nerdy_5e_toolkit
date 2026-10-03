import 'dart:async';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_animated_object_adapter.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedObjectStats.defaultProvider = Dnd5eAnimatedObjectAdapter.getStats;
  if (!sl.isRegistered<ReplicaId>()) {
    sl.registerSingleton<ReplicaId>(ReplicaId('test_runner_replica'));
  }
  await testMain();
}
