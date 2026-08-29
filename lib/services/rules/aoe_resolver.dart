import 'dart:math' as math;
import '../../models/arena/arena_combatant.dart';
import '../../models/arena/arena_simulation_models.dart';

/// 5e Area of Effect geometric shapes (DMG p. 249).
enum AoeShape {
  sphere('Sphere / Radius', 5.0),
  cylinder('Cylinder', 5.0),
  cone('Cone', 10.0),
  cube('Cube', 10.0),
  line('Line', 30.0);

  final String label;
  final double divisor;
  const AoeShape(this.label, this.divisor);
}

/// DMG p.249 Theater-of-the-Mind AoE Target Resolution with Box-Muller Gaussian clustering.
class AoeResolver {
  AoeResolver._();

  /// Calculates deterministic Base Target Cap per DMG p.249:
  /// - Sphere / Cylinder: radius / 5
  /// - Cone / Cube: size / 10
  /// - Line: length / 30
  static double getBaseTargetCap(AoeShape shape, double sizeInFeet) {
    if (sizeInFeet <= 0) return 1.0;
    return sizeInFeet / shape.divisor;
  }

  /// Calculates the dynamic number of targets caught in an AoE using a Box-Muller
  /// Gaussian transform around the DMG p.249 base target cap with variance sigma = 0.85.
  static int calculateTargetCount({
    required AoeShape shape,
    required double sizeInFeet,
    required int livingEnemyCount,
    required math.Random rng,
    double sigma = 0.85,
  }) {
    if (livingEnemyCount <= 1) return livingEnemyCount;

    final baseCap = getBaseTargetCap(shape, sizeInFeet);

    // Box-Muller Gaussian transform: z0 = sqrt(-2 ln(u1)) * cos(2 pi u2)
    final u1 = rng.nextDouble().clamp(1e-7, 1.0);
    final u2 = rng.nextDouble();
    final z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
    final val = baseCap + (sigma * z0);

    return val.round().clamp(1, livingEnemyCount);
  }

  /// Selects the exact entities caught in the AoE blast, prioritizing targets
  /// according to the simulator's tactical heuristics.
  static List<ArenaCombatant> selectTargets({
    required List<ArenaCombatant> livingEnemies,
    required AoeShape shape,
    required double sizeInFeet,
    required math.Random rng,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    double sigma = 0.85,
  }) {
    if (livingEnemies.isEmpty) return const [];
    if (livingEnemies.length == 1) return [livingEnemies.first];

    final targetCount = calculateTargetCount(
      shape: shape,
      sizeInFeet: sizeInFeet,
      livingEnemyCount: livingEnemies.length,
      rng: rng,
      sigma: sigma,
    );

    // If target count encompasses everyone, return all living enemies
    if (targetCount >= livingEnemies.length) {
      return List<ArenaCombatant>.from(livingEnemies);
    }

    final candidates = List<ArenaCombatant>.from(livingEnemies);

    // Sort by strategy to prioritize clustering / high-value targets
    switch (strategy) {
      case ArenaTargetingStrategy.focusLowestHp:
        candidates.sort((a, b) {
          if (a.currentHp != b.currentHp) return a.currentHp.compareTo(b.currentHp);
          return a.ac.compareTo(b.ac);
        });

      case ArenaTargetingStrategy.highestThreat:
        candidates.sort((a, b) {
          final crA = a.monster.challengeRating;
          final crB = b.monster.challengeRating;
          if (crA != crB) return crB.compareTo(crA);
          return b.maxHp.compareTo(a.maxHp);
        });

      case ArenaTargetingStrategy.randomEnemy:
        candidates.shuffle(rng);
    }

    return candidates.take(targetCount).toList();
  }

  static final RegExp _dimPattern = RegExp(r'(\d+)\s*(?:-|\s*)?(?:foot|ft\.?|feet)\b', caseSensitive: false);

  /// Helper to parse AoE shape and dimensions from action names and descriptions.
  static ({AoeShape shape, double sizeInFeet}) parseShapeAndSize(
    String name, [
    String? description,
  ]) {
    final combined = '${name.toLowerCase()} ${description?.toLowerCase() ?? ''}';

    // 1. Check for explicit dimensions like "60-foot cone", "20-ft. radius", "100-foot line"
    final dimMatch = _dimPattern.firstMatch(combined);

    double? explicitSize;
    if (dimMatch != null) {
      explicitSize = double.tryParse(dimMatch.group(1) ?? '');
    }

    if (combined.contains('cone')) {
      return (shape: AoeShape.cone, sizeInFeet: explicitSize ?? 30.0);
    }
    if (combined.contains('line')) {
      return (shape: AoeShape.line, sizeInFeet: explicitSize ?? 60.0);
    }
    if (combined.contains('cylinder')) {
      return (shape: AoeShape.cylinder, sizeInFeet: explicitSize ?? 10.0);
    }
    if (combined.contains('cube')) {
      return (shape: AoeShape.cube, sizeInFeet: explicitSize ?? 15.0);
    }
    if (combined.contains('sphere') || combined.contains('radius')) {
      return (shape: AoeShape.sphere, sizeInFeet: explicitSize ?? 20.0);
    }
    if (combined.contains('breath')) {
      return (shape: AoeShape.cone, sizeInFeet: explicitSize ?? 30.0);
    }

    return (shape: AoeShape.sphere, sizeInFeet: explicitSize ?? 20.0);
  }
}
