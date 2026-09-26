/// Canonical SRD 5.1 and SRD 5.2.1 Allowlists for Tabletop Content.
///
/// Provenance:
/// - SRD 5.1: Released by Wizards of the Coast LLC under CC-BY-4.0 (January 2023).
/// - SRD 5.2.1: Released by Wizards of the Coast LLC under CC-BY-4.0 (2024/2025).
/// - Original Project Content: Tabletop abstraction rules, formulas, and UI structures.
library;

/// Legal provenance source for SRD material.
enum SrdProvenance {
  /// Included in System Reference Document 5.1 under CC-BY-4.0.
  srd51,

  /// Included in System Reference Document 5.2.1 under CC-BY-4.0.
  srd521,

  /// Included in both SRD 5.1 and SRD 5.2.1 under CC-BY-4.0.
  both,
}

// =============================================================================
// CLASSES
// =============================================================================

/// Canonical classes present in SRD 5.1 and SRD 5.2.1.
const Map<String, SrdProvenance> canonicalSrdClassesWithProvenance = {
  'barbarian': SrdProvenance.both,
  'bard': SrdProvenance.both,
  'cleric': SrdProvenance.both,
  'druid': SrdProvenance.both,
  'fighter': SrdProvenance.both,
  'monk': SrdProvenance.both,
  'paladin': SrdProvenance.both,
  'ranger': SrdProvenance.both,
  'rogue': SrdProvenance.both,
  'sorcerer': SrdProvenance.both,
  'warlock': SrdProvenance.both,
  'wizard': SrdProvenance.both,
};

/// Set of all canonically permitted SRD class identifiers.
const Set<String> canonicalSrdClasses = {
  'barbarian',
  'bard',
  'cleric',
  'druid',
  'fighter',
  'monk',
  'paladin',
  'ranger',
  'rogue',
  'sorcerer',
  'warlock',
  'wizard',
};

/// Subset of classes currently bundled by this application.
const Set<String> bundledBaseClassSlugs = canonicalSrdClasses;

// =============================================================================
// SUBCLASSES
// =============================================================================

/// Canonical subclasses present in SRD 5.1 and SRD 5.2.1 (one per base class).
const Set<String> canonicalSrdSubclasses = {
  'berserker',
  'path-of-the-berserker',
  'lore',
  'college-of-lore',
  'life',
  'life-domain',
  'land',
  'circle-of-the-land',
  'champion',
  'open-hand',
  'open_hand',
  'way-of-the-open-hand',
  'warrior-of-the-open-hand',
  'devotion',
  'oath-of-devotion',
  'hunter',
  'thief',
  'draconic',
  'draconic-bloodline',
  'draconic-sorcery',
  'fiend',
  'the-fiend',
  'fiend-patron',
  'evocation',
  'school-of-evocation',
  'evoker',
};

// =============================================================================
// SPECIES / LINEAGES
// =============================================================================

/// Canonical species present in SRD 5.1 and SRD 5.2.1 with provenance.
const Map<String, SrdProvenance> canonicalSrdSpeciesWithProvenance = {
  'human': SrdProvenance.both,
  'human-variant': SrdProvenance.srd51,
  'variant-human': SrdProvenance.srd51,
  'elf': SrdProvenance.both,
  'dwarf': SrdProvenance.both,
  'halfling': SrdProvenance.both,
  'dragonborn': SrdProvenance.both,
  'gnome': SrdProvenance.both,
  'half-elf': SrdProvenance.srd51,
  'half-orc': SrdProvenance.srd51,
  'tiefling': SrdProvenance.both,
  'orc': SrdProvenance.srd521,
  'goliath': SrdProvenance.srd521,
};

/// Set of all canonically permitted SRD species identifiers.
const Set<String> canonicalSrdSpecies = {
  'human',
  'human-variant',
  'variant-human',
  'elf',
  'dwarf',
  'halfling',
  'dragonborn',
  'gnome',
  'half-elf',
  'half-orc',
  'tiefling',
  'orc',
  'goliath',
};

/// Subset of species currently bundled by this application.
const Set<String> bundledBaseSpeciesSlugs = {
  'dragonborn',
  'dwarf',
  'elf',
  'gnome',
  'goliath',
  'half-elf',
  'half-orc',
  'halfling',
  'human',
  'tiefling',
};

// =============================================================================
// FEATS
// =============================================================================

/// Canonical feats explicitly published in SRD 5.1 and SRD 5.2.1 under CC-BY-4.0.
///
/// Provenance:
/// - SRD 5.1: Grappler (p. 58).
/// - SRD 5.2.1: 20 feats across Origin, General, Fighting Style, and Epic Boon categories.
const Map<String, SrdProvenance> canonicalSrdFeatsWithProvenance = {
  // General Feats
  'grappler': SrdProvenance.both,
  'ability-score-improvement': SrdProvenance.srd521,

  // Origin Feats (SRD 5.2.1)
  'alert': SrdProvenance.srd521,
  'magic-initiate': SrdProvenance.srd521,
  'savage-attacker': SrdProvenance.srd521,
  'skilled': SrdProvenance.srd521,

  // Fighting Style Feats (SRD 5.2.1)
  'archery': SrdProvenance.srd521,
  'defense': SrdProvenance.srd521,
  'great-weapon-fighting': SrdProvenance.srd521,
  'two-weapon-fighting': SrdProvenance.srd521,

  // Epic Boon Feats (SRD 5.2.1)
  'boon-of-combat-prowess': SrdProvenance.srd521,
  'boon-of-dimensional-travel': SrdProvenance.srd521,
  'boon-of-energy-evasion': SrdProvenance.srd521,
  'boon-of-fate': SrdProvenance.srd521,
  'boon-of-fortitude': SrdProvenance.srd521,
  'boon-of-irresistible-offense': SrdProvenance.srd521,
  'boon-of-recovery': SrdProvenance.srd521,
  'boon-of-skill-proficiency': SrdProvenance.srd521,
  'boon-of-speed': SrdProvenance.srd521,
  'boon-of-spell-recall': SrdProvenance.srd521,
  'boon-of-the-night-spirit': SrdProvenance.srd521,
  'boon-of-truesight': SrdProvenance.srd521,
};

/// Set of all canonically permitted SRD feats across SRD 5.1 and SRD 5.2.1.
const Set<String> canonicalAllowedFeats = {
  'grappler',
  'ability-score-improvement',
  'alert',
  'magic-initiate',
  'savage-attacker',
  'skilled',
  'archery',
  'defense',
  'great-weapon-fighting',
  'two-weapon-fighting',
  'boon-of-combat-prowess',
  'boon-of-dimensional-travel',
  'boon-of-energy-evasion',
  'boon-of-fate',
  'boon-of-fortitude',
  'boon-of-irresistible-offense',
  'boon-of-recovery',
  'boon-of-skill-proficiency',
  'boon-of-speed',
  'boon-of-spell-recall',
  'boon-of-the-night-spirit',
  'boon-of-truesight',
};

/// Alias for backwards compatibility.
const Set<String> canonicalSrdFeats = canonicalAllowedFeats;

/// Subset of feats currently bundled in this application.
const Set<String> bundledBaseFeatSlugs = {
  'grappler',
};

// =============================================================================
// BACKGROUNDS
// =============================================================================

/// Canonical backgrounds published in SRD 5.1 (Acolyte, p. 60) and SRD 5.2.1.
const Map<String, SrdProvenance> canonicalSrdBackgroundsWithProvenance = {
  'acolyte': SrdProvenance.both,
};

const Set<String> canonicalAllowedBackgrounds = {
  'acolyte',
};
