import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

/// Parses a stored or received ruleset edition string into a typed [RulesetRef].
///
/// Invariants:
/// - 2024 compendium/wire aliases -> [RulesetEdition.v2024]
/// - 2014 compendium/wire aliases -> [RulesetEdition.v2014]
/// - Legacy defaults ('generic_tabletop', 'unknown', empty/whitespace) -> [RulesetEdition.v2024]
/// - Any other string -> [RulesetIdentifier] preserving the trimmed raw string unchanged without throwing.
RulesetRef parseStoredCampaignEdition(String raw) {
  final clean = raw.trim().toLowerCase();

  if (clean.isEmpty || clean == 'generic_tabletop' || clean == 'unknown') {
    return RulesetEdition.v2024;
  }

  if (clean.contains('2024') ||
      clean == 'srd5.2.1' ||
      clean == 'srd5.2' ||
      clean == 'srd2024' ||
      clean == 'srd521' ||
      clean == 'srd52' ||
      clean == '5e-2024' ||
      clean == 'v2024' ||
      clean.contains('5.2')) {
    return RulesetEdition.v2024;
  }

  if (clean.contains('2014') ||
      clean == 'srd5.1' ||
      clean == 'srd51' ||
      clean == '5e-2014' ||
      clean == 'v2014' ||
      clean.contains('5.1')) {
    return RulesetEdition.v2014;
  }

  return RulesetIdentifier(raw.trim());
}
