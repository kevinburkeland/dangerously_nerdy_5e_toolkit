/// Catalog of 2024 Revised rules differences and mechanical updates for 5e SRD monsters.
class SrdMonster2024Diffs {
  static const Map<String, ({String summary, List<String> highlights})> diffs = {
    'aboleth': (
      summary: 'Psychic damage integrated directly into Tentacle attacks, Enslave saving throw standardized to DC 14 Wisdom, and bonus action tentacle reactions.',
      highlights: [
        'Psychic damage on Tentacle attacks',
        'Standardized DC 14 Wisdom Enslave',
        'Tail attack damage scaling'
      ],
    ),
    'adultreddragon': (
      summary: 'Wing Attack integrated into bonus action reactions, Fire Breath saving throws streamlined, and enhanced legendary resistance rules.',
      highlights: [
        'Wing Attack reaction upgrade',
        'Streamlined DC 21 Fire Breath',
        'Standardized Frightful Presence'
      ],
    ),
    'adultbluedragon': (
      summary: 'Lightning Breath save DC standardized, bonus action reactions for aerial mobility, and streamlined legendary actions.',
      highlights: [
        'Streamlined DC 19 Lightning Breath',
        'Aerial mobility bonus reaction',
        'Legendary action recharge'
      ],
    ),
    'adultgreendragon': (
      summary: 'Poison Breath and amphibious traits updated to 2024 revised condition rules.',
      highlights: [
        'DC 18 Constitution Poison Breath',
        'Streamlined multiattack sequence'
      ],
    ),
    'adultblackdragon': (
      summary: 'Acid Breath line geometry and save DC standardized with revised darkness traits.',
      highlights: [
        'DC 18 Dexterity Acid Breath',
        'Amphibious and stealth enhancements'
      ],
    ),
    'adultwhitedragon': (
      summary: 'Cold Breath damage dice and cone area standardized with ice walk mobility.',
      highlights: [
        'DC 19 Constitution Cold Breath',
        'Burrowing ice walk mechanics'
      ],
    ),
    'mage': (
      summary: 'Replaces complex spell slot tracking with streamlined Arcane Burst spell attacks, at-will utility spells, and bonus action reactions (Shield & Misty Step).',
      highlights: [
        'Arcane Burst replaces spell slot bookkeeping',
        'Shield & Misty Step as dedicated reactions/bonus actions',
        'Standardized spell save DC 14'
      ],
    ),
    'archmage': (
      summary: 'Streamlined spell attacks with Arcane Burst and multi-target destructive bursts instead of rigid spell slot grids.',
      highlights: [
        'High-tier Arcane Burst attacks',
        'Time Stop & Teleport action streamlined',
        'Instant defensive reactions'
      ],
    ),
    'cultfanatic': (
      summary: 'Replaces spell slot bookkeeping with Radiant / Necrotic Burst actions and simplified spell list.',
      highlights: [
        'Radiant / Necrotic attack action',
        'Streamlined spellcasting rules',
        'Dark Devotion advantage on charm/frighten'
      ],
    ),
    'priest': (
      summary: 'Replaces rigid spell slot grid with Radiant Strike and Divine Burst action options.',
      highlights: [
        'Radiant Burst action',
        'Simplified healing actions',
        'Standardized spell DC'
      ],
    ),
    'druid': (
      summary: 'Nature Burst and elemental strike actions replace spell slot tracking with simplified Wild Shape utility.',
      highlights: [
        'Nature Burst ranged spell attack',
        'Quarterstaff Shillelagh strike',
        'Streamlined spell list'
      ],
    ),
    'vampire': (
      summary: 'Unarmed strike grapple mechanics integrated directly into basic attacks, necrotic bite healing streamlined.',
      highlights: [
        'Grapple built into Unarmed Strike',
        'Streamlined necrotic bite healing',
        'Shapechanger bonus action'
      ],
    ),
    'vampirespawn': (
      summary: 'Claws and Bite attacks streamlined with automatic grapple and necrotic health drain.',
      highlights: [
        'Integrated grapple on Claws',
        'Necrotic HP drain on Bite',
        'Spider Climb speed 30 ft'
      ],
    ),
    'hydra': (
      summary: 'Reactive heads grant 1 opportunity attack per head each round with streamlined head regrowth mechanics.',
      highlights: [
        'Multiple reactive opportunity attacks',
        'Standardized head regrowth threshold (25 HP)',
        'Multiattack scales with head count'
      ],
    ),
    'goblin': (
      summary: 'Nimble Escape streamlined as an explicit bonus action (Disengage or Hide on each turn).',
      highlights: [
        'Bonus action Nimble Escape',
        'Standardized scimitar and shortbow dice'
      ],
    ),
    'kobold': (
      summary: 'Pack Tactics and Sunlight Sensitivity refined for 2024 advantage/disadvantage condition rules.',
      highlights: [
        'Pack Tactics advantage clarity',
        'Dagger and sling stats standardized'
      ],
    ),
    'orc': (
      summary: 'Aggressive trait upgraded to bonus action Dash with temporary hit points upon closing distance.',
      highlights: [
        'Bonus action Aggressive Dash',
        'Greataxe 1d12 + 3 damage'
      ],
    ),
    'hobgoblin': (
      summary: 'Martial Advantage damage bonus clarified to once per turn on attack hit.',
      highlights: [
        'Martial Advantage extra 2d6 damage',
        'Longsword and longbow attacks'
      ],
    ),
    'skeleton': (
      summary: 'Shortsword and Shortbow attacks standardized with complete damage vulnerability to bludgeoning.',
      highlights: [
        'Bludgeoning damage vulnerability',
        'Poison immunity and exhaustion immunity'
      ],
    ),
    'zombie': (
      summary: 'Undead Fortitude DC formula standardized to 5 + damage taken to prevent falling to 0 HP.',
      highlights: [
        'Standardized DC Undead Fortitude',
        'Slam attack 1d6 + 1 bludgeoning'
      ],
    ),
    'ghoul': (
      summary: 'Claws attack paralysis DC standardized to DC 10 Constitution, elf immunity preserved.',
      highlights: [
        'DC 10 Constitution paralysis on Claws',
        'Bite and Claws Multiattack'
      ],
    ),
    'wight': (
      summary: 'Life Drain action max HP reduction lasts until a long rest with temp HP gain.',
      highlights: [
        'Life Drain necrotic damage + max HP reduction',
        'Sunlight Sensitivity condition updates'
      ],
    ),
    'banditcaptain': (
      summary: 'Multiattack sequence (2 Scimitars + 1 Dagger) and Parry reaction streamlined.',
      highlights: [
        '3-attack Multiattack sequence',
        'Parry reaction (+2 AC against 1 melee attack)'
      ],
    ),
    'veteran': (
      summary: 'Multiattack (2 Longswords + 1 Shortsword) and Heavy Crossbow ranged options updated.',
      highlights: [
        '3-attack Multiattack sequence',
        'Heavy Crossbow ranged option'
      ],
    ),
    'knight': (
      summary: 'Brave trait advantage and Leadership bonus action command die updated for 2024 action economy.',
      highlights: [
        'Leadership d4 bonus to allies',
        'Parry reaction for defense'
      ],
    ),
    'bugbear': (
      summary: 'Surprise Attack extra 2d6 damage applies during round 1 against targets that have not acted.',
      highlights: [
        'Surprise Attack extra 2d6 damage',
        'Brute extra weapon damage die'
      ],
    ),
    'giantspider': (
      summary: 'Web recharge action save DC standardized to DC 12, spider climb and web sense clarified.',
      highlights: [
        'DC 12 Dexterity Web recharge',
        'Bite poison damage and paralysis threshold'
      ],
    ),
    'behir': (
      summary: 'Lightning Breath save DC standardized to DC 16 Dexterity, Constrict and Swallow mechanics streamlined.',
      highlights: [
        'DC 16 Dexterity Lightning Breath (12d10)',
        'Constrict + Swallow action sequence'
      ],
    ),
    'chimera': (
      summary: 'Fire Breath can replace one attack in its 3-attack Multiattack sequence (Bite, Horns, Claws).',
      highlights: [
        'Fire Breath integrated with Multiattack',
        'DC 15 Dexterity Fire Breath (7d8)'
      ],
    ),
    'lich': (
      summary: 'Disrupt Life necrotic damage aura and Paralyzing Touch action updated with revised save DCs.',
      highlights: [
        'Disrupt Life necrotic aura',
        'DC 18 Constitution Paralyzing Touch',
        'Streamlined legendary resistance'
      ],
    ),
    'giantape': (
      summary: 'Fist strikes and Rock throw damage formulas aligned with 2024 monster attack math.',
      highlights: [
        '+9 to hit Fist strikes (3d10 + 6)',
        'Rock throw range 50/100 ft (7d6 + 6)'
      ],
    ),
    'harpy': (
      summary: 'Luring Song save DC updated to standardized charisma formula (DC 11 Wisdom).',
      highlights: [
        'DC 11 Wisdom Luring Song',
        'Claws & Club Multiattack sequence'
      ],
    ),
    'gargoyle': (
      summary: 'Damage resistances updated to reflect 2024 physical damage resistance rules.',
      highlights: [
        'Non-magical physical damage resistance',
        'Multiattack Bite + Claws'
      ],
    ),
    'minotaur': (
      summary: 'Charge damage and Goring Rush bonus action streamlined for 2024 action economy.',
      highlights: [
        'Charge extra 2d8 on 10+ ft move',
        'Reckless attack mechanic'
      ],
    ),
    'troll': (
      summary: 'Regeneration stopping conditions (Acid/Fire) aligned with 2024 damage timing rules.',
      highlights: [
        '10 HP Regeneration timing',
        'Multiattack 1 Bite + 2 Claws'
      ],
    ),
  };

  static ({String summary, List<String> highlights})? getDiff(String monsterId, String monsterName) {
    final key1 = monsterId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key2 = monsterName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return diffs[key1] ?? diffs[key2];
  }
}
