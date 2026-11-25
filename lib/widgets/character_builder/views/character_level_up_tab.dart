import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../services/haptic_service.dart';
import '../level_up_wizard_dialog.dart';

class CharacterLevelUpTab extends StatelessWidget {
  final Character? character;
  final VoidCallback onGoToRoster;
  final ValueChanged<Character> onLevelUpApplied;

  const CharacterLevelUpTab({
    super.key,
    required this.character,
    required this.onGoToRoster,
    required this.onLevelUpApplied,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final char = character;
    if (char == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upgrade, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              const Text('No Active Character',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Select or create a character to advance levels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('Go to Character Roster'),
                onPressed: () {
                  onGoToRoster();
                },
              ),
            ],
          ),
        ),
      );
    }
    final primaryClass = char.progression.classes.firstOrNull;
    final primaryClassName =
        primaryClass?.classRef.displayName.isNotEmpty == true
            ? primaryClass!.classRef.displayName
            : 'Adventurer';
    final nextLevel = char.totalLevel + 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Level Up Launchpad Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B),
                Colors.purple.shade900.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upgrade,
                        color: Colors.purpleAccent, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level Up ${char.name}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current: Level ${char.totalLevel} $primaryClassName  ➔  Next: Level $nextLevel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.purpleAccent.shade100,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                'Ready to advance your character? The 5e Level Up Wizard will guide you step-by-step through:',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              _buildLevelUpFeatureBullet(Icons.health_and_safety_outlined,
                  'Hit Points & Hit Die Scaling (Average vs Interactive Roll)'),
              _buildLevelUpFeatureBullet(Icons.auto_awesome,
                  'Class Archetypes & Subclass Selection at Milestone Levels'),
              _buildLevelUpFeatureBullet(Icons.fitness_center,
                  'Ability Score Improvements (ASI) or Feats (+2 / +1+1 / Feat)'),
              _buildLevelUpFeatureBullet(Icons.menu_book,
                  'Spellcasting & Spell Slot Scaling according to 5e rules'),
              _buildLevelUpFeatureBullet(Icons.alt_route,
                  'Multiclassing with Prerequisite Verification (13+ stat requirement)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.rocket_launch, size: 20),
                  label: const Text(
                    'LAUNCH LEVEL UP WIZARD',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.8),
                  ),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    LevelUpWizardDialog.show(
                      context,
                      character: char,
                      onLevelUpApplied: onLevelUpApplied,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelUpFeatureBullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.purpleAccent.shade100),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }

}
