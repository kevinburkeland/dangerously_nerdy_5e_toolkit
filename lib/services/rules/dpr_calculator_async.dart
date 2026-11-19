import 'package:flutter/foundation.dart';

import '../../models/dpr/dpr_models.dart';
import 'dpr_calculator_engine.dart';

export 'dpr_calculator_engine.dart';

DprCurveData _isolateCurveRunner(_DprCurvePayload payload) {
  return DprCalculatorEngine.generateCurve(
    payload.profile,
    advantageOverride: payload.advantageOverride,
    minAc: payload.minAc,
    maxAc: payload.maxAc,
  );
}

DprBreakEvenAnalysis _isolateBreakEvenRunner(_DprBreakEvenPayload payload) {
  return DprCalculatorEngine.calculatePowerAttackBreakEven(
    payload.profile,
    advantage: payload.advantage,
    minAc: payload.minAc,
    maxAc: payload.maxAc,
  );
}

/// Offloads DPR curve computation across ACs to a background isolate.
Future<DprCurveData> generateCurveAsync(
  DprCombatantProfile profile, {
  AdvantageType? advantageOverride,
  int minAc = 5,
  int maxAc = 30,
}) {
  final payload = _DprCurvePayload(
    profile: profile,
    advantageOverride: advantageOverride,
    minAc: minAc,
    maxAc: maxAc,
  );
  return compute(_isolateCurveRunner, payload);
}

/// Offloads Power Attack break-even analysis to a background isolate.
Future<DprBreakEvenAnalysis> calculatePowerAttackBreakEvenAsync(
  DprCombatantProfile baselineProfile, {
  AdvantageType? advantage,
  int minAc = 5,
  int maxAc = 30,
}) {
  final payload = _DprBreakEvenPayload(
    profile: baselineProfile,
    advantage: advantage,
    minAc: minAc,
    maxAc: maxAc,
  );
  return compute(_isolateBreakEvenRunner, payload);
}

/// Backwards-compatible alias for [calculatePowerAttackBreakEvenAsync].
Future<DprBreakEvenAnalysis> calculateGwmBreakEvenAsync(
  DprCombatantProfile baselineProfile, {
  AdvantageType? advantage,
  int minAc = 5,
  int maxAc = 30,
}) =>
    calculatePowerAttackBreakEvenAsync(
      baselineProfile,
      advantage: advantage,
      minAc: minAc,
      maxAc: maxAc,
    );

class _DprCurvePayload {
  final DprCombatantProfile profile;
  final AdvantageType? advantageOverride;
  final int minAc;
  final int maxAc;

  const _DprCurvePayload({
    required this.profile,
    this.advantageOverride,
    required this.minAc,
    required this.maxAc,
  });
}

class _DprBreakEvenPayload {
  final DprCombatantProfile profile;
  final AdvantageType? advantage;
  final int minAc;
  final int maxAc;

  const _DprBreakEvenPayload({
    required this.profile,
    this.advantage,
    required this.minAc,
    required this.maxAc,
  });
}
