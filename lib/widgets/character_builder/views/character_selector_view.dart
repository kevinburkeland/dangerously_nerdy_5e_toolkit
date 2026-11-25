import 'package:material_ui/material_ui.dart';
import '../../../presentation/visual/visual_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../character_sheet/missing_homebrew_warning_widget.dart';
import '../../../services/haptic_service.dart';
import '../../../services/repository/reference_resolver.dart';
import '../../../services/rules/character_homebrew_validator.dart';
import '../../glyphs/dnd_glyph.dart';
import '../steps/builder_step_order.dart';

class CharacterSelectorView extends StatelessWidget {
  final List<Character> characterRoster;
  final Character? activeCharacter;
  final String rosterSearchQuery;
  final RulesetVersion? rosterRulesetFilter;
  final ReferenceResolver resolver;
  final ValueChanged<String> onSearchQueryChanged;
  final ValueChanged<RulesetVersion?> onRulesetFilterChanged;
  final ValueChanged<Character> onSelectCharacter;
  final ValueChanged<Character> onConfirmDeleteCharacter;
  final ValueChanged<Character> onReparseCharacter;
  final VoidCallback onReparseAll;
  final VoidCallback onCreateNewCharacter;

  const CharacterSelectorView({
    super.key,
    required this.characterRoster,
    required this.activeCharacter,
    required this.rosterSearchQuery,
    required this.rosterRulesetFilter,
    required this.resolver,
    required this.onSearchQueryChanged,
    required this.onRulesetFilterChanged,
    required this.onSelectCharacter,
    required this.onConfirmDeleteCharacter,
    required this.onReparseCharacter,
    required this.onReparseAll,
    required this.onCreateNewCharacter,
  });

  Widget _buildMiniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final filteredRoster = characterRoster.where((c) {
      if (rosterRulesetFilter != null && c.ruleset != rosterRulesetFilter) {
        return false;
      }
      if (rosterSearchQuery.isEmpty) return true;
      final q = rosterSearchQuery.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(q);
      final classMatches = c.progression.classes
          .any((cls) => cls.classRef.displayName.toLowerCase().contains(q));
      final speciesMatches = c.speciesRef.displayName.toLowerCase().contains(q);
      final bgMatches =
          c.backgroundRef?.displayName.toLowerCase().contains(q) ?? false;
      return nameMatches || classMatches || speciesMatches || bgMatches;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Roster Banner / Hero Card
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_outlined,
                      color: Colors.cyanAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '5e Character Roster',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Select an adventurer to inspect their live sheet, or manage your party members.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('reparse_all_roster_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Reparse Roster',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: characterRoster.isEmpty
                          ? null
                          : onReparseAll,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('New Hero',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        onCreateNewCharacter();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Search Bar
        TextField(
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search heroes by name, class, species...',
            hintStyle: TextStyle(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 12),
            prefixIcon: Icon(Icons.search, color: primary, size: 18),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E293B)
                : theme.colorScheme.surfaceContainerHighest,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) => onSearchQueryChanged(val.trim()),
        ),

        const SizedBox(height: 8),

        // Ruleset Filter Chips
        Row(
          children: [
            FilterChip(
              label: const Text('All Rulesets', style: TextStyle(fontSize: 11)),
              selected: rosterRulesetFilter == null,
              onSelected: (_) => onRulesetFilterChanged(null),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('2024 Revised', style: TextStyle(fontSize: 11)),
              selected: rosterRulesetFilter == RulesetVersion.v2024,
              onSelected: (_) =>
                  onRulesetFilterChanged(RulesetVersion.v2024),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('2014 Classic', style: TextStyle(fontSize: 11)),
              selected: rosterRulesetFilter == RulesetVersion.v2014,
              onSelected: (_) =>
                  onRulesetFilterChanged(RulesetVersion.v2014),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (filteredRoster.isEmpty)
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.person_off_outlined,
                        color: Colors.white38, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      characterRoster.isEmpty
                          ? 'No characters in roster yet.'
                          : 'No characters found matching your filter.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Create New Character'),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        onCreateNewCharacter();
                      },
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...filteredRoster.map((hero) {
            final curCls = hero.progression.classes.firstOrNull;
            final clsType = curCls != null
                ? findBuilderClassType(curCls.classRef.slug)
                : DndClassType.fighter;
            final isCurrentActive = activeCharacter?.id.slug == hero.id.slug;
            final heroStats = CharacterStatCalculator.compute(hero, resolver);
            final heroHomebrewReport =
                CharacterHomebrewValidator.validate(hero);

            return Card(
              key: ValueKey('character_card_${hero.id.slug}'),
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCurrentActive ? Colors.cyanAccent : Colors.white12,
                  width: isCurrentActive ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        RepaintBoundary(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: DndGlyph.classFeature(
                                classType: clsType ?? DndClassType.fighter,
                                size: 44,
                                isDarkMode: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      hero.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          hero.ruleset == RulesetVersion.v2024
                                              ? Colors.cyan.shade900
                                                  .withValues(alpha: 0.6)
                                              : Colors.amber.shade900
                                                  .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      hero.ruleset == RulesetVersion.v2024
                                          ? '2024'
                                          : '2014',
                                      style: TextStyle(
                                        color:
                                            hero.ruleset == RulesetVersion.v2024
                                                ? Colors.cyanAccent
                                                : Colors.amberAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (heroHomebrewReport.hasMissing) ...[
                                    const SizedBox(width: 8),
                                    MissingHomebrewBadge(
                                      character: hero,
                                      report: heroHomebrewReport,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Level ${hero.totalLevel} ${hero.progression.classes.map((c) => "${c.classRef.displayName} ${c.level}").join(" / ")} • ${hero.speciesRef.displayName} • ${hero.backgroundRef?.displayName ?? "Adventurer"}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: ValueKey('reparse_character_${hero.id.slug}'),
                          icon: const Icon(Icons.sync,
                              color: Colors.cyanAccent, size: 20),
                          tooltip: 'Reparse Character Sheet',
                          onPressed: () => onReparseCharacter(hero),
                        ),
                        IconButton(
                          key: ValueKey('delete_character_${hero.id.slug}'),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Character',
                          onPressed: () => onConfirmDeleteCharacter(hero),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildMiniPill('AC ${heroStats.armorClass}',
                                Colors.amberAccent),
                            _buildMiniPill(
                                'HP ${hero.resources.currentHp}/${heroStats.maxHp}',
                                Colors.redAccent),
                            _buildMiniPill(
                                'Prof +${heroStats.proficiencyBonus}',
                                Colors.cyanAccent),
                            _buildMiniPill('Speed ${hero.baseSpeedFeet}ft',
                                Colors.greenAccent),
                          ],
                        ),
                        ElevatedButton.icon(
                          key: ValueKey('open_sheet_${hero.id.slug}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent.shade700,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.badge_outlined, size: 14),
                          label: const Text('Open Sheet',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => onSelectCharacter(hero),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
