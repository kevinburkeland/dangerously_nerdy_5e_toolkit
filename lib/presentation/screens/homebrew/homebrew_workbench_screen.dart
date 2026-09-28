import 'package:flutter/material.dart';
import '../../../domain/ingestion/descriptors/descriptor_registry.dart';
import '../../../domain/ingestion/models/ingestion_candidate.dart';
import '../../../domain/ingestion/models/ingestion_document_result.dart';
import '../../../domain/ingestion/services/ingestion_workbench_service.dart';
import '../../../models/domain/spell_monster_equipment.dart';
import '../../../services/haptic_service.dart';
import '../../../services/persistence/homebrew_persistence_service.dart';
import 'widgets/candidate_card.dart';
import 'widgets/field_editor_tile.dart';
import 'widgets/unrecognized_source_view.dart';

/// Developer and user-facing WYSIWYG Homebrew Ingestion Workbench.
/// Provides an inspectable, correctable parsing pipeline that explicitly tracks
/// missing, invalid, ambiguous, and unrecognized content.
class HomebrewWorkbenchScreen extends StatefulWidget {
  final String? initialSourceText;
  final IngestionWorkbenchService? workbenchService;
  final HomebrewPersistenceService? persistenceService;

  const HomebrewWorkbenchScreen({
    super.key,
    this.initialSourceText,
    this.workbenchService,
    this.persistenceService,
  });

  @override
  State<HomebrewWorkbenchScreen> createState() =>
      _HomebrewWorkbenchScreenState();
}

class _HomebrewWorkbenchScreenState extends State<HomebrewWorkbenchScreen>
    with SingleTickerProviderStateMixin {
  late final IngestionWorkbenchService _service;
  late final HomebrewPersistenceService _persistence;
  late final TextEditingController _sourceController;
  late TabController _mobileTabController;

  IngestionDocumentResult _parseResult = const IngestionDocumentResult.empty();
  int _selectedCandidateIndex = 0;
  bool _isAutoParse = true;
  bool _isSaving = false;

  static const String _sampleMonsterText = '''### Adult Topaz Dragon
Huge dragon, chaotic neutral
Armor Class 19 (natural armor)
Hit Points 210 (20d12 + 80)
Speed 40 ft., fly 80 ft., swim 40 ft.
STR DEX CON INT WIS CHA
20 (+5) 12 (+1) 19 (+4) 16 (+3) 15 (+2) 18 (+4)
Challenge 13 (10,000 XP)
Actions
Multiattack. The dragon makes one Bite attack and two Claw attacks.
Bite. Melee Weapon Attack: +10 to hit, reach 10 ft., one target. Hit: 16 (2d10 + 5) piercing damage plus 5 (1d10) necrotic damage.
''';

  static const String _sampleSpellText = '''### Sunbeam
6th-level evocation
Casting Time: 1 action
Range: Self (60-foot line)
Components: V, S, M (a magnifying glass)
Duration: Concentration, up to 1 minute
A beam of brilliant light flashes out from your hand in a 5-foot-wide, 60-foot-long line.
Each creature in the line must make a Constitution saving throw.
### At Higher Levels
When you cast this spell using a spell slot of 7th level or higher, damage increases by 1d8.
''';

  @override
  void initState() {
    super.initState();
    _service = widget.workbenchService ?? IngestionWorkbenchService();
    _persistence = widget.persistenceService ?? HomebrewPersistenceService();
    _sourceController = TextEditingController(
      text: widget.initialSourceText ?? _sampleMonsterText,
    );
    _mobileTabController = TabController(length: 3, vsync: this);

    _parseSource(_sourceController.text);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _mobileTabController.dispose();
    super.dispose();
  }

  void _parseSource(String text) {
    setState(() {
      _parseResult = _service.parse(text);
      if (_selectedCandidateIndex >= _parseResult.candidates.length) {
        _selectedCandidateIndex =
            _parseResult.candidates.isNotEmpty ? 0 : 0;
      }
    });
  }

  void _onSourceChanged(String text) {
    if (_isAutoParse) {
      _parseSource(text);
    }
  }

  void _onFieldEdited(String fieldKey, dynamic newValue) {
    if (_parseResult.candidates.isEmpty) return;
    final candidate = _parseResult.candidates[_selectedCandidateIndex];
    final updated = _service.updateCandidateField(candidate, fieldKey, newValue);

    setState(() {
      _parseResult =
          _parseResult.updateCandidate(_selectedCandidateIndex, updated);
    });
  }

  void _onChangeCandidateType(String newTypeKey) {
    if (_parseResult.candidates.isEmpty) return;
    final candidate = _parseResult.candidates[_selectedCandidateIndex];
    final updated = _service.changeCandidateType(candidate, newTypeKey);

    setState(() {
      _parseResult =
          _parseResult.updateCandidate(_selectedCandidateIndex, updated);
    });
  }

  void _onToggleIgnoreBlock(String blockId) {
    if (_parseResult.candidates.isEmpty) return;
    final candidate = _parseResult.candidates[_selectedCandidateIndex];
    final updated = _service.toggleIgnoreBlock(candidate, blockId);

    setState(() {
      _parseResult =
          _parseResult.updateCandidate(_selectedCandidateIndex, updated);
    });
  }

  Future<void> _commitCandidate(IngestionCandidate candidate) async {
    HapticService.selectionTick(context);
    final conversion = _service.convertToDomainEntity(candidate);

    if (!conversion.isSuccess || conversion.entity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Cannot commit: ${conversion.errors.join("; ")}',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final entity = conversion.entity!;
      if (entity is Monster) {
        await _persistence.saveCustomMonster(entity);
      } else if (entity is Spell) {
        await _persistence.saveCustomSpell(entity);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Successfully created and committed ${entity.entityType.key} "${entity.name}" to Codex!',
            ),
            action: SnackBarAction(
              label: 'Done',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).maybePop(entity);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to save entity: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingestion Workbench'),
        actions: [
          IconButton(
            tooltip: _isAutoParse ? 'Live Parse: ON' : 'Live Parse: OFF',
            icon: Icon(_isAutoParse ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _isAutoParse = !_isAutoParse);
            },
          ),
          IconButton(
            tooltip: 'Run Explicit Parse',
            icon: const Icon(Icons.refresh),
            onPressed: () => _parseSource(_sourceController.text),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 850;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Half: Source Document & Controls
                Expanded(
                  flex: 5,
                  child: _buildSourcePane(theme),
                ),
                VerticalDivider(width: 1, color: theme.dividerColor),
                // Right Half: Detected Objects & Candidate Editor
                Expanded(
                  flex: 6,
                  child: _buildWorkbenchPane(theme),
                ),
              ],
            );
          } else {
            // Mobile / Narrow view using TabBar
            return Column(
              children: [
                TabBar(
                  controller: _mobileTabController,
                  tabs: [
                    const Tab(text: 'Source', icon: Icon(Icons.code)),
                    Tab(
                      text: 'Candidates (${_parseResult.candidates.length})',
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                    const Tab(text: 'Editor', icon: Icon(Icons.edit_note)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _mobileTabController,
                    children: [
                      _buildSourcePane(theme),
                      _buildCandidateSelectionList(theme),
                      _buildCandidateEditor(theme),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSourcePane(ThemeData theme) {
    final lineCount = _sourceController.text.split('\n').length;
    final charCount = _sourceController.text.length;

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Sample Buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Source Text ($lineCount lines, $charCount chars)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.pets, size: 14),
                label: const Text('Sample Monster',
                    style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _sourceController.text = _sampleMonsterText;
                  _parseSource(_sampleMonsterText);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Sample Spell',
                    style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _sourceController.text = _sampleSpellText;
                  _parseSource(_sampleSpellText);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _sourceController.clear();
                  _parseSource('');
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Parse Telemetry Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.speed, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Parsed in ${_parseResult.parseDurationMs}ms • '
                    '${_parseResult.candidates.length} candidate(s) detected • '
                    '${_parseResult.unassignedBlocks.length} unassigned block(s)',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Raw Source Text Editor
          Expanded(
            child: TextFormField(
              controller: _sourceController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText:
                    'Paste arbitrary 5e stat block, spell, or item source text here...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: _onSourceChanged,
            ),
          ),

          // Unassigned source preview if any
          if (_parseResult.hasUnassigned)
            UnrecognizedSourceView(
              title: 'Unassigned Source Prose',
              explanation:
                  'The following blocks were not associated with any candidate object.',
              blocks: _parseResult.unassignedBlocks,
            ),
        ],
      ),
    );
  }

  Widget _buildWorkbenchPane(ThemeData theme) {
    return Column(
      children: [
        // Candidates Selection Bar
        if (_parseResult.candidates.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected Candidates (${_parseResult.candidates.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _parseResult.candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = _parseResult.candidates[index];
                      return SizedBox(
                        width: 240,
                        child: CandidateCard(
                          candidate: c,
                          isSelected: _selectedCandidateIndex == index,
                          onSelect: () {
                            setState(() => _selectedCandidateIndex = index);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Selected Candidate Detail Editor
        Expanded(
          child: _buildCandidateEditor(theme),
        ),
      ],
    );
  }

  Widget _buildCandidateSelectionList(ThemeData theme) {
    if (_parseResult.candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No candidate objects detected yet.\nPaste or type content into the Source tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.disabledColor),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _parseResult.candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _parseResult.candidates[index];
        return CandidateCard(
          candidate: c,
          isSelected: _selectedCandidateIndex == index,
          onSelect: () {
            setState(() => _selectedCandidateIndex = index);
            _mobileTabController.animateTo(2); // Jump to Editor tab on mobile
          },
        );
      },
    );
  }

  Widget _buildCandidateEditor(ThemeData theme) {
    if (_parseResult.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule_folder_outlined,
                size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
              'No candidate object selected.\nPaste source text to begin parsing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
      );
    }

    final candidate = _parseResult.candidates[_selectedCandidateIndex];
    final validation = _service.validate(candidate);
    final descriptor =
        DescriptorRegistry.getDescriptor(candidate.targetTypeKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Object Type Selector + Commit Button
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(candidate.identification.confidence * 100).toStringAsFixed(0)}% parser confidence',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Candidate Type Selector Menu
                      PopupMenuButton<String>(
                        tooltip: 'Change Candidate Type',
                        initialValue: candidate.targetTypeKey,
                        onSelected: (newType) {
                          _onChangeCandidateType(newType);
                        },
                        itemBuilder: (context) =>
                            DescriptorRegistry.supportedTypeKeys.map((typeKey) {
                          final d = DescriptorRegistry.getDescriptor(typeKey);
                          return PopupMenuItem<String>(
                            value: typeKey,
                            child: Text(d?.displayName ?? typeKey),
                          );
                        }).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                descriptor?.displayName ??
                                    candidate.targetTypeKey,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Validation Banner
                  if (validation.isValid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 18, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ready to commit. All domain invariants are satisfied.',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Cannot create ${candidate.targetTypeKey[0].toUpperCase() + candidate.targetTypeKey.substring(1)}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...validation.blockingErrors.map((err) => Padding(
                                padding: const EdgeInsets.only(left: 26, top: 2),
                                child: Text(
                                  '• $err',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Commit to Compendium Action
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: validation.isValid
                            ? theme.colorScheme.primary
                            : theme.disabledColor.withValues(alpha: 0.2),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        validation.isValid
                            ? 'Commit ${candidate.targetTypeKey[0].toUpperCase() + candidate.targetTypeKey.substring(1)} to Codex'
                            : 'Resolve Missing/Invalid Fields to Commit',
                      ),
                      onPressed: validation.isValid && !_isSaving
                          ? () => _commitCandidate(candidate)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Evidence Details Expansion Tile
          if (candidate.identification.evidence.isNotEmpty)
            ExpansionTile(
              title: Text(
                'Identification Evidence (${candidate.identification.evidence.length} signals)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              children: candidate.identification.evidence.map((ev) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.check, size: 14, color: Colors.greenAccent),
                  title: Text(ev.category,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(ev.description,
                      style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          Text(
            'Schema Fields (${descriptor?.fields.length ?? 0} expected)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Extracted, inferred, missing, and invalid fields are displayed below. You can correct values in place.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // List of fields
          if (descriptor != null)
            ...descriptor.fields.map((desc) {
              final field = candidate.fields[desc.key];
              if (field == null) return const SizedBox.shrink();

              return FieldEditorTile(
                field: field,
                onValueChanged: (val) {
                  _onFieldEdited(desc.key, val);
                },
              );
            }),

          // Unrecognized blocks section
          if (candidate.unrecognizedBlocks.isNotEmpty) ...[
            const SizedBox(height: 16),
            UnrecognizedSourceView(
              title: 'Unrecognized Content in this Entry',
              explanation:
                  'The parser detected these blocks inside the candidate boundary but could not map them to any standard field. You can mark them as ignored if they are notes or flavor text.',
              blocks: candidate.unrecognizedBlocks,
              ignoredBlockIds: candidate.ignoredBlockIds,
              onToggleIgnore: _onToggleIgnoreBlock,
            ),
          ],
        ],
      ),
    );
  }
}
