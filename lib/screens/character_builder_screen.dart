import 'package:material_ui/material_ui.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import '../infrastructure/di/injection_container.dart';
import '../models/dm_screen_data.dart' show DmRulesEdition;
import '../models/domain/character_models.dart';
import '../models/domain/core_types.dart';
import '../providers/character_sheet_controller.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/persistence/character_persistence_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../services/repository/layered_priority_repository.dart';
import '../services/repository/reference_resolver.dart';
import '../widgets/character_builder/views/active_live_sheet_view.dart';
import '../widgets/character_builder/views/builder_sample_repository.dart';
import '../widgets/character_builder/views/character_inventory_tab.dart';
import '../widgets/character_builder/views/character_level_up_tab.dart';
import '../widgets/character_builder/views/character_selector_view.dart';
import '../widgets/character_builder/views/guided_builder_tab.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/room_banner_widget.dart';

/// Interactive Character Generator, Live State Sheet, and Multiclassing Studio
class CharacterBuilderScreen extends StatefulWidget {
  const CharacterBuilderScreen({super.key});

  @override
  State<CharacterBuilderScreen> createState() => _CharacterBuilderScreenState();
}

class _CharacterBuilderScreenState extends State<CharacterBuilderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late LayeredPriorityRepository _repository;
  late ReferenceResolver _resolver;

  DmRulesEdition _rulesEdition = DmRulesEdition.v2024;
  DmRulesEdition? _localEditionOverride;
  RulesetVersion _selectedRuleset = RulesetVersion.v2024;

  final CharacterPersistenceService _persistenceService =
      CharacterPersistenceService();
  List<Character> _characterRoster = [];
  bool _isSelectorView = true;
  String _rosterSearchQuery = '';
  RulesetVersion? _rosterRulesetFilter;
  int _wizardResetNonce = 0;

  Character? _character;
  CharacterSheetController? _sheetController;

  bool get _hasActiveCharacter => !_isSelectorView && _character != null;
  int get _expectedTabCount => _hasActiveCharacter ? 4 : 2;

  void _syncTabController() {
    final expected = _expectedTabCount;
    if (_tabController.length != expected) {
      final oldIndex = _tabController.index.clamp(0, expected - 1);
      final old = _tabController;
      _tabController = TabController(
        length: expected,
        initialIndex: oldIndex,
        vsync: this,
      );
      old.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _expectedTabCount, vsync: this);
    _repository = LayeredPriorityRepository();
    _resolver = ReferenceResolver(_repository);
    populateBuilderSampleRepository(_repository);
    _characterRoster = [];
    _character = null;
    _isSelectorView = true;
    _loadPersistedRoster();
  }

  Future<void> _loadPersistedRoster() async {
    await HomebrewPersistenceService().syncToLibraries();
    final loaded = await _persistenceService.loadCharacters();
    final activeId = await _persistenceService.loadActiveCharacterId();
    if (mounted) {
      setState(() {
        _characterRoster = loaded;
        if (_characterRoster.isNotEmpty) {
          if (activeId != null) {
            final matched = _characterRoster.cast<Character?>().firstWhere(
                  (c) => c?.id.slug == activeId,
                  orElse: () => null,
                );
            _character = matched ?? _characterRoster.first;
          } else {
            _character = _characterRoster.first;
          }
          _recalculateStats();
        } else {
          _character = null;
          _isSelectorView = true;
        }
        _syncTabController();
      });
    }
  }

  void _selectCharacter(Character char) {
    HapticService.selectionTick(context);
    setState(() {
      _character = char;
      _rulesEdition = char.ruleset == RulesetVersion.v2024
          ? DmRulesEdition.v2024
          : DmRulesEdition.v2014;
      _isSelectorView = false;
      _recalculateStats();
      _syncTabController();
    });
    _persistenceService.saveActiveCharacterId(char.id.slug);
  }

  void _confirmDeleteCharacter(Character char) {
    HapticService.selectionTick(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete ${char.name}?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${char.name}? This character will be permanently removed from your roster.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteCharacter(char);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCharacter(Character char) async {
    HapticService.heavyImpact(context);
    await _persistenceService.deleteCharacter(char.id.slug);
    final updated = await _persistenceService.loadCharacters();
    setState(() {
      _characterRoster = updated;
      if (_character?.id.slug == char.id.slug) {
        if (_characterRoster.isNotEmpty) {
          _character = _characterRoster.first;
          _recalculateStats();
        } else {
          _character = null;
        }
        _isSelectorView = true;
      }
      _syncTabController();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('${char.name} deleted from roster.'),
        ),
      );
    }
  }

  Future<void> _reparseCharacter(Character hero) async {
    HapticService.selectionTick(context);
    final reloaded = await _persistenceService.reparseCharacter(hero);
    setState(() {
      _characterRoster = _characterRoster
          .map((c) => c.id.slug == reloaded.id.slug ? reloaded : c)
          .toList();
      if (_character?.id.slug == reloaded.id.slug) {
        _character = reloaded;
        _recalculateStats();
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F766E),
          content: Text('${hero.name} reparsed and updated!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _reparseAllCharacters() async {
    HapticService.mediumImpact(context);
    final updatedList = await _persistenceService.reparseAllCharacters();
    setState(() {
      _characterRoster = updatedList;
      if (_character != null) {
        final currentUpdated = updatedList.firstWhere(
          (c) => c.id.slug == _character!.id.slug,
          orElse: () => _character!,
        );
        _character = currentUpdated;
        _recalculateStats();
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F766E),
          content: Text(
              'All ${updatedList.length} character sheets reparsed and updated!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _recalculateStats() {
    if (_character != null) {
      _syncSheetController();
    }
  }

  void _syncSheetController() {
    final char = _character;
    if (char != null) {
      if (_sheetController == null) {
        _sheetController = CharacterSheetController(
          character: char,
          replicaId: sl<ReplicaId>(),
          persistenceService: _persistenceService,
          resolver: _resolver,
        );
        _sheetController!.addListener(_onSheetControllerUpdated);
      } else if (_sheetController!.character.id != char.id ||
          _sheetController!.character != char) {
        _sheetController!.setCharacter(char);
      }
    } else {
      _sheetController?.removeListener(_onSheetControllerUpdated);
      _sheetController?.dispose();
      _sheetController = null;
    }
  }

  void _onSheetControllerUpdated() {
    if (_sheetController != null && mounted) {
      setState(() => _character = _sheetController!.character);
    }
  }

  void _onRulesEditionChanged(DmRulesEdition newEdition) {
    HapticService.selectionTick(context);
    setState(() {
      _localEditionOverride = newEdition;
      _rulesEdition = newEdition;
      _selectedRuleset = newEdition == DmRulesEdition.v2024
          ? RulesetVersion.v2024
          : RulesetVersion.v2014;
      final char = _character;
      if (char != null) {
        _character = char.copyWith(
          id: EntityId(slug: char.id.slug, ruleset: _selectedRuleset),
        );
        _recalculateStats();
      }
    });
    SettingsScope.maybeOf(context)?.setRulesEdition(newEdition);
  }

  void _onCharacterCreated(Character newChar) {
    _persistenceService.saveCharacter(newChar).then((_) async {
      final updated = await _persistenceService.loadCharacters();
      if (mounted) {
        setState(() {
          _characterRoster = updated;
          _character = newChar;
          _isSelectorView = false;
          _recalculateStats();
          _syncTabController();
          _tabController.animateTo(0);
        });
      }
    });
  }

  void _goToRoster() {
    setState(() {
      _isSelectorView = true;
      _syncTabController();
      _tabController.animateTo(0);
    });
  }

  @override
  void dispose() {
    _sheetController?.removeListener(_onSheetControllerUpdated);
    _sheetController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final activeEdition = _localEditionOverride ??
        settingsProvider?.settings.rulesEdition ??
        _rulesEdition;

    if (_localEditionOverride == null && activeEdition != _rulesEdition) {
      _rulesEdition = activeEdition;
      _selectedRuleset = activeEdition == DmRulesEdition.v2024
          ? RulesetVersion.v2024
          : RulesetVersion.v2014;
      final char = _character;
      if (char != null) {
        _character = char.copyWith(
          id: EntityId(slug: char.id.slug, ruleset: _selectedRuleset),
        );
        _syncSheetController();
      }
    }

    _syncTabController();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_pin, color: Colors.cyanAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSelectorView || _character == null
                    ? 'Character Studio'
                    : _character!.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          RulesEditionToggle(
            currentEdition: _rulesEdition,
            onEditionChanged: _onRulesEditionChanged,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          key: ValueKey('studio_tab_bar_$_hasActiveCharacter'),
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white70,
          tabs: _hasActiveCharacter
              ? const [
                  Tab(icon: Icon(Icons.badge_outlined), text: 'Live Sheet'),
                  Tab(icon: Icon(Icons.auto_awesome), text: 'Guided Builder'),
                  Tab(
                      icon: Icon(Icons.inventory_2_outlined),
                      text: 'Inventory & Loot'),
                  Tab(icon: Icon(Icons.upgrade), text: 'Level Up'),
                ]
              : const [
                  Tab(icon: Icon(Icons.badge_outlined), text: 'Live Sheet'),
                  Tab(icon: Icon(Icons.auto_awesome), text: 'Guided Builder'),
                ],
        ),
      ),
      body: Column(
        children: [
          RoomBannerWidget(),
          Expanded(
            child: TabBarView(
              key: ValueKey('studio_tab_bar_view_$_hasActiveCharacter'),
              controller: _tabController,
              children: [
                _buildLiveSheetTab(),
                GuidedBuilderTab(
                  selectedRuleset: _selectedRuleset,
                  rulesEdition: _rulesEdition,
                  resetNonce: _wizardResetNonce,
                  onRulesEditionChanged: _onRulesEditionChanged,
                  onCharacterCreated: _onCharacterCreated,
                ),
                if (_hasActiveCharacter) ...[
                  CharacterInventoryTab(
                    character: _character,
                    onGoToRoster: _goToRoster,
                    onCharacterUpdated: (updated) {
                      _persistenceService.saveCharacter(updated);
                      setState(() {
                        _character = updated;
                        _recalculateStats();
                      });
                    },
                  ),
                  CharacterLevelUpTab(
                    character: _character,
                    onGoToRoster: _goToRoster,
                    onLevelUpApplied: (upgraded) {
                      _persistenceService
                          .saveCharacter(upgraded)
                          .then((_) async {
                        final updatedRoster =
                            await _persistenceService.loadCharacters();
                        if (mounted) {
                          setState(() {
                            _characterRoster = updatedRoster;
                            _character = upgraded;
                            _recalculateStats();
                            _tabController.animateTo(0);
                          });
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorView() {
    return CharacterSelectorView(
      characterRoster: _characterRoster,
      activeCharacter: _character,
      rosterSearchQuery: _rosterSearchQuery,
      rosterRulesetFilter: _rosterRulesetFilter,
      resolver: _resolver,
      onSearchQueryChanged: (q) => setState(() => _rosterSearchQuery = q),
      onRulesetFilterChanged: (f) => setState(() => _rosterRulesetFilter = f),
      onSelectCharacter: _selectCharacter,
      onConfirmDeleteCharacter: _confirmDeleteCharacter,
      onReparseCharacter: _reparseCharacter,
      onReparseAll: _reparseAllCharacters,
      onCreateNewCharacter: () {
        setState(() {
          _wizardResetNonce++;
          _tabController.animateTo(1);
        });
      },
    );
  }

  Widget _buildLiveSheetTab() {
    if (_isSelectorView || _characterRoster.isEmpty) {
      return _buildSelectorView();
    }
    return ActiveLiveSheetView(
      character: _character,
      sheetController: _sheetController,
      selectorFallback: _buildSelectorView(),
      onEnsureSheetController: () {
        if (_sheetController == null) _syncSheetController();
      },
      onBackToRoster: () {
        setState(() {
          _isSelectorView = true;
          _syncTabController();
        });
      },
    );
  }
}
