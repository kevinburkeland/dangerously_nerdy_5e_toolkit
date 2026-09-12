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

  /// Extracts filter query strings (e.g. `level=0|class=Cleric`) embedded inside
  /// compendium/homebrew `additionalSpells` structures under `all` or `choose` keys.
  static List<String> extractFilterStrings(dynamic data) {
    final filters = <String>[];

    void search(dynamic obj) {
      if (obj == null) return;
      if (obj is List) {
        for (final item in obj) {
          search(item);
        }
      } else if (obj is Map) {
        for (final entry in obj.entries) {
          final k = entry.key.toString().toLowerCase();
          final v = entry.value;
          if (k == 'all' || k == 'choose') {
            if (v is String && v.contains('=')) {
              filters.add(v);
            } else if (v is List) {
              for (final sub in v) {
                if (sub is String && sub.contains('=')) {
                  filters.add(sub);
                } else {
                  search(sub);
                }
              }
            } else {
              search(v);
            }
          } else {
            search(v);
          }
        }
      }
    }

    search(data);
    return filters;
  }

  /// Evaluates a 5eTools-style filter expression (e.g. `level=0|class=Cleric`, `school=I;N`)
  /// against registered spells in [SpellbookLibrary.allSpells].
  static List<SpellItem> resolveFilterSpells(String filterString, [DmRulesEdition? edition]) {
    final clauses = filterString.split('|');
    int? targetLevel;
    Set<int>? targetLevels;
    Set<String>? targetClasses;
    Set<SpellSchool>? targetSchools;
    Set<String>? targetSources;
    bool requiresRitual = false;
    bool hasRecognizedFilter = false;

    for (final rawClause in clauses) {
      final clause = rawClause.trim();
      final eqIdx = clause.indexOf('=');
      if (eqIdx == -1) continue;
      final key = clause.substring(0, eqIdx).trim().toLowerCase();
      final val = clause.substring(eqIdx + 1).trim();

      if (key == 'level') {
        final parts = val.split(';').map((v) => int.tryParse(v.trim())).whereType<int>().toSet();
        if (parts.length == 1) {
          targetLevel = parts.first;
          hasRecognizedFilter = true;
        } else if (parts.length > 1) {
          targetLevels = parts;
          hasRecognizedFilter = true;
        }
      } else if (key == 'class') {
        final clsList = val.toLowerCase().split(';').map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
        if (clsList.isNotEmpty) {
          targetClasses = clsList;
          hasRecognizedFilter = true;
        }
      } else if (key == 'source') {
        final srcList = val.toLowerCase().split(';').map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
        if (srcList.isNotEmpty) {
          targetSources = srcList;
          hasRecognizedFilter = true;
        }
      } else if (key == 'school') {
        final schools = <SpellSchool>{};
        for (final s in val.toLowerCase().split(';')) {
          final sTrim = s.trim();
          switch (sTrim) {
            case 'a':
            case 'abjuration':
              schools.add(SpellSchool.abjuration);
            case 'c':
            case 'conjuration':
              schools.add(SpellSchool.conjuration);
            case 'd':
            case 'divination':
              schools.add(SpellSchool.divination);
            case 'e':
            case 'enchantment':
              schools.add(SpellSchool.enchantment);
            case 'v':
            case 'evocation':
              schools.add(SpellSchool.evocation);
            case 'i':
            case 'illusion':
              schools.add(SpellSchool.illusion);
            case 'n':
            case 'necromancy':
              schools.add(SpellSchool.necromancy);
            case 't':
            case 'transmutation':
              schools.add(SpellSchool.transmutation);
          }
        }
        if (schools.isNotEmpty) {
          targetSchools = schools;
          hasRecognizedFilter = true;
        }
      } else if (key.contains('components') || key.contains('ritual')) {
        if (val.toLowerCase().contains('ritual')) {
          requiresRitual = true;
          hasRecognizedFilter = true;
        }
      }
    }

    if (!hasRecognizedFilter) {
      return const [];
    }

    return SpellbookLibrary.allSpells.where((spell) {
      if (targetLevel != null && spell.level != targetLevel) return false;
      if (targetLevels != null && !targetLevels.contains(spell.level)) return false;

      if (targetSchools != null && !targetSchools.contains(spell.school)) return false;

      if (requiresRitual && !spell.rules2014.ritual && !spell.rules2024.ritual) {
        return false;
      }

      if (targetSources != null) {
        final lowerId = spell.id.toLowerCase();
        final matchesSource = spell.tags.any((t) => targetSources!.contains(t.toLowerCase())) ||
            targetSources.any((src) => lowerId.contains(src));
        if (!matchesSource) return false;
      }

      if (targetClasses != null) {
        final classes2014 = spell.rules2014.classes.map((c) => c.name.toLowerCase()).toSet();
        final classes2024 = spell.rules2024.classes.map((c) => c.name.toLowerCase()).toSet();
        final matches2014 = classes2014.intersection(targetClasses).isNotEmpty;
        final matches2024 = classes2024.intersection(targetClasses).isNotEmpty;

        if (edition == DmRulesEdition.v2014 && !matches2014) return false;
        if (edition == DmRulesEdition.v2024 && !matches2024) return false;
        if (edition == null && !matches2014 && !matches2024) return false;
      }

      return true;
    }).toList();
  }

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

    // Canonical Divine Soul Sorcerer grant: full Cleric spell list (5e RAW Divine Magic)
    final isDivineSoul = classSlug.toLowerCase() == 'sorcerer' &&
        (cleanSub.contains('divine_soul') || cleanSub.contains('divine-soul') || cleanSub == 'divinesoul' || cleanSub.contains('divine'));
    if (isDivineSoul) {
      for (final s in SpellbookLibrary.allSpells) {
        if (s.rules2014.classes.contains(SpellClass.cleric) || s.rules2024.classes.contains(SpellClass.cleric)) {
          results.add(s.name.toLowerCase());
          results.add(s.id.toLowerCase());
        }
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
        final filters = extractFilterStrings(addSpells);
        for (final filter in filters) {
          final matching = resolveFilterSpells(filter);
          for (final s in matching) {
            results.add(s.name.toLowerCase());
            results.add(s.id.toLowerCase());
          }
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
    if (subclassSlug == null || subclassSlug.isEmpty) return false;
    final cleanSub = subclassSlug.toLowerCase().replaceAll('-', '_').trim();

    // Fast-path: Divine Soul Sorcerers learn from both Sorcerer and Cleric lists (Divine Magic)
    if (classSlug.toLowerCase() == 'sorcerer' &&
        (cleanSub.contains('divine_soul') || cleanSub.contains('divine-soul') || cleanSub == 'divinesoul' || cleanSub.contains('divine'))) {
      final rules = spell.getRules(edition);
      if (rules.classes.contains(SpellClass.cleric)) return true;
    }

    // Fast-path: Arcane Trickster Rogues & Eldritch Knight Fighters learn Wizard spells
    if (classSlug.toLowerCase() == 'rogue' && cleanSub.contains('arcane_trickster')) {
      final rules = spell.getRules(edition);
      if (rules.classes.contains(SpellClass.wizard)) return true;
    }
    if (classSlug.toLowerCase() == 'fighter' && cleanSub.contains('eldritch_knight')) {
      final rules = spell.getRules(edition);
      if (rules.classes.contains(SpellClass.wizard)) return true;
    }

    final expanded = getExpandedSpells(classSlug, subclassSlug);
    if (expanded.isEmpty) return false;

    final spellName = spell.getName(edition).toLowerCase();
    final spellId = spell.id.toLowerCase();
    if (expanded.contains(spellName) || expanded.contains(spellId)) return true;

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

