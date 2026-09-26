import 'package:vtt_engine_core/rules/ruleset_edition.dart';
export 'package:vtt_engine_core/rules/ruleset_edition.dart';

/// 5e-specific extensions on [RulesetEdition] providing SRD citations, display names, and bundle IDs.
extension RulesetEdition5eExtension on RulesetEdition {
  /// Human-readable display title.
  String get displayName => switch (this) {
        RulesetEdition.v2014 => '2014 Rules (SRD 5.1)',
        RulesetEdition.v2024 => '2024 Revised Rules (SRD 5.2.1)',
      };

  /// Machine edition identifier for bundles and wire payloads.
  String get editionId => switch (this) {
        RulesetEdition.v2014 => '5e-2014',
        RulesetEdition.v2024 => '5e-2024',
      };

  /// Systems Reference Document citation.
  String get srdCitation => switch (this) {
        RulesetEdition.v2014 =>
          'Systems Reference Document 5.1 (OGL 1.0a / CC-BY-4.0)',
        RulesetEdition.v2024 => 'System Reference Document 5.2.1 (CC-BY-4.0)',
      };
}
