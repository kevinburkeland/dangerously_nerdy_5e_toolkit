import 'dart:convert';
import '../crdt/pn_counter.dart';

/// Represents party coin purse denominations with conversion and splitting math,
/// backed by PN-Counter CvRDT vectors for conflict-free distributed convergence.
class PartyPurse {
  final int cp;
  final int sp;
  final int ep;
  final int gp;
  final int pp;
  final PnCounter cpCounter;
  final PnCounter spCounter;
  final PnCounter epCounter;
  final PnCounter gpCounter;
  final PnCounter ppCounter;

  const PartyPurse({
    this.cp = 0,
    this.sp = 0,
    this.ep = 0,
    this.gp = 0,
    this.pp = 0,
    this.cpCounter = const PnCounter(),
    this.spCounter = const PnCounter(),
    this.epCounter = const PnCounter(),
    this.gpCounter = const PnCounter(),
    this.ppCounter = const PnCounter(),
  });

  /// Effective PN-counters guaranteeing starting balance is preserved in CRDT vectors.
  PnCounter get effectiveCpCounter =>
      cpCounter.positive.isNotEmpty || cpCounter.negative.isNotEmpty
          ? cpCounter
          : (cp > 0 ? PnCounter.withInitialValue(cp) : const PnCounter());

  PnCounter get effectiveSpCounter =>
      spCounter.positive.isNotEmpty || spCounter.negative.isNotEmpty
          ? spCounter
          : (sp > 0 ? PnCounter.withInitialValue(sp) : const PnCounter());

  PnCounter get effectiveEpCounter =>
      epCounter.positive.isNotEmpty || epCounter.negative.isNotEmpty
          ? epCounter
          : (ep > 0 ? PnCounter.withInitialValue(ep) : const PnCounter());

  PnCounter get effectiveGpCounter =>
      gpCounter.positive.isNotEmpty || gpCounter.negative.isNotEmpty
          ? gpCounter
          : (gp > 0 ? PnCounter.withInitialValue(gp) : const PnCounter());

  PnCounter get effectivePpCounter =>
      ppCounter.positive.isNotEmpty || ppCounter.negative.isNotEmpty
          ? ppCounter
          : (pp > 0 ? PnCounter.withInitialValue(pp) : const PnCounter());

  /// Total gold piece equivalent (1 PP = 10 GP, 1 EP = 0.5 GP, 1 SP = 0.1 GP, 1 CP = 0.01 GP)
  double get totalGpEquivalent =>
      (pp * 10.0) + gp.toDouble() + (ep * 0.5) + (sp * 0.1) + (cp * 0.01);

  /// Total raw count of all physical coins regardless of denomination (for weight calculations: 50 coins = 1 lb)
  int get totalCoins => cp + sp + ep + gp + pp;

  bool get isEmpty => cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0;

  PartyPurse copyWith({
    int? cp,
    int? sp,
    int? ep,
    int? gp,
    int? pp,
    PnCounter? cpCounter,
    PnCounter? spCounter,
    PnCounter? epCounter,
    PnCounter? gpCounter,
    PnCounter? ppCounter,
  }) {
    final resolvedCp = cp ?? (cpCounter != null ? cpCounter.value : this.cp);
    final resolvedSp = sp ?? (spCounter != null ? spCounter.value : this.sp);
    final resolvedEp = ep ?? (epCounter != null ? epCounter.value : this.ep);
    final resolvedGp = gp ?? (gpCounter != null ? gpCounter.value : this.gp);
    final resolvedPp = pp ?? (ppCounter != null ? ppCounter.value : this.pp);

    return PartyPurse(
      cp: resolvedCp,
      sp: resolvedSp,
      ep: resolvedEp,
      gp: resolvedGp,
      pp: resolvedPp,
      cpCounter: cpCounter ?? (cp != null ? PnCounter.withInitialValue(cp) : this.cpCounter),
      spCounter: spCounter ?? (sp != null ? PnCounter.withInitialValue(sp) : this.spCounter),
      epCounter: epCounter ?? (ep != null ? PnCounter.withInitialValue(ep) : this.epCounter),
      gpCounter: gpCounter ?? (gp != null ? PnCounter.withInitialValue(gp) : this.gpCounter),
      ppCounter: ppCounter ?? (pp != null ? PnCounter.withInitialValue(pp) : this.ppCounter),
    );
  }

  /// Merges another purse using CvRDT lattice join over PN-counters across all denominations.
  PartyPurse merge(PartyPurse other) {
    final mergedCp = effectiveCpCounter.merge(other.effectiveCpCounter);
    final mergedSp = effectiveSpCounter.merge(other.effectiveSpCounter);
    final mergedEp = effectiveEpCounter.merge(other.effectiveEpCounter);
    final mergedGp = effectiveGpCounter.merge(other.effectiveGpCounter);
    final mergedPp = effectivePpCounter.merge(other.effectivePpCounter);

    return PartyPurse(
      cp: mergedCp.value,
      sp: mergedSp.value,
      ep: mergedEp.value,
      gp: mergedGp.value,
      pp: mergedPp.value,
      cpCounter: mergedCp,
      spCounter: mergedSp,
      epCounter: mergedEp,
      gpCounter: mergedGp,
      ppCounter: mergedPp,
    );
  }

  /// Adds another purse's coins to this purse
  PartyPurse add(PartyPurse other, {String nodeId = 'local'}) {
    return depositCoins(
      cp: other.cp,
      sp: other.sp,
      ep: other.ep,
      gp: other.gp,
      pp: other.pp,
      nodeId: nodeId,
    );
  }

  /// Deducts another purse's coins, clamped at zero
  PartyPurse deduct(PartyPurse other, {String nodeId = 'local'}) {
    return withdrawCoins(
      cp: other.cp,
      sp: other.sp,
      ep: other.ep,
      gp: other.gp,
      pp: other.pp,
      nodeId: nodeId,
    );
  }

  /// Atomically deducts a cost denominated in GP equivalent, making change
  /// and repacking into optimal coin denominations (PP -> GP -> EP -> SP -> CP).
  ///
  /// Throws [StateError] if total purse value in GP is less than [costGp].
  PartyPurse deductGpEquivalent(double costGp, {String nodeId = 'local'}) {
    if (costGp <= 0) return this;
    final costInCp = (costGp * 100).round();
    int balanceInCp = (pp * 1000) + (gp * 100) + (ep * 50) + (sp * 10) + cp;

    if (balanceInCp < costInCp) {
      throw StateError('Insufficient funds: purse has $totalGpEquivalent GP, needed $costGp GP');
    }

    balanceInCp -= costInCp;

    // Re-pack into optimal coin denominations (highest denomination first)
    final newPp = balanceInCp ~/ 1000;
    balanceInCp %= 1000;

    final newGp = balanceInCp ~/ 100;
    balanceInCp %= 100;

    final newEp = balanceInCp ~/ 50;
    balanceInCp %= 50;

    final newSp = balanceInCp ~/ 10;
    final newCp = balanceInCp % 10;

    PnCounter applyDiff(PnCounter counter, int diff) {
      if (diff > 0) return counter.increment(diff, nodeId: nodeId);
      if (diff < 0) return counter.decrement(-diff, nodeId: nodeId);
      return counter;
    }

    final newCpC = applyDiff(effectiveCpCounter, newCp - cp);
    final newSpC = applyDiff(effectiveSpCounter, newSp - sp);
    final newEpC = applyDiff(effectiveEpCounter, newEp - ep);
    final newGpC = applyDiff(effectiveGpCounter, newGp - gp);
    final newPpC = applyDiff(effectivePpCounter, newPp - pp);

    return PartyPurse(
      pp: newPp,
      gp: newGp,
      ep: newEp,
      sp: newSp,
      cp: newCp,
      cpCounter: newCpC,
      spCounter: newSpC,
      epCounter: newEpC,
      gpCounter: newGpC,
      ppCounter: newPpC,
    );
  }

  /// Deposits coin increments (never reducing below 0)
  PartyPurse depositCoins({
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String nodeId = 'local',
  }) {
    final newCpCounter = cp > 0 ? effectiveCpCounter.increment(cp, nodeId: nodeId) : effectiveCpCounter;
    final newSpCounter = sp > 0 ? effectiveSpCounter.increment(sp, nodeId: nodeId) : effectiveSpCounter;
    final newEpCounter = ep > 0 ? effectiveEpCounter.increment(ep, nodeId: nodeId) : effectiveEpCounter;
    final newGpCounter = gp > 0 ? effectiveGpCounter.increment(gp, nodeId: nodeId) : effectiveGpCounter;
    final newPpCounter = pp > 0 ? effectivePpCounter.increment(pp, nodeId: nodeId) : effectivePpCounter;

    return PartyPurse(
      cp: newCpCounter.value,
      sp: newSpCounter.value,
      ep: newEpCounter.value,
      gp: newGpCounter.value,
      pp: newPpCounter.value,
      cpCounter: newCpCounter,
      spCounter: newSpCounter,
      epCounter: newEpCounter,
      gpCounter: newGpCounter,
      ppCounter: newPpCounter,
    );
  }

  /// Withdraws coin amounts, clamped at zero
  PartyPurse withdrawCoins({
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String nodeId = 'local',
  }) {
    final newCpCounter = cp > 0 ? effectiveCpCounter.decrement(cp, nodeId: nodeId) : effectiveCpCounter;
    final newSpCounter = sp > 0 ? effectiveSpCounter.decrement(sp, nodeId: nodeId) : effectiveSpCounter;
    final newEpCounter = ep > 0 ? effectiveEpCounter.decrement(ep, nodeId: nodeId) : effectiveEpCounter;
    final newGpCounter = gp > 0 ? effectiveGpCounter.decrement(gp, nodeId: nodeId) : effectiveGpCounter;
    final newPpCounter = pp > 0 ? effectivePpCounter.decrement(pp, nodeId: nodeId) : effectivePpCounter;

    return PartyPurse(
      cp: newCpCounter.value,
      sp: newSpCounter.value,
      ep: newEpCounter.value,
      gp: newGpCounter.value,
      pp: newPpCounter.value,
      cpCounter: newCpCounter,
      spCounter: newSpCounter,
      epCounter: newEpCounter,
      gpCounter: newGpCounter,
      ppCounter: newPpCounter,
    );
  }

  /// Modifies a single denomination by [delta] (positive for deposit, negative for withdrawal),
  /// routing directly through CvRDT [PnCounter] vectors for conflict-free convergence.
  PartyPurse modifyCoin(String denomination, int delta, {String nodeId = 'local'}) {
    if (delta == 0) return this;
    final clean = denomination.trim().toLowerCase();
    if (delta > 0) {
      return depositCoins(
        cp: clean == 'cp' ? delta : 0,
        sp: clean == 'sp' ? delta : 0,
        ep: clean == 'ep' ? delta : 0,
        gp: clean == 'gp' ? delta : 0,
        pp: clean == 'pp' ? delta : 0,
        nodeId: nodeId,
      );
    } else {
      return withdrawCoins(
        cp: clean == 'cp' ? -delta : 0,
        sp: clean == 'sp' ? -delta : 0,
        ep: clean == 'ep' ? -delta : 0,
        gp: clean == 'gp' ? -delta : 0,
        pp: clean == 'pp' ? -delta : 0,
        nodeId: nodeId,
      );
    }
  }

  /// Calculates per-player split distribution and leftovers
  PartyPurseSplit splitShares(
    int playerCount, {
    bool includeLiquidatedGemsAndArt = false,
    double liquidatedGemsAndArtGp = 0.0,
  }) {
    if (playerCount <= 0) {
      return PartyPurseSplit(
        playerCount: 1,
        totalGpEquivalent: totalGpEquivalent,
        perPlayerGpEquivalent: totalGpEquivalent,
        cpPerPlayer: cp,
        spPerPlayer: sp,
        epPerPlayer: ep,
        gpPerPlayer: gp,
        ppPerPlayer: pp,
        remainderPurse: const PartyPurse(),
        liquidatedGemsAndArtIncluded: includeLiquidatedGemsAndArt,
      );
    }

    if (includeLiquidatedGemsAndArt) {
      final grandTotalGp = totalGpEquivalent + liquidatedGemsAndArtGp;
      final perPlayer = grandTotalGp / playerCount;
      final floorPerPlayer = perPlayer.floorToDouble();
      final remainder = grandTotalGp - (floorPerPlayer * playerCount);

      return PartyPurseSplit(
        playerCount: playerCount,
        totalGpEquivalent: grandTotalGp,
        perPlayerGpEquivalent: perPlayer,
        cpPerPlayer: 0,
        spPerPlayer: 0,
        epPerPlayer: 0,
        gpPerPlayer: floorPerPlayer.toInt(),
        ppPerPlayer: 0,
        remainderPurse: PartyPurse(gp: remainder.round()),
        liquidatedGemsAndArtIncluded: true,
      );
    }

    final ppEach = pp ~/ playerCount;
    final gpEach = gp ~/ playerCount;
    final epEach = ep ~/ playerCount;
    final spEach = sp ~/ playerCount;
    final cpEach = cp ~/ playerCount;

    final ppRem = pp % playerCount;
    final gpRem = gp % playerCount;
    final epRem = ep % playerCount;
    final spRem = sp % playerCount;
    final cpRem = cp % playerCount;

    final perPlayerGpEq = (ppEach * 10.0) + gpEach + (epEach * 0.5) + (spEach * 0.1) + (cpEach * 0.01);

    return PartyPurseSplit(
      playerCount: playerCount,
      totalGpEquivalent: totalGpEquivalent,
      perPlayerGpEquivalent: perPlayerGpEq,
      cpPerPlayer: cpEach,
      spPerPlayer: spEach,
      epPerPlayer: epEach,
      gpPerPlayer: gpEach,
      ppPerPlayer: ppEach,
      remainderPurse: PartyPurse(
        cp: cpRem,
        sp: spRem,
        ep: epRem,
        gp: gpRem,
        pp: ppRem,
      ),
      liquidatedGemsAndArtIncluded: false,
    );
  }

  Map<String, dynamic> toMap() {
    final effCp = effectiveCpCounter;
    final effSp = effectiveSpCounter;
    final effEp = effectiveEpCounter;
    final effGp = effectiveGpCounter;
    final effPp = effectivePpCounter;
    return {
      'cp': cp,
      'sp': sp,
      'ep': ep,
      'gp': gp,
      'pp': pp,
      if (effCp.positive.isNotEmpty || effCp.negative.isNotEmpty)
        'cpCounter': effCp.toMap(),
      if (effSp.positive.isNotEmpty || effSp.negative.isNotEmpty)
        'spCounter': effSp.toMap(),
      if (effEp.positive.isNotEmpty || effEp.negative.isNotEmpty)
        'epCounter': effEp.toMap(),
      if (effGp.positive.isNotEmpty || effGp.negative.isNotEmpty)
        'gpCounter': effGp.toMap(),
      if (effPp.positive.isNotEmpty || effPp.negative.isNotEmpty)
        'ppCounter': effPp.toMap(),
    };
  }

  factory PartyPurse.fromMap(Map<String, dynamic> map) {
    final hasCp = map.containsKey('cp');
    final hasSp = map.containsKey('sp');
    final hasEp = map.containsKey('ep');
    final hasGp = map.containsKey('gp');
    final hasPp = map.containsKey('pp');

    final cpVal = (map['cp'] as num?)?.toInt() ?? 0;
    final spVal = (map['sp'] as num?)?.toInt() ?? 0;
    final epVal = (map['ep'] as num?)?.toInt() ?? 0;
    final gpVal = (map['gp'] as num?)?.toInt() ?? 0;
    final ppVal = (map['pp'] as num?)?.toInt() ?? 0;

    PnCounter parseCounter(dynamic val, int scalarFallback) {
      if (val is Map) {
        try {
          final m = val.map((k, v) => MapEntry(k.toString(), v));
          return PnCounter.fromMap(m);
        } catch (_) {}
      }
      return scalarFallback > 0 ? PnCounter.withInitialValue(scalarFallback, nodeId: 'init') : const PnCounter();
    }

    var cpC = parseCounter(map['cpCounter'], cpVal);
    var spC = parseCounter(map['spCounter'], spVal);
    var epC = parseCounter(map['epCounter'], epVal);
    var gpC = parseCounter(map['gpCounter'], gpVal);
    var ppC = parseCounter(map['ppCounter'], ppVal);

    // If the map provides scalar keys and they differ from the counter (e.g. updated
    // by atomic FieldValue.increment in Firestore), the scalar reflects the latest
    // authoritative mutation. We adjust the existing counter via a deterministic 'cloud'
    // delta rather than wiping existing node vectors, strictly preserving CvRDT join idempotence.
    PnCounter reconcileScalarWithCounter(bool hasScalar, int scalar, PnCounter counter) {
      if (!hasScalar) return counter;
      if (scalar == counter.value) return counter;
      final diff = scalar - counter.value;
      return diff > 0
          ? counter.increment(diff, nodeId: 'cloud')
          : counter.decrement(-diff, nodeId: 'cloud');
    }

    cpC = reconcileScalarWithCounter(hasCp, cpVal, cpC);
    spC = reconcileScalarWithCounter(hasSp, spVal, spC);
    epC = reconcileScalarWithCounter(hasEp, epVal, epC);
    gpC = reconcileScalarWithCounter(hasGp, gpVal, gpC);
    ppC = reconcileScalarWithCounter(hasPp, ppVal, ppC);

    final finalCp = hasCp ? cpVal : (cpC.positive.isNotEmpty || cpC.negative.isNotEmpty ? cpC.value : cpVal);
    final finalSp = hasSp ? spVal : (spC.positive.isNotEmpty || spC.negative.isNotEmpty ? spC.value : spVal);
    final finalEp = hasEp ? epVal : (epC.positive.isNotEmpty || epC.negative.isNotEmpty ? epC.value : epVal);
    final finalGp = hasGp ? gpVal : (gpC.positive.isNotEmpty || gpC.negative.isNotEmpty ? gpC.value : gpVal);
    final finalPp = hasPp ? ppVal : (ppC.positive.isNotEmpty || ppC.negative.isNotEmpty ? ppC.value : ppVal);

    return PartyPurse(
      cp: finalCp,
      sp: finalSp,
      ep: finalEp,
      gp: finalGp,
      pp: finalPp,
      cpCounter: cpC,
      spCounter: spC,
      epCounter: epC,
      gpCounter: gpC,
      ppCounter: ppC,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PartyPurse.fromJson(String source) =>
      PartyPurse.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartyPurse &&
          runtimeType == other.runtimeType &&
          cp == other.cp &&
          sp == other.sp &&
          ep == other.ep &&
          gp == other.gp &&
          pp == other.pp &&
          cpCounter == other.cpCounter &&
          spCounter == other.spCounter &&
          epCounter == other.epCounter &&
          gpCounter == other.gpCounter &&
          ppCounter == other.ppCounter;

  @override
  int get hashCode => Object.hash(
        cp,
        sp,
        ep,
        gp,
        pp,
        cpCounter,
        spCounter,
        epCounter,
        gpCounter,
        ppCounter,
      );
}

class PartyPurseSplit {
  final int playerCount;
  final double totalGpEquivalent;
  final double perPlayerGpEquivalent;
  final int cpPerPlayer;
  final int spPerPlayer;
  final int epPerPlayer;
  final int gpPerPlayer;
  final int ppPerPlayer;
  final PartyPurse remainderPurse;
  final bool liquidatedGemsAndArtIncluded;

  const PartyPurseSplit({
    required this.playerCount,
    required this.totalGpEquivalent,
    required this.perPlayerGpEquivalent,
    required this.cpPerPlayer,
    required this.spPerPlayer,
    required this.epPerPlayer,
    required this.gpPerPlayer,
    required this.ppPerPlayer,
    required this.remainderPurse,
    required this.liquidatedGemsAndArtIncluded,
  });
}
