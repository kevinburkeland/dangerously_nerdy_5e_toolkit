/// Canonical Ruleset Edition value object representing supported D&D ruleset mechanics.
///
/// Serves as the single source of truth across core domain rules, compendiums,
/// homebrew ingestion, and tabletop display. Pure Dart domain model with zero Flutter dependencies.
enum RulesetEdition {
  dnd2014,
  dnd2024;

  /// Human-readable display title.
  String get displayName => switch (this) {
        RulesetEdition.dnd2014 => '2014 Rules (SRD 5.1)',
        RulesetEdition.dnd2024 => '2024 Revised Rules (SRD 5.2)',
      };

  /// Concise label for badges, chips, and tabs.
  String get shortLabel => switch (this) {
        RulesetEdition.dnd2014 => '2014',
        RulesetEdition.dnd2024 => '2024',
      };

  /// Machine edition identifier for bundles and wire payloads.
  String get editionId => switch (this) {
        RulesetEdition.dnd2014 => '5e-2014',
        RulesetEdition.dnd2024 => '5e-2024',
      };

  /// Systems Reference Document citation.
  String get srdCitation => switch (this) {
        RulesetEdition.dnd2014 => 'Systems Reference Document 5.1 (OGL 1.0a / CC-BY-4.0)',
        RulesetEdition.dnd2024 => 'Systems Reference Document 5.2 (CC-BY-4.0)',
      };

  /// Whether this edition represents the revised 2024 ruleset.
  bool get is2024 => this == RulesetEdition.dnd2024;

  /// Whether this edition represents the legacy 2014 ruleset.
  bool get is2014 => this == RulesetEdition.dnd2014;

  /// Robust string parser handling compendium and schema identifiers ('5e-2014', 'v2014', 'srd2024', etc.).
  static RulesetEdition fromString(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.contains('2024') ||
        clean == 'srd5.2' ||
        clean == 'srd2024' ||
        clean == 'xphb' ||
        clean == '5e-2024' ||
        clean == 'v2024') {
      return RulesetEdition.dnd2024;
    }
    return RulesetEdition.dnd2014;
  }
}
