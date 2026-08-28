import 'dart:convert';

/// Represents party coin purse denominations with conversion and splitting math.
class PartyPurse {
  final int cp;
  final int sp;
  final int ep;
  final int gp;
  final int pp;

  const PartyPurse({
    this.cp = 0,
    this.sp = 0,
    this.ep = 0,
    this.gp = 0,
    this.pp = 0,
  });

  /// Total gold piece equivalent (1 PP = 10 GP, 1 EP = 0.5 GP, 1 SP = 0.1 GP, 1 CP = 0.01 GP)
  double get totalGpEquivalent =>
      (pp * 10.0) + gp.toDouble() + (ep * 0.5) + (sp * 0.1) + (cp * 0.01);

  bool get isEmpty => cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0;

  PartyPurse copyWith({
    int? cp,
    int? sp,
    int? ep,
    int? gp,
    int? pp,
  }) {
    return PartyPurse(
      cp: cp ?? this.cp,
      sp: sp ?? this.sp,
      ep: ep ?? this.ep,
      gp: gp ?? this.gp,
      pp: pp ?? this.pp,
    );
  }

  /// Deposits coin increments (never reducing below 0)
  PartyPurse depositCoins({
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
  }) {
    return PartyPurse(
      cp: this.cp + cp,
      sp: this.sp + sp,
      ep: this.ep + ep,
      gp: this.gp + gp,
      pp: this.pp + pp,
    );
  }

  /// Withdraws coin amounts, clamped at zero
  PartyPurse withdrawCoins({
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
  }) {
    return PartyPurse(
      cp: (this.cp - cp).clamp(0, 999999999),
      sp: (this.sp - sp).clamp(0, 999999999),
      ep: (this.ep - ep).clamp(0, 999999999),
      gp: (this.gp - gp).clamp(0, 999999999),
      pp: (this.pp - pp).clamp(0, 999999999),
    );
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
    return {
      'cp': cp,
      'sp': sp,
      'ep': ep,
      'gp': gp,
      'pp': pp,
    };
  }

  factory PartyPurse.fromMap(Map<String, dynamic> map) {
    return PartyPurse(
      cp: (map['cp'] as num?)?.toInt() ?? 0,
      sp: (map['sp'] as num?)?.toInt() ?? 0,
      ep: (map['ep'] as num?)?.toInt() ?? 0,
      gp: (map['gp'] as num?)?.toInt() ?? 0,
      pp: (map['pp'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PartyPurse.fromJson(String source) =>
      PartyPurse.fromMap(jsonDecode(source) as Map<String, dynamic>);
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
