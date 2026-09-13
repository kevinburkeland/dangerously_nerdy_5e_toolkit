/// Granular sub-classification for [EntityType.custom] homebrew entities
/// stored under the other/rules codex collection.
enum HomebrewOtherCategory {
  tables,
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

  /// Classifies a raw category string, entity name, and auxiliary custom properties
  /// into a canonical [HomebrewOtherCategory].
  static HomebrewOtherCategory classify({
    required String category,
    required String name,
    Map<String, dynamic>? customProperties,
  }) {
    final cat = category.toLowerCase().trim();
    final n = name.toLowerCase().trim();
    final ft = customProperties?['featureType']?.toString().toUpperCase() ?? '';

    // Tables
    if (cat.contains('table') || (customProperties != null && customProperties.containsKey('rows'))) {
      return HomebrewOtherCategory.tables;
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
    final isPb = cat.contains('pact boon') || cat == 'pb' || cat.startsWith('pb:') || n.startsWith('pact of the') || ft == 'PB';
    final isEi = cat.contains('invocation') || cat == 'ei' || cat.startsWith('ei:') || ft == 'EI';
    if (isPb || isEi) {
      return HomebrewOtherCategory.invocationsAndPacts;
    }

    // Infusions
    final isInf = cat.contains('infusion') || cat == 'ai' || cat.startsWith('ai:') || ft == 'AI';
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

    // Character Options
    if (cat.contains('character option') ||
        cat.contains('optional feature') ||
        cat.contains('optfeature') ||
        cat.contains('charoption') ||
        cat.contains('metamagic') ||
        cat.contains('maneuver')) {
      return HomebrewOtherCategory.characterOptions;
    }

    return HomebrewOtherCategory.rulesAndReference;
  }
}
