import 'dart:async';
import 'package:vtt_engine_core/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_animated_object_adapter.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedObjectStats.defaultProvider = Dnd5eAnimatedObjectAdapter.getStats;
  await testMain();
}
