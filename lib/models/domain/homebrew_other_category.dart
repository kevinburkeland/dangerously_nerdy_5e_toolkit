/// Granular sub-classification for [EntityType.custom] homebrew entities
/// stored under the other/rules codex collection.
enum HomebrewOtherCategory {
  tables,
  dataTables,
  deities,
  vehicles,
  trapsAndHazards,
  invocationsAndPacts,
  infusions,
  charmsAndRewards,
  conditionsAndDiseases,
  characterOptions,
  rulesAndReference;

  String get label {
    switch (this) {
      case HomebrewOtherCategory.tables:
        return 'Rollable Tables';
      case HomebrewOtherCategory.dataTables:
        return 'Data & Reference Tables';
      case HomebrewOtherCategory.deities:
        return 'Deities & Pantheons';
      case HomebrewOtherCategory.vehicles:
        return 'Vehicles & Vessels';
      case HomebrewOtherCategory.trapsAndHazards:
        return 'Traps & Hazards';
      case HomebrewOtherCategory.invocationsAndPacts:
        return 'Invocations & Pact Boons';
      case HomebrewOtherCategory.infusions:
        return 'Infusions';
      case HomebrewOtherCategory.charmsAndRewards:
        return 'Charms & Rewards';
      case HomebrewOtherCategory.conditionsAndDiseases:
        return 'Conditions & Diseases';
      case HomebrewOtherCategory.characterOptions:
        return 'Character Options';
      case HomebrewOtherCategory.rulesAndReference:
        return 'Rules & Reference';
    }
  }

  /// Helper to determine whether a table entity is a dice-based rolling table
  /// or a reference / data table.
  static bool isRollingTable({
    required String category,
    required String name,
    Map<String, dynamic>? customProperties,
  }) {
    final cat = category.toLowerCase().trim();
    final n = name.toLowerCase().trim();

    // Explicit data/reference indicator in category or name
    if (cat.contains('data') ||
        cat.contains('reference') ||
        n.contains('data table') ||
        n.contains('reference table') ||
        n.contains('matrix')) {
      return false;
    }

    if (cat.contains('roll') ||
        cat.contains('random') ||
        n.contains('random') ||
        n.contains('rollable') ||
        n.contains('loot') ||
        n.contains('hit') ||
        n.contains('encounter') ||
        n.contains('critical')) {
      return true;
    }

    if (customProperties != null) {
      // Check for explicit dice properties
      if (customProperties.containsKey('diceType') ||
          customProperties.containsKey('diceCount') ||
          customProperties.containsKey('dice') ||
          customProperties.containsKey('roll')) {
        return true;
      }

      // Check column headers for dice or roll notation (e.g. "d100", "d20", "d6", "Roll", "Die", "Result")
      final colLabels = customProperties['colLabels'];
      if (colLabels is List && colLabels.isNotEmpty) {
        final diceRegex = RegExp(r'\b(?:d\d+|d%|roll|die|dice|result)\b', caseSensitive: false);
        for (final col in colLabels) {
          final colStr = col is Map ? (col['entry'] ?? col.toString()) : col.toString();
          if (diceRegex.hasMatch(colStr)) {
            return true;
          }
        }
      }

      // Check first column of rows for numeric ranges or dice rolls (e.g. "1-4", "01-10", 1, 2)
      final rows = customProperties['rows'];
      if (rows is List && rows.isNotEmpty) {
        final firstRow = rows.first;
        if (firstRow is List && firstRow.isNotEmpty) {
          final firstCell = firstRow.first;
          if (firstCell is int || firstCell is num) {
            return true;
          }
          if (firstCell is Map && (firstCell.containsKey('min') || firstCell.containsKey('roll'))) {
            return true;
          }
          final cellStr = firstCell.toString().trim();
          if (RegExp(r'^\s*(?:\d{1,3}\s*[-–—]\s*\d{1,3}|\d{1,3}|d\d+)\s*$').hasMatch(cellStr)) {
            return true;
          }
          // If rows exist with multiple cells and first cell is text (e.g. Object names or armor names)
          return false;
        }
      }

      // If colLabels exist and none matched dice/roll and rows don't have numeric start
      if (colLabels is List && colLabels.isNotEmpty) {
        return false;
      }
    }

    // Default fallback for generic table without schema: rolling table
    return true;
  }

  /// Classifies a raw category string, entity name, and auxiliary custom properties
  /// into a canonical [HomebrewOtherCategory].
  static HomebrewOtherCategory classify({
    required String category,
    required String name,
    Map<String, dynamic>? customProperties,
  }) {
    final cat = category.toLowerCase().trim();
    final n = name.toLowerCase().trim();

    // Extract all featureTypes (can be List or String)
    final Set<String> featureTypes = {};
    final rawFt = customProperties?['featureType'];
    if (rawFt is List) {
      for (final f in rawFt) {
        featureTypes.add(f.toString().trim().toUpperCase());
      }
    } else if (rawFt != null) {
      featureTypes.add(rawFt.toString().trim().toUpperCase());
    }

    // Tables: Differentiate between Rolling Tables and Data/Reference Tables
    if (cat.contains('table') || (customProperties != null && customProperties.containsKey('rows'))) {
      if (isRollingTable(category: cat, name: n, customProperties: customProperties)) {
        return HomebrewOtherCategory.tables;
      }
      return HomebrewOtherCategory.dataTables;
    }

    // Deities
    if (cat.contains('deity') || (customProperties != null && customProperties.containsKey('pantheon'))) {
      return HomebrewOtherCategory.deities;
    }

    // Vehicles
    if (cat.contains('vehicle') ||
        (customProperties != null &&
            (customProperties.containsKey('vehicleType') || customProperties.containsKey('upgradeType')))) {
      return HomebrewOtherCategory.vehicles;
    }

    // Traps & Hazards
    if (cat.contains('trap') ||
        cat.contains('hazard') ||
        (customProperties != null &&
            (customProperties.containsKey('trapType') || customProperties.containsKey('hazardType')))) {
      return HomebrewOtherCategory.trapsAndHazards;
    }

    // Invocations & Pact Boons
    final isPb = cat.contains('pact boon') ||
        cat == 'pb' ||
        cat.startsWith('pb:') ||
        n.startsWith('pact of the') ||
        featureTypes.contains('PB') ||
        featureTypes.any((t) => t.startsWith('PB'));

    final isEi = cat.contains('invocation') ||
        cat == 'ei' ||
        cat.startsWith('ei:') ||
        featureTypes.contains('EI') ||
        featureTypes.any((t) => t.startsWith('EI'));

    if (isPb || isEi) {
      return HomebrewOtherCategory.invocationsAndPacts;
    }

    // Infusions
    final isInf = cat.contains('infusion') ||
        cat == 'ai' ||
        cat.startsWith('ai:') ||
        featureTypes.contains('AI') ||
        featureTypes.any((t) => t.startsWith('AI'));

    if (isInf) {
      return HomebrewOtherCategory.infusions;
    }

    // Charms & Rewards
    if (cat.contains('charm') ||
        cat.contains('reward') ||
        cat.contains('boon') ||
        cat.contains('blessing') ||
        cat.contains('cult')) {
      return HomebrewOtherCategory.charmsAndRewards;
    }

    // Conditions & Diseases
    if (cat.contains('condition') || cat.contains('disease') || cat.contains('status')) {
      return HomebrewOtherCategory.conditionsAndDiseases;
    }

    // Character Options (Metamagic, Maneuvers, Optional Features, Psionics)
    if (cat.contains('character option') ||
        cat.contains('optional feature') ||
        cat.contains('optfeature') ||
        cat.contains('charoption') ||
        cat.contains('metamagic') ||
        cat.contains('maneuver') ||
        cat.contains('psionic') ||
        featureTypes.contains('MM') ||
        featureTypes.contains('MV:B') ||
        featureTypes.contains('MAN') ||
        featureTypes.contains('FS:F') ||
        featureTypes.contains('ED') ||
        featureTypes.contains('AS')) {
      return HomebrewOtherCategory.characterOptions;
    }

    return HomebrewOtherCategory.rulesAndReference;
  }
}
