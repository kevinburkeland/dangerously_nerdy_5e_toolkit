import 'package:flutter/foundation.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/feature_grant.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/spellbook_data.dart';

/// Innate/Racial native spell model for spells granted by species or racial heritage.
@immutable
class InnateSpeciesSpell {
  final EntityReference<Spell> spellRef;
  final int minCharacterLevel;
  final String castingAbility;
  final bool isCantrip;
  final int chargesPerLongRest; // 1 = once per long rest, 0 = at will (cantrip)

  const InnateSpeciesSpell({
    required this.spellRef,
    required this.minCharacterLevel,
    this.castingAbility = 'Charisma',
    this.isCantrip = false,
    this.chargesPerLongRest = 1,
  });
}

/// Structured collision and allocation report for skills.
@immutable
class SkillCollisionReport {
  final Map<SkillType, String> grantedSkills; // Skill -> Source description
  final List<SkillType> collidingSkills; // Collisions detected
  final int compensatoryPicksEarned; // Count of free compensatory selections granted
  final Set<SkillType> availableSkillPool; // Unassigned skills eligible for compensatory pick
  final Map<SkillType, SkillProficiencyLevel> resolvedProficiencies;

  const SkillCollisionReport({
    required this.grantedSkills,
    required this.collidingSkills,
    required this.compensatoryPicksEarned,
    required this.availableSkillPool,
    required this.resolvedProficiencies,
  });
}

/// Pure rules engine for resolving skill collisions, compensatory picks, and racial traits.
class SkillTraitResolver {
  SkillTraitResolver._();

  /// Resolves background fixed skills, species fixed skills, and class selections.
  /// When a class skill selection collides with a background/species grant, a compensatory pick is granted.
  static SkillCollisionReport resolveSkills({
    String? speciesSlug,
    String? subraceSlug,
    required String? backgroundSlug,
    required String classSlug,
    required Set<SkillType> requestedClassSkills,
    required Set<SkillType> compensatoryPicks,
    Set<SkillType> speciesBonusSkills = const {},
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final granted = <SkillType, String>{};
    final collisions = <SkillType>[];
    final resolved = <SkillType, SkillProficiencyLevel>{};

    // 1. Ingest Species Fixed & Bonus Skills
    if (speciesSlug != null) {
      final race = SrdSpeciesLibrary.findBySlug(speciesSlug);
      if (race != null) {
        for (final grant in race.grants) {
          if (grant.type == GrantType.bonusSkill) {
            final skillName = grant.payload['skill']?.toString() ?? grant.label ?? '';
            final skill = SkillType.tryParse(skillName);
            if (skill != null) {
              granted[skill] = 'Species: ${race.name} ($skillName)';
            }
          }
        }
        if (race.customProperties['skillProficiencies'] is List) {
          for (final sp in race.customProperties['skillProficiencies'] as List) {
            if (sp is Map) {
              for (final k in sp.keys) {
                final skill = SkillType.tryParse(k.toString());
                if (skill != null) {
                  granted[skill] = 'Species: ${race.name}';
                }
              }
            }
          }
        }
      }

      final sSlug = speciesSlug.toLowerCase();
      if (sSlug.contains('elf') && !sSlug.contains('half-elf')) {
        granted[SkillType.perception] = 'Species: Elf (Keen Senses)';
      } else if (sSlug.contains('half-orc') || sSlug.contains('orc')) {
        granted[SkillType.intimidation] = 'Species: Half-Orc (Menacing)';
      }
    }

    // 1b. Ingest Subrace Fixed Skills
    if (subraceSlug != null && subraceSlug.isNotEmpty) {
      final subrace = SrdSpeciesLibrary.findSubraceBySlug(subraceSlug);
      if (subrace != null) {
        for (final grant in subrace.grants) {
          if (grant.type == GrantType.bonusSkill) {
            final skillName = grant.payload['skill']?.toString() ?? grant.label ?? '';
            final skill = SkillType.tryParse(skillName);
            if (skill != null) {
              _addOrCollide(granted, collisions, skill, 'Subrace: ${subrace.name} ($skillName)');
            }
          }
        }
        if (subrace.customProperties['skillProficiencies'] is List) {
          for (final sp in subrace.customProperties['skillProficiencies'] as List) {
            if (sp is Map) {
              for (final k in sp.keys) {
                final skill = SkillType.tryParse(k.toString());
                if (skill != null) {
                  _addOrCollide(granted, collisions, skill, 'Subrace: ${subrace.name}');
                }
              }
            }
          }
        }
      }
    }

    for (final sk in speciesBonusSkills) {
      _addOrCollide(granted, collisions, sk, 'Species: Bonus Skill Choice');
    }

    // 2. Ingest Background Fixed Skills
    if (backgroundSlug != null) {
      final bg = backgroundSlug.toLowerCase();
      switch (bg) {
        case 'acolyte':
          _addOrCollide(granted, collisions, SkillType.insight, 'Background: Acolyte');
          _addOrCollide(granted, collisions, SkillType.religion, 'Background: Acolyte');
        case 'criminal':
        case 'spy':
          _addOrCollide(granted, collisions, SkillType.deception, 'Background: Criminal');
          _addOrCollide(granted, collisions, SkillType.stealth, 'Background: Criminal');
        case 'entertainer':
          _addOrCollide(granted, collisions, SkillType.acrobatics, 'Background: Entertainer');
          _addOrCollide(granted, collisions, SkillType.performance, 'Background: Entertainer');
        case 'folk-hero':
        case 'folk_hero':
        case 'guide':
          _addOrCollide(granted, collisions, SkillType.animalHandling, 'Background: Folk Hero');
          _addOrCollide(granted, collisions, SkillType.survival, 'Background: Folk Hero');
        case 'guild-artisan':
        case 'guild_artisan':
        case 'merchant':
          _addOrCollide(granted, collisions, SkillType.insight, 'Background: Guild Artisan');
          _addOrCollide(granted, collisions, SkillType.persuasion, 'Background: Guild Artisan');
        case 'noble':
          _addOrCollide(granted, collisions, SkillType.history, 'Background: Noble');
          _addOrCollide(granted, collisions, SkillType.persuasion, 'Background: Noble');
        case 'sage':
          _addOrCollide(granted, collisions, SkillType.arcana, 'Background: Sage');
          _addOrCollide(granted, collisions, SkillType.history, 'Background: Sage');
        case 'sailor':
          _addOrCollide(granted, collisions, SkillType.athletics, 'Background: Sailor');
          _addOrCollide(granted, collisions, SkillType.perception, 'Background: Sailor');
        case 'soldier':
          _addOrCollide(granted, collisions, SkillType.athletics, 'Background: Soldier');
          _addOrCollide(granted, collisions, SkillType.intimidation, 'Background: Soldier');
        case 'urchin':
          _addOrCollide(granted, collisions, SkillType.sleightOfHand, 'Background: Urchin');
          _addOrCollide(granted, collisions, SkillType.stealth, 'Background: Urchin');
      }
    }

    // 3. Process Requested Class Skills & Detect Overlaps
    for (final skill in requestedClassSkills) {
      if (granted.containsKey(skill)) {
        collisions.add(skill);
      } else {
        granted[skill] = 'Class: ${classSlug.toUpperCase()}';
      }
    }

    // 4. Ingest Compensatory Picks
    for (final compSkill in compensatoryPicks) {
      if (!granted.containsKey(compSkill)) {
        granted[compSkill] = 'Compensatory Choice (RAW Fallback)';
      }
    }

    // 5. Populate resolved map
    for (final skill in granted.keys) {
      resolved[skill] = SkillProficiencyLevel.proficient;
    }

    // 6. Compute unassigned available skill pool
    final available = SkillType.values.where((s) => !granted.containsKey(s)).toSet();

    return SkillCollisionReport(
      grantedSkills: granted,
      collidingSkills: collisions,
      compensatoryPicksEarned: collisions.length,
      availableSkillPool: available,
      resolvedProficiencies: resolved,
    );
  }

  static void _addOrCollide(
    Map<SkillType, String> granted,
    List<SkillType> collisions,
    SkillType skill,
    String source,
  ) {
    if (granted.containsKey(skill)) {
      collisions.add(skill);
    } else {
      granted[skill] = source;
    }
  }

  /// Calculates dynamic flexible skill bonus count granted by species
  static int getSpeciesBonusSkillCount(String? speciesSlug, DmRulesEdition edition) {
    if (speciesSlug == null) return 0;
    final slug = speciesSlug.toLowerCase();
    if (slug == 'human' && edition == DmRulesEdition.v2024) {
      return 1; // 2024 Human Skillful
    } else if (slug == 'human-variant' || slug == 'human_variant') {
      return 1; // 2014 Variant Human
    } else if (slug == 'half-elf' || slug == 'half_elf') {
      return 2; // Half-Elf Skill Versatility
    } else if (slug == 'custom-lineage' || slug == 'custom_lineage') {
      return 1;
    }
    return 0;
  }

  /// Returns native innate species spells based on character level scaling
  static List<InnateSpeciesSpell> getInnateSpeciesSpells({
    required String speciesSlug,
    required String? subraceSlug,
    required int totalCharacterLevel,
    DmRulesEdition edition = DmRulesEdition.v2024,
    EntityReference<DomainEntity>? subraceRef,
    Map<String, dynamic>? customProperties,
  }) {
    final spells = <InnateSpeciesSpell>[];
    final slug = speciesSlug.toLowerCase();
    final subSlug = subraceSlug?.toLowerCase() ?? '';

    // Check dynamic grants and additionalSpells from Subrace and Species
    final race = SrdSpeciesLibrary.findBySlug(speciesSlug);
    final subrace = (subraceSlug != null && subraceSlug.isNotEmpty)
        ? (SrdSpeciesLibrary.findSubraceBySlug(subraceSlug) ??
            race?.subraces.where((s) => s.id.slug.toLowerCase() == subSlug || s.name.toLowerCase() == subSlug).firstOrNull)
        : null;

    void processGrantsAndSpells(List<FeatureGrant> grants, Map<String, dynamic> customProps) {
      for (final g in grants) {
        if (g.type == GrantType.bonusSpell) {
          final spellSlug = g.payload['slug']?.toString() ?? '';
          final spellName = g.payload['displayName']?.toString() ?? g.label ?? spellSlug;
          final spellFromLib = SpellbookLibrary.getSpellById(spellSlug);
          final isCantrip = g.payload['isCantrip'] == true || spellFromLib?.level == 0;
          if (spellSlug.isNotEmpty && !spells.any((s) => s.spellRef.slug == spellSlug)) {
            spells.add(InnateSpeciesSpell(
              spellRef: EntityReference<Spell>(
                refType: EntityType.spell,
                slug: spellSlug,
                displayName: spellName,
              ),
              minCharacterLevel: 1,
              isCantrip: isCantrip,
              chargesPerLongRest: isCantrip ? 0 : 1,
            ));
          }
        }
      }

      final rawAddSpells = customProps['additionalSpells'] ?? customProps['spells'];
      if (rawAddSpells is List) {
        for (final entry in rawAddSpells) {
          if (entry is Map) {
            for (final sectionKey in ['innate', 'known', 'prepared', 'expanded']) {
              final section = entry[sectionKey];
              if (section is Map) {
                section.forEach((lvlKey, spellList) {
                  int reqLevel = 1;
                  final lvlStr = lvlKey.toString().toLowerCase().trim();
                  if (sectionKey == 'expanded') {
                    if (lvlStr == 's1' || lvlStr == '1' || lvlStr == '_') {
                      reqLevel = 1;
                    } else if (lvlStr == 's2' || lvlStr == '2') {
                      reqLevel = 3;
                    } else if (lvlStr == 's3' || lvlStr == '3') {
                      reqLevel = 5;
                    } else if (lvlStr == 's4' || lvlStr == '4') {
                      reqLevel = 7;
                    } else if (lvlStr == 's5' || lvlStr == '5') {
                      reqLevel = 9;
                    } else {
                      reqLevel = int.tryParse(lvlStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
                    }
                  } else {
                    if (lvlStr == '_') {
                      reqLevel = 1;
                    } else {
                      reqLevel = int.tryParse(lvlStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
                    }
                  }

                  void addSpellItems(dynamic listOrMap) {
                    if (listOrMap is List) {
                      for (final item in listOrMap) {
                        final str = item.toString().trim();
                        final isCantripRaw = str.contains('#c') || lvlStr == '_' || lvlStr == '0' || lvlStr == 's0';
                        final cleanName = str.replaceAll('#c', '').split('|').first.trim();
                        final cleanSlug = cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
                        if (cleanSlug.isEmpty) continue;
                        final spellFromLib = SpellbookLibrary.getSpellById(cleanSlug);
                        final isCantrip = isCantripRaw || spellFromLib?.level == 0;
                        final finalMinLevel = isCantrip ? 1 : reqLevel;
                        if (totalCharacterLevel >= finalMinLevel && !spells.any((s) => s.spellRef.slug == cleanSlug)) {
                          spells.add(InnateSpeciesSpell(
                            spellRef: EntityReference<Spell>(
                              refType: EntityType.spell,
                              slug: cleanSlug,
                              displayName: cleanName,
                            ),
                            minCharacterLevel: finalMinLevel,
                            isCantrip: isCantrip,
                            chargesPerLongRest: isCantrip ? 0 : 1,
                          ));
                        }
                      }
                    } else if (listOrMap is Map) {
                      for (final val in listOrMap.values) {
                        addSpellItems(val);
                      }
                    }
                  }

                  addSpellItems(spellList);
                });
              }
            }
          }
        }
      }
    }

    if (race != null) {
      processGrantsAndSpells(race.grants, race.customProperties);
    }
    if (subrace != null) {
      processGrantsAndSpells(subrace.grants, subrace.customProperties);
    }
    if (subraceRef != null && subraceRef.customProperties.isNotEmpty) {
      final refGrants = <FeatureGrant>[];
      if (subraceRef.customProperties['grants'] is List) {
        for (final g in subraceRef.customProperties['grants'] as List) {
          if (g is Map) {
            try {
              refGrants.add(FeatureGrant.fromMap(Map<String, dynamic>.from(g)));
            } catch (_) {}
          }
        }
      }
      processGrantsAndSpells(refGrants, subraceRef.customProperties);
    }
    if (customProperties != null && customProperties.isNotEmpty) {
      processGrantsAndSpells(const [], customProperties);
    }

    // Baseline SRD species fallbacks
    // Tiefling
    if (slug.contains('tiefling')) {
      if (!spells.any((s) => s.spellRef.slug == 'thaumaturgy')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'thaumaturgy', displayName: 'Thaumaturgy'),
          minCharacterLevel: 1,
          isCantrip: true,
          chargesPerLongRest: 0,
        ));
      }
      if (totalCharacterLevel >= 3 && !spells.any((s) => s.spellRef.slug == 'hellish-rebuke')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'hellish-rebuke', displayName: 'Hellish Rebuke'),
          minCharacterLevel: 3,
          chargesPerLongRest: 1,
        ));
      }
      if (totalCharacterLevel >= 5 && !spells.any((s) => s.spellRef.slug == 'darkness')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'darkness', displayName: 'Darkness'),
          minCharacterLevel: 5,
          chargesPerLongRest: 1,
        ));
      }
    }

    // Drow / Dark Elf
    if (subSlug.contains('drow') || slug.contains('drow')) {
      if (!spells.any((s) => s.spellRef.slug == 'dancing-lights')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'dancing-lights', displayName: 'Dancing Lights'),
          minCharacterLevel: 1,
          isCantrip: true,
          chargesPerLongRest: 0,
        ));
      }
      if (totalCharacterLevel >= 3 && !spells.any((s) => s.spellRef.slug == 'faerie-fire')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'faerie-fire', displayName: 'Faerie Fire'),
          minCharacterLevel: 3,
          chargesPerLongRest: 1,
        ));
      }
      if (totalCharacterLevel >= 5 && !spells.any((s) => s.spellRef.slug == 'darkness')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'darkness', displayName: 'Darkness'),
          minCharacterLevel: 5,
          chargesPerLongRest: 1,
        ));
      }
    }

    // Forest Gnome
    if (subSlug.contains('forest') && slug.contains('gnome')) {
      if (!spells.any((s) => s.spellRef.slug == 'minor-illusion')) {
        spells.add(const InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'minor-illusion', displayName: 'Minor Illusion'),
          minCharacterLevel: 1,
          isCantrip: true,
          chargesPerLongRest: 0,
        ));
      }
    }

    return spells;
  }

  /// Resolves and aggregates tool proficiencies across class, species/subrace, and background.
  /// Resolves and aggregates tool proficiencies across class, species/subrace, background, and feats.
  static List<String> resolveTools({
    List<String> draftTools = const [],
    String? classSlug,
    String? speciesSlug,
    String? subraceSlug,
    String? backgroundSlug,
    List<String> featSlugs = const [],
    Map<String, dynamic>? customProperties,
  }) {
    final tools = <String>{};
    for (final t in draftTools) {
      if (t.trim().isNotEmpty) tools.add(t.trim());
    }

    final cl = classSlug?.toLowerCase().trim();
    if (cl == 'artificer') {
      if (!tools.any((t) => t.toLowerCase().contains('thieves'))) {
        tools.add('Thieves\' Tools');
      }
      if (!tools.any((t) => t.toLowerCase().contains('tinker'))) {
        tools.add('Tinker\'s Tools');
      }
    } else if (cl == 'rogue') {
      if (!tools.any((t) => t.toLowerCase().contains('thieves'))) {
        tools.add('Thieves\' Tools');
      }
    } else if (cl == 'druid') {
      if (!tools.any((t) => t.toLowerCase().contains('herbalism'))) {
        tools.add('Herbalism Kit');
      }
    }

    if (backgroundSlug != null && backgroundSlug.isNotEmpty) {
      final bg = SrdBackgroundsLibrary.findBySlug(backgroundSlug);
      if (bg != null) {
        for (final bt in bg.toolProficiencies) {
          if (!tools.any((t) => t.toLowerCase() == bt.toLowerCase())) {
            tools.add(bt);
          }
        }
      }
    }

    if (speciesSlug != null && speciesSlug.isNotEmpty) {
      final sp = SrdSpeciesLibrary.findBySlug(speciesSlug);
      if (sp != null) {
        for (final g in sp.grants) {
          if (g.type == GrantType.proficiency && g.payload['proficiency'] != null) {
            final prof = g.payload['proficiency'].toString();
            if (_isToolProficiency(prof) && !tools.any((t) => t.toLowerCase() == prof.toLowerCase())) {
              tools.add(prof);
            }
          }
        }
      }
    }

    if (subraceSlug != null && subraceSlug.isNotEmpty) {
      final sub = SrdSpeciesLibrary.findSubraceBySlug(subraceSlug);
      if (sub != null) {
        for (final g in sub.grants) {
          if (g.type == GrantType.proficiency && g.payload['proficiency'] != null) {
            final prof = g.payload['proficiency'].toString();
            if (_isToolProficiency(prof) && !tools.any((t) => t.toLowerCase() == prof.toLowerCase())) {
              tools.add(prof);
            }
          }
        }
      }
    }

    // Feat Tool Proficiencies
    for (final fSlug in featSlugs) {
      final feat = SrdFeatsLibrary.findBySlug(fSlug);
      if (feat != null) {
        for (final g in feat.grants) {
          if (g.type == GrantType.bonusTool && g.payload['tool'] != null) {
            final tName = g.payload['tool'].toString().trim();
            if (tName.isNotEmpty && !tools.any((t) => t.toLowerCase() == tName.toLowerCase())) {
              tools.add(tName);
            }
          } else if (g.type == GrantType.proficiency && g.payload['proficiency'] != null) {
            final pName = g.payload['proficiency'].toString().trim();
            if (_isToolProficiency(pName) && !tools.any((t) => t.toLowerCase() == pName.toLowerCase())) {
              tools.add(pName);
            }
          }
        }
        // Direct property fallback
        final featTools = feat.customProperties['toolProficiencies'] ??
            (feat.customProperties['rawJson'] is Map ? feat.customProperties['rawJson']['toolProficiencies'] : null);
        if (featTools is List) {
          for (final t in featTools) {
            if (t is String && t.trim().isNotEmpty) {
              final tStr = t.trim();
              if (!tools.any((existing) => existing.toLowerCase() == tStr.toLowerCase())) {
                tools.add(tStr);
              }
            } else if (t is Map) {
              t.forEach((toolName, enabled) {
                if (enabled == true || enabled == 1) {
                  final tStr = toolName.toString().trim();
                  if (tStr != 'any' && tStr != 'anyArtisansTool' && !tools.any((existing) => existing.toLowerCase() == tStr.toLowerCase())) {
                    tools.add(tStr);
                  }
                }
              });
            }
          }
        }
      }
    }

    return tools.toList();
  }

  static bool _isToolProficiency(String name) {
    final lower = name.toLowerCase().trim();
    return lower.contains('tool') ||
        lower.contains('kit') ||
        lower.contains('supplies') ||
        lower.contains('utensil') ||
        lower.contains('instrument') ||
        lower.contains('set') ||
        lower.contains('vehicle');
  }

  /// Resolves and aggregates armor proficiencies across class, species/subrace, feats, and custom properties.
  static List<String> resolveArmorProficiencies({
    String? classSlug,
    String? speciesSlug,
    String? subraceSlug,
    List<String> featSlugs = const [],
    Map<String, dynamic>? customProperties,
  }) {
    final armors = <String>{};

    // 1. Class
    if (classSlug != null && classSlug.isNotEmpty) {
      final cls = SrdClassesLibrary.findBySlug(classSlug);
      if (cls != null) {
        for (final a in cls.armorProficiencies) {
          armors.add(_normalizeArmor(a));
        }
      }
    }

    // 2. Species / Subrace
    void extractFromGrants(List<FeatureGrant> grants) {
      for (final g in grants) {
        if (g.type == GrantType.proficiency && g.payload['proficiency'] != null) {
          final p = g.payload['proficiency'].toString();
          if (_isArmorProficiency(p)) {
            armors.add(_normalizeArmor(p));
          }
        }
      }
    }

    if (speciesSlug != null && speciesSlug.isNotEmpty) {
      final sp = SrdSpeciesLibrary.findBySlug(speciesSlug);
      if (sp != null) extractFromGrants(sp.grants);
    }
    if (subraceSlug != null && subraceSlug.isNotEmpty) {
      final sub = SrdSpeciesLibrary.findSubraceBySlug(subraceSlug);
      if (sub != null) extractFromGrants(sub.grants);
    }

    // 3. Feats
    for (final fSlug in featSlugs) {
      final feat = SrdFeatsLibrary.findBySlug(fSlug);
      if (feat != null) {
        extractFromGrants(feat.grants);
        final featArmors = feat.customProperties['armorProficiencies'] ??
            (feat.customProperties['rawJson'] is Map ? feat.customProperties['rawJson']['armorProficiencies'] : null);
        if (featArmors is List) {
          for (final a in featArmors) {
            if (a is String && a.trim().isNotEmpty) {
              armors.add(_normalizeArmor(a.trim()));
            } else if (a is Map) {
              a.forEach((key, val) {
                if (val == true || val == 1) {
                  armors.add(_normalizeArmor(key.toString().trim()));
                }
              });
            }
          }
        }
      }
    }

    // 4. Custom Properties
    if (customProperties != null && customProperties['armorProficiencies'] is List) {
      for (final a in customProperties['armorProficiencies'] as List) {
        armors.add(_normalizeArmor(a.toString()));
      }
    }

    // Canonical ordering: Light Armor, Medium Armor, Heavy Armor, Shields, then others
    const order = ['Light Armor', 'Medium Armor', 'Heavy Armor', 'Shields'];
    final sorted = armors.toList()
      ..sort((a, b) {
        final idxA = order.indexOf(a);
        final idxB = order.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return sorted;
  }

  static bool _isArmorProficiency(String name) {
    final lower = name.toLowerCase().trim();
    return lower.contains('armor') || lower.contains('shield');
  }

  static String _normalizeArmor(String name) {
    final lower = name.toLowerCase().trim();
    return switch (lower) {
      'light' || 'light armor' => 'Light Armor',
      'medium' || 'medium armor' => 'Medium Armor',
      'heavy' || 'heavy armor' => 'Heavy Armor',
      'shield' || 'shields' => 'Shields',
      _ => name.trim(),
    };
  }

  /// Resolves and aggregates weapon proficiencies across class, species/subrace, feats, and custom properties.
  static List<String> resolveWeaponProficiencies({
    String? classSlug,
    String? speciesSlug,
    String? subraceSlug,
    List<String> featSlugs = const [],
    Map<String, dynamic>? customProperties,
  }) {
    final weapons = <String>{};

    // 1. Class
    if (classSlug != null && classSlug.isNotEmpty) {
      final cls = SrdClassesLibrary.findBySlug(classSlug);
      if (cls != null) {
        for (final w in cls.weaponProficiencies) {
          weapons.add(_normalizeWeapon(w));
        }
      }
    }

    // 2. Species / Subrace
    void extractFromGrants(List<FeatureGrant> grants) {
      for (final g in grants) {
        if (g.type == GrantType.proficiency && g.payload['proficiency'] != null) {
          final p = g.payload['proficiency'].toString();
          if (!_isArmorProficiency(p) && !_isToolProficiency(p)) {
            weapons.add(_normalizeWeapon(p));
          }
        }
      }
    }

    if (speciesSlug != null && speciesSlug.isNotEmpty) {
      final sp = SrdSpeciesLibrary.findBySlug(speciesSlug);
      if (sp != null) extractFromGrants(sp.grants);
    }
    if (subraceSlug != null && subraceSlug.isNotEmpty) {
      final sub = SrdSpeciesLibrary.findSubraceBySlug(subraceSlug);
      if (sub != null) extractFromGrants(sub.grants);
    }

    // 3. Feats
    for (final fSlug in featSlugs) {
      final feat = SrdFeatsLibrary.findBySlug(fSlug);
      if (feat != null) {
        extractFromGrants(feat.grants);
        final featWeapons = feat.customProperties['weaponProficiencies'] ??
            (feat.customProperties['rawJson'] is Map ? feat.customProperties['rawJson']['weaponProficiencies'] : null);
        if (featWeapons is List) {
          for (final w in featWeapons) {
            if (w is String && w.trim().isNotEmpty) {
              weapons.add(_normalizeWeapon(w.trim()));
            } else if (w is Map) {
              w.forEach((key, val) {
                if (val == true || val == 1) {
                  weapons.add(_normalizeWeapon(key.toString().trim()));
                }
              });
            }
          }
        }
      }
    }

    // 4. Custom Properties
    if (customProperties != null && customProperties['weaponProficiencies'] is List) {
      for (final w in customProperties['weaponProficiencies'] as List) {
        weapons.add(_normalizeWeapon(w.toString()));
      }
    }

    return weapons.toList()..sort();
  }

  static String _normalizeWeapon(String name) {
    final lower = name.toLowerCase().trim();
    return switch (lower) {
      'simple' || 'simple weapon' || 'simple weapons' => 'Simple Weapons',
      'martial' || 'martial weapon' || 'martial weapons' => 'Martial Weapons',
      _ => name.trim(),
    };
  }

  /// Derives native physical and sensory traits from species
  static ({int baseSpeedFeet, int darkvisionFeet, int hpPerLevelBonus, bool powerfulBuild}) getSpeciesTraits({
    required String speciesSlug,
    required String? subraceSlug,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final slug = speciesSlug.toLowerCase();
    final subSlug = subraceSlug?.toLowerCase() ?? '';

    final race = SrdSpeciesLibrary.findBySlug(speciesSlug);
    final subrace = subraceSlug != null && subraceSlug.isNotEmpty
        ? SrdSpeciesLibrary.findSubraceBySlug(subraceSlug)
        : null;

    int speed = 30;
    int darkvision = 0;
    int hpBonus = 0;
    bool powerfulBuild = false;

    // Speed calculation: subrace overrides or fallback to race
    if (subrace?.speed != null && subrace!.speed!.isNotEmpty) {
      final parsedSubSpeed = int.tryParse(RegExp(r'\d+').firstMatch(subrace.speed!)?.group(0) ?? '');
      if (parsedSubSpeed != null && parsedSubSpeed > 0) {
        speed = parsedSubSpeed;
      }
    } else if (race != null) {
      final parsedSpeed = int.tryParse(RegExp(r'\d+').firstMatch(race.speed)?.group(0) ?? '');
      if (parsedSpeed != null && parsedSpeed > 0) {
        speed = parsedSpeed;
      }
    } else if (subSlug.contains('wood') || subSlug.contains('wood-elf')) {
      speed = 35;
    } else if (slug == 'goliath') {
      speed = edition == DmRulesEdition.v2024 ? 35 : 30;
    } else if (edition == DmRulesEdition.v2014 &&
        (slug == 'dwarf' || slug == 'gnome' || slug == 'halfling')) {
      speed = 25;
    }

    // Darkvision: subrace overrides or race setting
    if (subrace?.darkvision != null && subrace!.darkvision! > 0) {
      darkvision = subrace.darkvision!;
    } else if (race?.customProperties['hasDarkvision'] == true) {
      darkvision = (race?.customProperties['darkvisionFeet'] as num?)?.toInt() ?? 60;
    } else if (slug.contains('elf') || slug.contains('dwarf') || slug.contains('gnome') ||
        slug.contains('half-orc') || slug.contains('tiefling')) {
      darkvision = (subSlug.contains('drow') || slug.contains('drow')) ? 120 : 60;
    }

    // Powerful build
    if (race?.traitsMarkdown.toLowerCase().contains('powerful build') == true ||
        subrace?.traitsMarkdown.toLowerCase().contains('powerful build') == true ||
        slug == 'goliath') {
      powerfulBuild = true;
    }

    // Dwarven Toughness / HP bonus
    if (subrace?.traitsMarkdown.toLowerCase().contains('dwarven toughness') == true ||
        subrace?.traitsMarkdown.toLowerCase().contains('hit point maximum increases by 1') == true ||
        (slug.contains('dwarf') && (edition == DmRulesEdition.v2024 || subSlug.contains('hill')))) {
      hpBonus = 1;
    }

    return (
      baseSpeedFeet: speed,
      darkvisionFeet: darkvision,
      hpPerLevelBonus: hpBonus,
      powerfulBuild: powerfulBuild,
    );
  }
}
