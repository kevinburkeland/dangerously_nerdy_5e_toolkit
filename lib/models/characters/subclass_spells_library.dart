import '../../models/spellbook_data.dart';
import '../dm_screen_data.dart';
import '../domain/feature_grant.dart';
import 'srd_classes_library.dart';

/// Central repository and lookup engine for 5e Subclass Expanded Spells & Patron Spell Lists.
class SubclassSpellsLibrary {
  SubclassSpellsLibrary._();

  /// Canonical expanded spell lists mapped by normalized subclass slug keywords.
  static const Map<String, List<String>> _subclassExpandedSpells = {
    // -------------------------------------------------------------------------
    // WARLOCK PATRONS
    // -------------------------------------------------------------------------
    'fiend': [
      'burning hands',
      'command',
      'blindness/deafness',
      'scorching ray',
      'fireball',
      'stinking cloud',
      'fire shield',
      'wall of fire',
      'flame strike',
      'hallow',
    ],
    'archfey': [
      'faerie fire',
      'sleep',
      'calm emotions',
      'phantasmal force',
      'misty step',
      'blink',
      'plant growth',
      'dominate beast',
      'greater invisibility',
      'dominate person',
      'seeming',
    ],
    'great_old_one': [
      'dissonant whispers',
      'tasha\'s hideous laughter',
      'detect thoughts',
      'phantasmal force',
      'clairvoyance',
      'sending',
      'dominate beast',
      'evard\'s black tentacles',
      'dominate person',
      'telekinesis',
    ],
    'celestial': [
      'cure wounds',
      'guiding bolt',
      'flaming sphere',
      'lesser restoration',
      'daylight',
      'revivify',
      'guardian of faith',
      'wall of fire',
      'flame strike',
      'greater restoration',
    ],
    'hexblade': [
      'shield',
      'wrathful smite',
      'blur',
      'branding smite',
      'blink',
      'elemental weapon',
      'phantasmal killer',
      'staggering smite',
      'banishing smite',
      'cone of cold',
    ],
    'fathomless': [
      'create or destroy water',
      'thunderwave',
      'gust of wind',
      'silence',
      'lightning bolt',
      'sleet storm',
      'control water',
      'summon elemental',
      'bigby\'s hand',
      'cone of cold',
    ],
    'genie': [
      'detect evil and good',
      'phantasmal force',
      'create food and water',
      'phantasmal killer',
      'creation',
      'wish',
    ],
    'undead': [
      'bane',
      'false life',
      'blindness/deafness',
      'phantasmal force',
      'phantom steed',
      'speak with dead',
      'death ward',
      'greater invisibility',
      'antilife shell',
      'cloudkill',
    ],
    'undying': [
      'false life',
      'ray of sickness',
      'blindness/deafness',
      'silence',
      'feign death',
      'speak with dead',
      'aura of life',
      'death ward',
      'contagion',
      'legend lore',
      'spare the dying',
    ],

    // -------------------------------------------------------------------------
    // CLERIC DOMAINS
    // -------------------------------------------------------------------------
    'life': [
      'bless',
      'cure wounds',
      'lesser restoration',
      'spiritual weapon',
      'beacon of hope',
      'revivify',
      'death ward',
      'guardian of faith',
      'mass cure wounds',
      'raise dead',
    ],
    'light': [
      'burning hands',
      'faerie fire',
      'flaming sphere',
      'scorching ray',
      'daylight',
      'fireball',
      'guardian of faith',
      'wall of fire',
      'flame strike',
      'scrying',
    ],
    'trickery': [
      'charm person',
      'disguise self',
      'mirror image',
      'pass without trace',
      'blink',
      'dispel magic',
      'dimension door',
      'polymorph',
      'dominate person',
      'modify memory',
    ],
    'war': [
      'divine favor',
      'shield of faith',
      'magic weapon',
      'spiritual weapon',
      'crusader\'s mantle',
      'spirit guardians',
      'freedom of movement',
      'stoneskin',
      'flame strike',
      'hold monster',
    ],

    // -------------------------------------------------------------------------
    // PALADIN OATHS
    // -------------------------------------------------------------------------
    'devotion': [
      'protection from evil and good',
      'sanctuary',
      'lesser restoration',
      'zone of truth',
      'beacon of hope',
      'dispel magic',
      'freedom of movement',
      'guardian of faith',
      'commune',
      'flame strike',
    ],
    'vengeance': [
      'bane',
      'hunter\'s mark',
      'hold person',
      'misty step',
      'haste',
      'protection from energy',
      'banishment',
      'dimension door',
      'hold monster',
      'scrying',
    ],
    'ancients': [
      'ensnaring strike',
      'speak with animals',
      'moonbeam',
      'misty step',
      'plant growth',
      'protection from energy',
      'ice storm',
      'stoneskin',
      'commune with nature',
      'tree stride',
    ],
  };

  /// Returns the set of expanded spell names for a given class & subclass slug.
  static Set<String> getExpandedSpells(String classSlug, String? subclassSlug) {
    if (subclassSlug == null || subclassSlug.isEmpty) return const {};
    final cleanSub = subclassSlug.toLowerCase().replaceAll('-', '_').trim();
    final cleanSubHyphen = subclassSlug.toLowerCase().replaceAll('_', '-').trim();

    final results = <String>{};
    for (final entry in _subclassExpandedSpells.entries) {
      if (cleanSub.contains(entry.key)) {
        results.addAll(entry.value);
      }
    }

    // Dynamic resolution from loaded subclasses (including homebrew)
    final matchedSubs = SrdClassesLibrary.allSubclasses.where((s) {
      final sSlug = s.id.slug.toLowerCase().trim();
      final sName = s.name.toLowerCase().trim();
      final sShort = s.shortName.toLowerCase().trim();
      return sSlug == cleanSubHyphen ||
          sSlug == cleanSub ||
          sName == cleanSub ||
          sName == cleanSubHyphen ||
          sShort == cleanSub ||
          sShort == cleanSubHyphen ||
          cleanSub.contains(sSlug) ||
          cleanSubHyphen.contains(sSlug);
    });

    for (final sub in matchedSubs) {
      for (final g in sub.grants) {
        if (g.type == GrantType.bonusSpell) {
          final name = g.payload['displayName']?.toString() ?? g.label ?? g.payload['slug']?.toString();
          if (name != null && name.isNotEmpty) {
            results.add(name.toLowerCase());
          }
        }
      }
      final addSpells = sub.customProperties['additionalSpells'] ?? sub.customProperties['subclassSpells'];
      if (addSpells != null) {
        final extracted = FeatureGrant.extractSpellNames(addSpells);
        for (final sp in extracted) {
          results.add(sp.toLowerCase());
        }
      }
    }

    return results;
  }

  /// Determines if a given [SpellItem] belongs to the expanded spell list for the subclass.
  static bool isExpandedSpell(
    String classSlug,
    String? subclassSlug,
    SpellItem spell,
    DmRulesEdition edition,
  ) {
    final expanded = getExpandedSpells(classSlug, subclassSlug);
    if (expanded.isEmpty) return false;

    final spellName = spell.getName(edition).toLowerCase();
    final spellId = spell.id.toLowerCase();
    final cleanName = spellName.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanId = spellId.replaceAll(RegExp(r'[^a-z0-9]'), '');

    return expanded.any((exp) {
      final cleanExp = exp.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return cleanName == cleanExp ||
          cleanId == cleanExp ||
          cleanId.contains(cleanExp) ||
          cleanName.contains(cleanExp);
    });
  }

  /// Indicates whether the class's subclass spells are auto-prepared (e.g. Cleric Domains, Paladin Oaths)
  /// as opposed to being expanded options added to the spells known pool (e.g. Warlock Patrons).
  static bool isAlwaysPreparedSubclass(String classSlug, [String? subclassSlug]) {
    final slug = classSlug.toLowerCase();
    if (slug == 'cleric' || slug == 'paladin' || slug == 'druid') return true;

    if (subclassSlug != null && subclassSlug.isNotEmpty) {
      final cleanSub = subclassSlug.toLowerCase().replaceAll('_', '-').trim();
      final match = SrdClassesLibrary.allSubclasses.where((s) {
        final sSlug = s.id.slug.toLowerCase().trim();
        return sSlug == cleanSub || s.name.toLowerCase().trim() == cleanSub;
      }).firstOrNull;
      if (match != null) {
        final addSpells = match.customProperties['additionalSpells'];
        if (addSpells is List) {
          for (final group in addSpells) {
            if (group is Map && group.containsKey('prepared')) return true;
          }
        }
      }
    }
    return false;
  }

  /// Returns the list of auto-granted [SpellItem]s for a given class, subclass, and class level.
  static List<SpellItem> getAlwaysPreparedSpellsForLevel({
    required String classSlug,
    required String? subclassSlug,
    required int classLevel,
    required DmRulesEdition edition,
  }) {
    if (!isAlwaysPreparedSubclass(classSlug, subclassSlug) || subclassSlug == null || subclassSlug.isEmpty) {
      return const [];
    }

    final maxTier = switch (classSlug.toLowerCase()) {
      'cleric' || 'druid' => (classLevel + 1) ~/ 2,
      'paladin' => (classLevel < 3) ? 0 : ((classLevel + 3) ~/ 4),
      _ => (classLevel + 1) ~/ 2,
    };

    if (maxTier <= 0) return const [];

    final expanded = getExpandedSpells(classSlug, subclassSlug);
    if (expanded.isEmpty) return const [];

    return SpellbookLibrary.allSpells.where((s) {
      if (s.level == 0 || s.level > maxTier) return false;
      return isExpandedSpell(classSlug, subclassSlug, s, edition);
    }).toList();
  }
}

