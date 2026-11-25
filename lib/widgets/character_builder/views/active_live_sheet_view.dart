import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../providers/character_sheet_controller.dart';
import '../../character_sheet/ability_scores_ribbon.dart';
import '../../character_sheet/character_header_banner.dart';
import '../../character_sheet/character_sheet_tabs.dart';
import '../../character_sheet/character_vitals_hud.dart';

class ActiveLiveSheetView extends StatelessWidget {
  final Character? character;
  final CharacterSheetController? sheetController;
  final Widget selectorFallback;
  final VoidCallback onEnsureSheetController;
  final VoidCallback onBackToRoster;

  const ActiveLiveSheetView({
    super.key,
    required this.character,
    required this.sheetController,
    required this.selectorFallback,
    required this.onEnsureSheetController,
    required this.onBackToRoster,
  });

  @override
  Widget build(BuildContext context) {
    final char = character;
    if (char == null) {
      return selectorFallback;
    }

    onEnsureSheetController();
    final controller = sheetController;
    if (controller == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          CharacterHeaderBanner(
                            controller: controller,
                            onSwitchHero: onBackToRoster,
                          ),
                          const SizedBox(height: 14),
                          CharacterVitalsHud(controller: controller),
                          const SizedBox(height: 14),
                          AbilityScoresRibbon(controller: controller),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: CharacterSheetTabs(controller: controller),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  CharacterHeaderBanner(
                    controller: controller,
                    onSwitchHero: onBackToRoster,
                  ),
                  const SizedBox(height: 12),
                  CharacterVitalsHud(controller: controller),
                  const SizedBox(height: 12),
                  AbilityScoresRibbon(controller: controller),
                  const SizedBox(height: 14),
                  CharacterSheetTabs(controller: controller),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

}
