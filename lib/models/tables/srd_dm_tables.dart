import 'rollable_table.dart';

/// Complete 5e SRD DM & Gameplay Reference Tables (Madness, Hazards, Traps, Carousing, NPC Generators).
class SrdDmTables {
  SrdDmTables._();

  // ==========================================
  // MADNESS TABLES (Short, Long, Indefinite)
  // ==========================================
  static const RollableTable shortTermMadness = RollableTable(
    id: 'short_term_madness',
    name: 'Short-Term Madness (1d10 Minutes)',
    category: TableCategory.dmGameplay,
    diceFormula: '1d100',
    description: 'Short-term madness affects a creature for 1d10 minutes. A Lesser Restoration spell or similar can cure the effect.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 20, label: 'Retreating into mind (Incapacitated)', description: 'The character retreats into his or her mind and becomes paralyzed. The effect ends if the character takes any damage.'),
      TableEntry(minRoll: 21, maxRoll: 30, label: 'Incapacitated (Screaming/Weeping)', description: 'The character becomes incapacitated and spends the duration screaming, laughing, or weeping uncontrollably.'),
      TableEntry(minRoll: 31, maxRoll: 40, label: 'Frightened (Must Flee)', description: 'The character becomes frightened and must use his or her action and movement each round to flee from the source of the fear.'),
      TableEntry(minRoll: 41, maxRoll: 50, label: 'Babbling incoherently', description: 'The character begins babbling and is incapable of normal speech or spellcasting.'),
      TableEntry(minRoll: 51, maxRoll: 60, label: 'Attack nearest creature each turn', description: 'The character must use his or her action each round to attack the nearest creature.'),
      TableEntry(minRoll: 61, maxRoll: 70, label: 'Vivid hallucinations', description: 'The character experiences vivid hallucinations and has disadvantage on ability checks.'),
      TableEntry(minRoll: 71, maxRoll: 75, label: 'Extreme compulsion', description: 'The character does whatever anyone tells him or her to do that isn\'t obviously self-destructive.'),
      TableEntry(minRoll: 76, maxRoll: 80, label: 'Overpowering urge to eat strange things', description: 'The character experiences an overpowering urge to eat something strange such as dirt, slime, or raw offal.'),
      TableEntry(minRoll: 81, maxRoll: 90, label: 'Stunned', description: 'The character is stunned.'),
      TableEntry(minRoll: 91, maxRoll: 100, label: 'Falls unconscious', description: 'The character falls unconscious for the duration.'),
    ],
  );

  static const RollableTable longTermMadness = RollableTable(
    id: 'long_term_madness',
    name: 'Long-Term Madness (1d10 × 10 Hours)',
    category: TableCategory.dmGameplay,
    diceFormula: '1d100',
    description: 'Long-term madness affects a creature for 1d10 × 10 hours. Greater Restoration or Calm Emotions can alleviate symptoms.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 10, label: 'Compulsive behavior', description: 'The character feels compelled to repeat a specific activity over and over, such as washing hands, pacing, or counting coins.'),
      TableEntry(minRoll: 11, maxRoll: 20, label: 'Vivid hallucinations & disadvantage', description: 'The character experiences vivid hallucinations and has disadvantage on ability checks.'),
      TableEntry(minRoll: 21, maxRoll: 30, label: 'Extreme paranoia', description: 'The character suffers extreme paranoia. The character has disadvantage on Wisdom and Charisma checks and can\'t gain advantage on anything.'),
      TableEntry(minRoll: 31, maxRoll: 40, label: 'Severe aversion / phobia', description: 'The character experiences a severe phobia regarding something specific, regarding it as frightening.'),
      TableEntry(minRoll: 41, maxRoll: 45, label: 'Loss of memory (Amnesia)', description: 'The character experiences a total amnesia concerning their identity and friends.'),
      TableEntry(minRoll: 46, maxRoll: 55, label: 'Attachment to a lucky object', description: 'The character becomes attached to a lucky charm or mundane object and has disadvantage on attack rolls, ability checks, and saves while separated from it.'),
      TableEntry(minRoll: 56, maxRoll: 65, label: 'Blinded (psychosomatic)', description: 'The character is psychosomatically blinded.'),
      TableEntry(minRoll: 66, maxRoll: 75, label: 'Deafened (psychosomatic)', description: 'The character is psychosomatically deafened.'),
      TableEntry(minRoll: 76, maxRoll: 85, label: 'Tremors and shaking', description: 'The character experiences uncontrollable tremors or tics, having disadvantage on attack rolls and Dexterity checks.'),
      TableEntry(minRoll: 86, maxRoll: 95, label: 'Incapable of speaking the truth', description: 'The character feels compelled to lie about everything, even minor details.'),
      TableEntry(minRoll: 96, maxRoll: 100, label: 'Catatonic stupor', description: 'The character falls into a catatonic stupor, incapacitated until cured.'),
    ],
  );

  static const RollableTable indefiniteMadness = RollableTable(
    id: 'indefinite_madness',
    name: 'Indefinite Madness (Permanent Flaws)',
    category: TableCategory.dmGameplay,
    diceFormula: '1d100',
    description: 'Indefinite madness imposes a permanent character flaw that lasts until cured by a Greater Restoration or Heal spell.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 15, label: 'Intoxication Dependency', description: '"Being drunk or high keeps me sane. I\'m constantly seeking my next drink or smoke."'),
      TableEntry(minRoll: 16, maxRoll: 25, label: 'Secret Hoarder', description: '"I keep whatever I find. I must hoard my treasures in secret caches where no one can find them."'),
      TableEntry(minRoll: 26, maxRoll: 30, label: 'Treacherous Friends', description: '"I try to become the most powerful person around so no one can ever hurt or betray me again."'),
      TableEntry(minRoll: 31, maxRoll: 35, label: 'Immortal Delusion', description: '"I believe I cannot die. No danger can frighten me, and caution is for the weak."'),
      TableEntry(minRoll: 36, maxRoll: 45, label: 'Whispering Shadows', description: '"I hear whispering in dark places that tells me secrets about my companions."'),
      TableEntry(minRoll: 46, maxRoll: 50, label: 'Extreme Paranoia', description: '"Everyone is out to get me. I can trust no one, especially not my so-called friends."'),
      TableEntry(minRoll: 51, maxRoll: 55, label: 'Obsessive Trophies', description: '"I must take a grisly trophy from every enemy I defeat to prove my superiority."'),
      TableEntry(minRoll: 56, maxRoll: 70, label: 'Power Craving', description: '"The world is decaying, and only my ascension to absolute power can preserve what matters."'),
      TableEntry(minRoll: 71, maxRoll: 80, label: 'Disdain for Morals', description: '"Morality is an illusion created by the weak. I do whatever is necessary to survive."'),
      TableEntry(minRoll: 81, maxRoll: 85, label: 'Grand Destiny', description: '"A god or cosmic entity speaks through me. I must obey its divine commands above all else."'),
      TableEntry(minRoll: 86, maxRoll: 95, label: 'Unnatural Compulsion', description: '"I feel an unbearable urge to wash my weapons in the blood of creatures I slay."'),
      TableEntry(minRoll: 96, maxRoll: 100, label: 'Solitary Withdrawal', description: '"I despise crowds and speaking. I prefer total isolation and silence."'),
    ],
  );

  // ==========================================
  // TRAP SEVERITY & DAMAGE BY TIER
  // ==========================================
  static const RollableTable trapSeverity = RollableTable(
    id: 'trap_severity',
    name: 'Trap Severity & Damage by Tier',
    category: TableCategory.dmGameplay,
    diceFormula: '1d20',
    diceSides: 20,
    description: 'Quick resolution for trap DCs, attack bonuses, and damage dice based on party level tier.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 6, label: 'Setback Trap (DC 10–11, Attack +3 to +5)', description: 'Tier 1 (Lvl 1-4): 1d10 dmg • Tier 2 (Lvl 5-10): 2d10 dmg • Tier 3 (Lvl 11-16): 4d10 dmg • Tier 4 (Lvl 17+): 10d10 dmg.'),
      TableEntry(minRoll: 7, maxRoll: 14, label: 'Dangerous Trap (DC 12–15, Attack +6 to +8)', description: 'Tier 1 (Lvl 1-4): 2d10 dmg • Tier 2 (Lvl 5-10): 4d10 dmg • Tier 3 (Lvl 11-16): 10d10 dmg • Tier 4 (Lvl 17+): 18d10 dmg.'),
      TableEntry(minRoll: 15, maxRoll: 20, label: 'Deadly Trap (DC 16–20, Attack +9 to +12)', description: 'Tier 1 (Lvl 1-4): 4d10 dmg • Tier 2 (Lvl 5-10): 10d10 dmg • Tier 3 (Lvl 11-16): 18d10 dmg • Tier 4 (Lvl 17+): 24d10 dmg.'),
    ],
  );

  // ==========================================
  // CAROUSING & DOWNTIME COMPLICATIONS (d100)
  // ==========================================
  static const RollableTable carousingComplications = RollableTable(
    id: 'carousing_complications',
    name: 'Carousing & Downtime Complications',
    category: TableCategory.dmGameplay,
    diceFormula: '1d100',
    description: 'Roll on this table after a character spends downtime carousing in taverns and feasts.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 10, label: 'Jailed for 1d4 days', description: 'You wake up behind bars for disorderly conduct and must pay a 25 gp fine or serve 1d4 days of hard labor.'),
      TableEntry(minRoll: 11, maxRoll: 20, label: 'Robbed of all coin', description: 'You wake up in an alley with empty pockets, a splitting headache, and no memory of the night.'),
      TableEntry(minRoll: 21, maxRoll: 30, label: 'Mysterious tattoo', description: 'You discover a permanent magical or guild tattoo inked on your body in a language you don\'t speak.'),
      TableEntry(minRoll: 31, maxRoll: 40, label: 'Accidental wager debt', description: 'A pugilist or gambler claims you owe them 100 gp on a bar fight bet.'),
      TableEntry(minRoll: 41, maxRoll: 50, label: 'Noble romantic entanglement', description: 'A member of high nobility falls passionately in love with you, much to the fury of their family.'),
      TableEntry(minRoll: 51, maxRoll: 60, label: 'Local hero celebrity', description: 'You performed a legendary drinking stunt and the local tavern names a cocktail after you.'),
      TableEntry(minRoll: 61, maxRoll: 70, label: 'Feud with local guild', description: 'You accidentally insulted a master artisan or thieves\' guild member in a drunken debate.'),
      TableEntry(minRoll: 71, maxRoll: 80, label: 'Adopted a stray monster', description: 'You adopted a pseudodragon, goat, or goblin child who now follows you everywhere.'),
      TableEntry(minRoll: 81, maxRoll: 90, label: 'Bought something bizarre', description: 'You bought a useless deed to a ruined windmill or swamp island for 50 gp.'),
      TableEntry(minRoll: 91, maxRoll: 100, label: 'Valuable quest secret learned', description: 'A loose-lipped spy or merchant gave you the location of a secret dungeon entrance or vault key.'),
    ],
  );

  // ==========================================
  // NPC GENERATOR TABLES
  // ==========================================
  static const RollableTable npcAppearance = RollableTable(
    id: 'npc_appearance',
    name: 'NPC Distinctive Appearance',
    category: TableCategory.characterLore,
    diceFormula: '1d20',
    diceSides: 20,
    description: 'Quick physical feature generator for improvising NPCs.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Distinctive jewelry: earrings, necklace, circlet', description: 'Wears elaborate gemstones or signet rings.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Piercings on ears, nose, or brow', description: 'Multiple silver or bone studs.'),
      TableEntry(minRoll: 3, maxRoll: 3, label: 'Flamboyant or outlandish clothes', description: 'Vibrant silk robes or eccentric hats.'),
      TableEntry(minRoll: 4, maxRoll: 4, label: 'Formal, immaculate attire', description: 'Sharp, pressed vestments and polished leather.'),
      TableEntry(minRoll: 5, maxRoll: 5, label: 'Ragged, dirty, or patched clothes', description: 'Shows signs of hard labor or impoverished background.'),
      TableEntry(minRoll: 6, maxRoll: 6, label: 'Pronounced scar on face or neck', description: 'Claw mark, burn scar, or dueling slash.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: 'Missing teeth or gold tooth', description: 'Glint of gold when smiling.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: 'Missing fingers or toes', description: 'War wound or frostbite relic.'),
      TableEntry(minRoll: 9, maxRoll: 9, label: 'Unusual eye color (or two different colors)', description: 'One gold eye and one violet eye.'),
      TableEntry(minRoll: 10, maxRoll: 10, label: 'Distinctive birthmark', description: 'Resembles a crescent moon or dragon wing.'),
      TableEntry(minRoll: 11, maxRoll: 11, label: 'Unusual skin color or pale complexion', description: 'Chalky pale, bronze metallic, or slate gray.'),
      TableEntry(minRoll: 12, maxRoll: 12, label: 'Bald or shaved head with scalp tattoo', description: 'Intricate tribal or mystical script.'),
      TableEntry(minRoll: 13, maxRoll: 13, label: 'Unusual hair color or wild braided mane', description: 'Silver, bright copper, or emerald dye.'),
      TableEntry(minRoll: 14, maxRoll: 14, label: 'Twitching nervous tic or blink', description: 'Subtle facial muscle twitch when stressed.'),
      TableEntry(minRoll: 15, maxRoll: 15, label: 'Distinctive posture (crooked, towering, slouching)', description: 'Imposing vertical presence or perpetual stoop.'),
      TableEntry(minRoll: 16, maxRoll: 16, label: 'Exceptionally beautiful or handsome', description: 'Striking features that draw all eyes in the room.'),
      TableEntry(minRoll: 17, maxRoll: 17, label: 'Exceptionally ugly or scarred', description: 'Severe features that intimidate onlookers.'),
      TableEntry(minRoll: 18, maxRoll: 18, label: 'Unusual body odor (perfume, spices, brimstone)', description: 'Aura of cloves, sea salt, or ozone.'),
      TableEntry(minRoll: 19, maxRoll: 19, label: 'Hot-tempered scowl or perpetual grin', description: 'Expressive face wearing emotions openly.'),
      TableEntry(minRoll: 20, maxRoll: 20, label: 'Peg leg, hook hand, or eye patch', description: 'Veteran prosthetics carved from darkwood.'),
    ],
  );

  static const RollableTable npcTalents = RollableTable(
    id: 'npc_talents',
    name: 'NPC High Talent / Skill',
    category: TableCategory.characterLore,
    diceFormula: '1d20',
    diceSides: 20,
    description: 'Distinctive special talents or master skills possessed by an NPC.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Plays a musical instrument masterfully', description: 'Virtuoso lutenist, flutist, or drummer.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Speaks several languages fluently', description: 'Polyglot scholar or traveling caravan merchant.'),
      TableEntry(minRoll: 3, maxRoll: 3, label: 'Unbelievably lucky in games of chance', description: 'Always wins coin tosses and dice rolls.'),
      TableEntry(minRoll: 4, maxRoll: 4, label: 'Perfect photographic memory', description: 'Recalls maps, ledgers, and faces from decades past.'),
      TableEntry(minRoll: 5, maxRoll: 5, label: 'Great with animals and beasts', description: 'Soothes wild predators with a gentle whisper.'),
      TableEntry(minRoll: 6, maxRoll: 6, label: 'Great with children and storytelling', description: 'Beloved neighborhood tale-spinner.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: 'Master puzzle solver and cryptographer', description: 'Solves cipher wheels and riddle locks in seconds.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: 'Deep intuitive knowledge of regional history', description: 'Knows genealogies of local ruling lines.'),
      TableEntry(minRoll: 9, maxRoll: 9, label: 'Master impersonator and mimic', description: 'Copies voices and accents flawlessly.'),
      TableEntry(minRoll: 10, maxRoll: 10, label: 'Master artist, painter, or sculptor', description: 'Creates breathtaking lifelike portraits.'),
      TableEntry(minRoll: 11, maxRoll: 11, label: 'Great acrobat, juggler, or tightrope walker', description: 'Incredible balance and agility.'),
      TableEntry(minRoll: 12, maxRoll: 12, label: 'Expert gourmet cook and brewer', description: 'Turns trail rations into festive banquets.'),
      TableEntry(minRoll: 13, maxRoll: 13, label: 'Expert dart thrower or archer', description: 'Splits arrows at 50 paces.'),
      TableEntry(minRoll: 14, maxRoll: 14, label: 'Skilled thief, pickpocket, and sleight-of-hand', description: 'Palms coins and keys unnoticed.'),
      TableEntry(minRoll: 15, maxRoll: 15, label: 'Expert carver, calligrapher, or forger', description: 'Replicates signatures and legal seals.'),
      TableEntry(minRoll: 16, maxRoll: 16, label: 'Skilled swimmer and pearl diver', description: 'Can hold breath for four minutes.'),
      TableEntry(minRoll: 17, maxRoll: 17, label: 'Incredible stamina and endurance runner', description: 'Runs for days without flagging.'),
      TableEntry(minRoll: 18, maxRoll: 18, label: 'Master disguise artist', description: 'Transforms identity with makeup and prosthetics.'),
      TableEntry(minRoll: 19, maxRoll: 19, label: 'Expert at reading lips across crowded rooms', description: 'Eavesdrops silently on conspirators.'),
      TableEntry(minRoll: 20, maxRoll: 20, label: 'Skilled navigator by stars and wind', description: 'Never gets lost at sea or in deserts.'),
    ],
  );

  static const RollableTable npcMannerisms = RollableTable(
    id: 'npc_mannerisms',
    name: 'NPC Mannerisms & Quirks',
    category: TableCategory.characterLore,
    diceFormula: '1d20',
    diceSides: 20,
    description: 'Memorable roleplaying quirks for DM portrayal.',
    entries: [
      TableEntry(minRoll: 1, maxRoll: 1, label: 'Prone to singing, humming, or whistling quietly', description: 'Always has a cheerful tune on the lips.'),
      TableEntry(minRoll: 2, maxRoll: 2, label: 'Speaks in rhymes or poetic verses', description: 'Deliberate meter and melodic phrasing.'),
      TableEntry(minRoll: 3, maxRoll: 3, label: 'Particularly high or low-pitched voice', description: 'Gravelly baritone or melodic soprano.'),
      TableEntry(minRoll: 4, maxRoll: 4, label: 'Slurs words, lisps, or stutters', description: 'Distinct speech cadence.'),
      TableEntry(minRoll: 5, maxRoll: 5, label: 'Speaks with booming loudness', description: 'Projects to the entire tavern naturally.'),
      TableEntry(minRoll: 6, maxRoll: 6, label: 'Whispers conspiracies constantly', description: 'Leans in close and speaks in hushed tones.'),
      TableEntry(minRoll: 7, maxRoll: 7, label: 'Uses flowery diction and grand metaphors', description: 'Speaks like a high-court diplomat.'),
      TableEntry(minRoll: 8, maxRoll: 8, label: 'Frequently misuses big words', description: 'Confidently uses wrong vocabulary.'),
      TableEntry(minRoll: 9, maxRoll: 9, label: 'Speaks in third person', description: 'Refers to self by name only.'),
      TableEntry(minRoll: 10, maxRoll: 10, label: 'Fidgets with coin, dice, or dagger', description: 'Hands are perpetually in motion.'),
      TableEntry(minRoll: 11, maxRoll: 11, label: 'Constantly grooms hair, beard, or clothes', description: 'Obsessed with looking immaculate.'),
      TableEntry(minRoll: 12, maxRoll: 12, label: 'Never makes eye contact', description: 'Eyes constantly dart to exits and floor.'),
      TableEntry(minRoll: 13, maxRoll: 13, label: 'Uncomfortably intense direct eye contact', description: 'Stares unblinkingly while conversing.'),
      TableEntry(minRoll: 14, maxRoll: 14, label: 'Chews on fingernails or smoking pipe', description: 'Nervous oral fixation.'),
      TableEntry(minRoll: 15, maxRoll: 15, label: 'Taps foot or drum fingers rhythmically', description: 'Perpetual internal beat.'),
      TableEntry(minRoll: 16, maxRoll: 16, label: 'Squints as if everything is too bright', description: 'Shields eyes or peers closely.'),
      TableEntry(minRoll: 17, maxRoll: 17, label: 'Snorts loudly when laughing', description: 'Uninhibited, boisterous guffaws.'),
      TableEntry(minRoll: 18, maxRoll: 18, label: 'Paces back and forth incessantly', description: 'Cannot stand still during conversations.'),
      TableEntry(minRoll: 19, maxRoll: 19, label: 'Touches people on the shoulder or arm', description: 'Physically demonstrative communicator.'),
      TableEntry(minRoll: 20, maxRoll: 20, label: 'Tells long, rambling anecdotes', description: 'Every answer begins with "That reminds me of..."'),
    ],
  );
}
