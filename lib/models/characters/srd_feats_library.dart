import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/homebrew_extended_entities.dart';

/// Comprehensive SRD 5.1 (2014) and SRD 5.2 (2024) Feat Library.
@immutable
class SrdFeatsLibrary {
  // --------------------------------------------------------------------------
  // SRD GENERAL FEATS
  // --------------------------------------------------------------------------

  static const Feat grappler = Feat(
    id: EntityId(slug: 'grappler', ruleset: RulesetVersion.v2024),
    name: 'Grappler',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Advantage on Grappled Targets.** You have Advantage on attack rolls against a creature you are grappling.\n\n'
        '**Fast Grappler.** You can move at your full speed rather than half speed when carrying or dragging a creature grappled by you.\n\n'
        '**Free Strike.** Once per turn when you hit a creature with an Unarmed Strike, you can deal damage and grapple the target.',
    customProperties: {
      'advantageOnGrappled': true,
      'fastDrag': true,
    },
  );

  /// Base Core SRD Feats
  static final List<Feat> _baseFeats = [
    grappler,
  ];

  static List<Feat> _customFeats = [];

  /// Dynamic list of all available feats (Base SRD + Custom Homebrew)
  static List<Feat> get allFeats => [..._baseFeats, ..._customFeats];

  /// Sets the list of custom/homebrew feats
  static void setCustomFeats(List<Feat> custom) {
    _customFeats = List<Feat>.from(custom);
  }

  /// Adds or replaces a custom feat in the library
  static void addCustomFeat(Feat feat) {
    _customFeats.removeWhere((f) => f.id.slug == feat.id.slug);
    _customFeats.add(feat);
  }

  /// Removes a custom feat by slug
  static void removeCustomFeat(String slug) {
    _customFeats.removeWhere((f) => f.id.slug == slug);
  }

  /// Filter feats by category
  static List<Feat> getOriginFeats({RulesetVersion ruleset = RulesetVersion.v2024}) {
    if (ruleset == RulesetVersion.v2014) {
      return const []; // 2014 rules have no Origin Feats
    }
    return allFeats.where((f) => f.category == 'Origin').toList();
  }

  static List<Feat> getGeneralFeats() {
    return allFeats.where((f) => f.category == 'General').toList();
  }

  static List<Feat> getFeatsForRuleset(RulesetVersion ruleset) {
    if (ruleset == RulesetVersion.v2014) {
      // In 2014, feats are General (combat / utility) feats; no Origin feats
      return allFeats.where((f) => f.category != 'Origin').toList();
    }
    return allFeats;
  }

  static Feat? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allFeats.where((f) => f.id.slug == clean || f.name.toLowerCase() == clean).firstOrNull;
  }
}
