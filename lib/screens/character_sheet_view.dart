import 'package:flutter/material.dart';
import '../models/domain/core_types.dart';
import '../models/domain/entity_reference.dart';
import '../models/domain/character_models.dart';
import '../providers/character_sheet_controller.dart';
import '../services/persistence/character_persistence_service.dart';
import '../widgets/character_sheet/character_header_banner.dart';
import '../widgets/character_sheet/character_vitals_hud.dart';
import '../widgets/character_sheet/ability_scores_ribbon.dart';
import '../widgets/character_sheet/character_sheet_tabs.dart';

/// Modernized, responsive, 4-pane Character Sheet View adhering to 5e rules evaluation.
class CharacterSheetView extends StatefulWidget {
  final Character? character;
  final CharacterSheetController? controller;
  final ValueChanged<Character>? onCharacterUpdated;
  final bool isDmMode;

  const CharacterSheetView({
    super.key,
    this.character,
    this.controller,
    this.onCharacterUpdated,
    this.isDmMode = false,
  });

  @override
  State<CharacterSheetView> createState() => _CharacterSheetViewState();
}

class _CharacterSheetViewState extends State<CharacterSheetView> {
  late CharacterSheetController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isLoading = false;
    } else if (widget.character != null) {
      _controller = CharacterSheetController(character: widget.character!);
      _isLoading = false;
    } else {
      _loadDefaultOrSavedCharacter();
    }
  }

  Future<void> _loadDefaultOrSavedCharacter() async {
    final service = CharacterPersistenceService();
    final roster = await service.loadCharacters();
    final activeSlug = await service.loadActiveCharacterId();

    Character active;
    if (roster.isNotEmpty) {
      active = roster.firstWhere(
        (c) => c.id.slug == activeSlug,
        orElse: () => roster.first,
      );
    } else {
      // Fallback empty character
      active = const Character(
        id: EntityId(slug: 'hero-default', ruleset: RulesetVersion.v2024),
        name: 'Adventurer',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 12),
      );
    }

    if (mounted) {
      setState(() {
        _controller = CharacterSheetController(
          character: active,
          persistenceService: service,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePop() async {
    await _controller.flush();
    widget.onCharacterUpdated?.call(_controller.character);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope<Character>(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              await _handlePop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () async {
                        await _handlePop();
                        if (context.mounted) {
                          Navigator.of(context).pop(_controller.character);
                        }
                      },
                    )
                  : null,
              title: Text(
                _controller.character.name.isEmpty ? 'Character Sheet' : _controller.character.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              actions: [
                if (widget.isDmMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      avatar: const Icon(Icons.shield_outlined, size: 14, color: Colors.amberAccent),
                      label: const Text(
                        'DM Mode',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                      ),
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (_controller.isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                // Two-Column Desktop / Tablet Layout
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Header, Vitals, Ability Ribbon
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            CharacterHeaderBanner(controller: _controller),
                            const SizedBox(height: 14),
                            CharacterVitalsHud(controller: _controller),
                            const SizedBox(height: 14),
                            AbilityScoresRibbon(controller: _controller),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Column: Tabbed Content Area
                      Expanded(
                        flex: 6,
                        child: CharacterSheetTabs(controller: _controller),
                      ),
                    ],
                  ),
                );
              }

              // Single Column Mobile Layout
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    CharacterHeaderBanner(controller: _controller),
                    const SizedBox(height: 12),
                    CharacterVitalsHud(controller: _controller),
                    const SizedBox(height: 12),
                    AbilityScoresRibbon(controller: _controller),
                    const SizedBox(height: 14),
                    CharacterSheetTabs(controller: _controller),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
}
