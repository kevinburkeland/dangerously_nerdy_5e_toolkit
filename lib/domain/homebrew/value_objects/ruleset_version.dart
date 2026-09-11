/// Explicit ruleset baselines for remote homebrew repositories.
///
/// Mandates explicit assignment without default fallback values
/// to prevent silent cross-ruleset data pollution.
enum RulesetVersion {
  srd2014,
  srd2024;

  /// Human-readable display label.
  String get displayName => switch (this) {
        RulesetVersion.srd2014 => '2014 Rules (SRD 5.1)',
        RulesetVersion.srd2024 => '2024 Revised Rules (SRD 5.2)',
      };

  /// Citation reference.
  String get srdCitation => switch (this) {
        RulesetVersion.srd2014 => 'Systems Reference Document 5.1 (OGL 1.0a / CC-BY-4.0)',
        RulesetVersion.srd2024 => 'Systems Reference Document 5.2 (CC-BY-4.0)',
      };

  /// Machine edition identifier.
  String get editionId => switch (this) {
        RulesetVersion.srd2014 => '5e-2014',
        RulesetVersion.srd2024 => '5e-2024',
      };
}
