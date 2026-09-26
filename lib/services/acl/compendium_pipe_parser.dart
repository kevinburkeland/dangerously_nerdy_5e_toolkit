import '../../models/domain/feature_grant.dart';

/// Anti-Corruption Layer (ACL) parser for isolating and transforming
/// external pipe-delimited tokens (e.g. `Feature|Class|Source|Level`, `Spell|Source#c`)
/// into clean domain entities, references, and [FeatureGrant]s.
class CompendiumPipeParser {
  const CompendiumPipeParser._();

  /// Parses an external feature token formatted as `Name|Class|Source|Level`.
  static ({String name, String? className, String? source, int? level})
      parseFeatureToken(String token) {
    if (!token.contains('|')) {
      return (name: token.trim(), className: null, source: null, level: null);
    }
    final parts = token.split('|').map((p) => p.trim()).toList();
    final name = parts.isNotEmpty ? parts[0] : '';
    final className = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    final source = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
    final level = parts.length > 3 ? int.tryParse(parts[3]) : null;
    return (name: name, className: className, source: source, level: level);
  }

  /// Parses an external spell token such as `Fireball|PHB` or `Light#c` or `Guidance|SRD#c`.
  static ({String name, String? source, bool isCantrip}) parseSpellToken(
      String token) {
    final isCantrip = token.contains('#c');
    final stripped = token.replaceAll('#c', '').trim();
    if (!stripped.contains('|')) {
      return (name: stripped, source: null, isCantrip: isCantrip);
    }
    final parts = stripped.split('|').map((p) => p.trim()).toList();
    final name = parts.isNotEmpty ? parts[0] : '';
    final source = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    return (name: name, source: source, isCantrip: isCantrip);
  }

  /// Exhaustively extracts clean spell names and cantrip flags from compendium additionalSpells / subclassSpells structures.
  static Map<String, bool> extractSpellDescriptors(dynamic addSpellsData) {
    if (addSpellsData == null) return const {};
    final descriptors = <String, bool>{};

    void processSpellItem(dynamic item, {bool isCantripContext = false}) {
      if (item == null) return;
      if (item is String) {
        final parsed = parseSpellToken(item);
        final isCantrip = isCantripContext || parsed.isCantrip;
        final clean = parsed.name;
        if (clean.isNotEmpty && !clean.startsWith('{')) {
          descriptors[clean] = (descriptors[clean] ?? false) || isCantrip;
        }
      } else if (item is List) {
        for (final subItem in item) {
          processSpellItem(subItem, isCantripContext: isCantripContext);
        }
      } else if (item is Map) {
        if (item.containsKey('choose')) {
          final ch = item['choose'];
          if (ch is Map && ch['from'] != null) {
            processSpellItem(ch['from'], isCantripContext: isCantripContext);
          } else if (ch is String && ch.isNotEmpty) {
            final parsed = parseSpellToken(ch);
            final isCantrip = isCantripContext || parsed.isCantrip;
            final clean = parsed.name;
            if (!clean.contains('=')) {
              descriptors[clean] = (descriptors[clean] ?? false) || isCantrip;
            }
          }
        }
        if (item.containsKey('from')) {
          processSpellItem(item['from'], isCantripContext: isCantripContext);
        }
        for (final entry in item.entries) {
          final k = entry.key.toString().toLowerCase();
          if (k == 'choose' || k == 'count' || k == 'all' || k == 'from')
            continue;
          final isSubCantrip =
              isCantripContext || k == '_' || k == '0' || k == 's0';
          processSpellItem(entry.value, isCantripContext: isSubCantrip);
        }
      }
    }

    void processSpellGroup(dynamic group) {
      if (group == null) return;
      if (group is List) {
        for (final item in group) {
          processSpellGroup(item);
        }
      } else if (group is Map) {
        bool hadKnownSubkey = false;
        for (final key in [
          'prepared',
          'expanded',
          'innate',
          'known',
          'spells'
        ]) {
          if (group.containsKey(key)) {
            hadKnownSubkey = true;
            processSpellItem(group[key]);
          }
        }
        if (!hadKnownSubkey) {
          for (final entry in group.entries) {
            final k = entry.key.toString().toLowerCase();
            if (k == 'name' ||
                k == 'source' ||
                k == 'class' ||
                k == 'subclass' ||
                k == 'choose' ||
                k == 'count' ||
                k == 'all') {
              continue;
            }
            final isSubCantrip = k == '_' || k == '0' || k == 's0';
            processSpellItem(entry.value, isCantripContext: isSubCantrip);
          }
        }
      } else if (group is String) {
        processSpellItem(group);
      }
    }

    processSpellGroup(addSpellsData);
    return descriptors;
  }

  /// Exhaustively extracts clean spell names from compendium structures.
  static Set<String> extractSpellNames(dynamic addSpellsData) {
    return extractSpellDescriptors(addSpellsData).keys.toSet();
  }

  /// Exhaustively extracts [FeatureGrant.bonusSpell] grants from compendium additionalSpells data.
  static List<FeatureGrant> extractBonusSpells(
      dynamic addSpellsData, String ownerPrefix, String ownerSlug) {
    final descriptors = extractSpellDescriptors(addSpellsData);
    final grants = <FeatureGrant>[];
    final seenSlugs = <String>{};

    for (final entry in descriptors.entries) {
      final clean = entry.key;
      final isCantrip = entry.value;
      final slug = clean
          .toLowerCase()
          .replaceAll(RegExp(r"['’]"), '')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      if (slug.isNotEmpty && seenSlugs.add(slug)) {
        grants.add(FeatureGrant.bonusSpell(
          grantId: '$ownerPrefix-$ownerSlug-spell-$slug',
          slug: slug,
          displayName: clean,
          isCantrip: isCantrip,
          label: '$clean (${isCantrip ? 'Cantrip' : 'Bonus Spell'})',
        ));
      }
    }

    return grants;
  }
}
