import '../dm_screen_data.dart';
import '../monster_codex_data.dart';
import 'arena_combatant.dart';

/// Specification for a combatant in a preset matchup.
class ArenaPresetMember {
  final String monsterId;
  final String? monsterName;
  final int count;

  const ArenaPresetMember({
    required this.monsterId,
    this.monsterName,
    this.count = 1,
  });
}

/// A pre-configured pit fight ready to load with 1 click.
class ArenaPresetMatchup {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final List<ArenaPresetMember> teamA;
  final List<ArenaPresetMember> teamB;

  const ArenaPresetMatchup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.teamA,
    required this.teamB,
  });

  /// Resolves the preset members into [ArenaCombatant] instances.
  ({List<ArenaCombatant> teamA, List<ArenaCombatant> teamB}) resolveFighters([
    DmRulesEdition edition = DmRulesEdition.v2024,
  ]) {
    final listA = <ArenaCombatant>[];
    final listB = <ArenaCombatant>[];

    for (final member in teamA) {
      final monster = MonsterCodexLibrary.getMonsterById(member.monsterId) ??
          MonsterCodexLibrary.getMonsterByName(member.monsterName ?? member.monsterId);
      if (monster != null) {
        for (int i = 0; i < member.count; i++) {
          final suffix = member.count > 1 ? ' #${i + 1}' : '';
          listA.add(
            ArenaCombatant.fromMonster(
              id: 'team_a_${monster.id}_$i',
              monster: monster,
              team: ArenaTeam.teamA,
              customName: '${monster.getName(edition)}$suffix',
              edition: edition,
            ),
          );
        }
      }
    }

    for (final member in teamB) {
      final monster = MonsterCodexLibrary.getMonsterById(member.monsterId) ??
          MonsterCodexLibrary.getMonsterByName(member.monsterName ?? member.monsterId);
      if (monster != null) {
        for (int i = 0; i < member.count; i++) {
          final suffix = member.count > 1 ? ' #${i + 1}' : '';
          listB.add(
            ArenaCombatant.fromMonster(
              id: 'team_b_${monster.id}_$i',
              monster: monster,
              team: ArenaTeam.teamB,
              customName: '${monster.getName(edition)}$suffix',
              edition: edition,
            ),
          );
        }
      }
    }

    return (teamA: listA, teamB: listB);
  }

  static const List<ArenaPresetMatchup> defaultPresets = [
    ArenaPresetMatchup(
      id: 'apex_predator',
      title: 'Apex Predator vs Pack',
      subtitle: '1 Tyrannosaurus Rex (CR 8) vs 8 Wolves (CR 1/4)',
      tag: 'Pack Tactics Test',
      teamA: [
        ArenaPresetMember(monsterId: 'tyrannosaurus_rex', monsterName: 'Tyrannosaurus Rex', count: 1),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'wolf', monsterName: 'Wolf', count: 8),
      ],
    ),
    ArenaPresetMatchup(
      id: 'dragon_slayers',
      title: 'Dragon Slayer Strike Team',
      subtitle: '1 Young Red Dragon (CR 10) vs 4 Knights (CR 3)',
      tag: 'Boss Fight',
      teamA: [
        ArenaPresetMember(monsterId: 'young_red_dragon', monsterName: 'Young Red Dragon', count: 1),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'knight', monsterName: 'Knight', count: 4),
      ],
    ),
    ArenaPresetMatchup(
      id: 'giant_vs_swarm',
      title: 'Giant vs Goblin Swarm',
      subtitle: '1 Hill Giant (CR 5) vs 12 Goblins (CR 1/4)',
      tag: 'Action Economy',
      teamA: [
        ArenaPresetMember(monsterId: 'hill_giant', monsterName: 'Hill Giant', count: 1),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'goblin', monsterName: 'Goblin', count: 12),
      ],
    ),
    ArenaPresetMatchup(
      id: 'elemental_clash',
      title: 'Primal Opposition',
      subtitle: '2 Fire Elementals (CR 5) vs 2 Water Elementals (CR 5)',
      tag: 'Elemental Mirror',
      teamA: [
        ArenaPresetMember(monsterId: 'fire_elemental', monsterName: 'Fire Elemental', count: 2),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'water_elemental', monsterName: 'Water Elemental', count: 2),
      ],
    ),
    ArenaPresetMatchup(
      id: 'undead_legion',
      title: 'Crypt Uprising',
      subtitle: '2 Wights (CR 3) vs 8 Skeletons (CR 1/4) & 4 Zombies (CR 1/4)',
      tag: 'Undead Battle',
      teamA: [
        ArenaPresetMember(monsterId: 'wight', monsterName: 'Wight', count: 2),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'skeleton', monsterName: 'Skeleton', count: 8),
        ArenaPresetMember(monsterId: 'zombie', monsterName: 'Zombie', count: 4),
      ],
    ),
    ArenaPresetMatchup(
      id: 'aquatic_abyss',
      title: 'Deep Abyss Ambush',
      subtitle: '1 Giant Shark (CR 5) vs 6 Bandit Mariners (CR 1/8)',
      tag: 'Water Match',
      teamA: [
        ArenaPresetMember(monsterId: 'giant_shark', monsterName: 'Giant Shark', count: 1),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'bandit', monsterName: 'Bandit', count: 6),
      ],
    ),
    ArenaPresetMatchup(
      id: 'gladiator_arena',
      title: 'Colosseum Champion',
      subtitle: '1 Gladiator (CR 5) vs 2 Berserkers (CR 2)',
      tag: 'Cage Match',
      teamA: [
        ArenaPresetMember(monsterId: 'gladiator', monsterName: 'Gladiator', count: 1),
      ],
      teamB: [
        ArenaPresetMember(monsterId: 'berserker', monsterName: 'Berserker', count: 2),
      ],
    ),
  ];
}
