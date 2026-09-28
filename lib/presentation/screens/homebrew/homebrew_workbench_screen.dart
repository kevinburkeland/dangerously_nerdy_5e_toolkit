import 'package:flutter/material.dart';
import '../../../domain/ingestion/capability/ruleset_ingestion_capability.dart';
import '../../../domain/ingestion/models/ingestion_candidate.dart';
import '../../../domain/ingestion/models/ingestion_document_result.dart';
import '../../../domain/ingestion/services/ingestion_workbench_service.dart';
import '../../../infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import '../../../services/haptic_service.dart';
import '../../../services/persistence/homebrew_persistence_service.dart';
import 'widgets/candidate_card.dart';
import 'widgets/field_editor_tile.dart';
import 'widgets/unrecognized_source_view.dart';

/// Developer and user-facing WYSIWYG Homebrew Ingestion Workbench.
/// Provides an inspectable, correctable parsing pipeline that explicitly tracks
/// missing, invalid, ambiguous, and unrecognized content.
///
/// Purely ruleset-agnostic: relies on [RulesetIngestionCapability] for schema descriptors,
/// domain validation, and entity construction.
class HomebrewWorkbenchScreen extends StatefulWidget {
  final String? initialSourceText;
  final RulesetIngestionCapability? capability;
  final IngestionWorkbenchService? workbenchService;
  final HomebrewPersistenceService? persistenceService;

  const HomebrewWorkbenchScreen({
    super.key,
    this.initialSourceText,
    this.capability,
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
A beam of brilliant light flashes out from your hand in a 5-foot-wide, 60-foot-long line. Each creature in the line must make a Constitution saving throw. On a failed save, a creature takes 6d8 radiant damage and is blinded for 1 minute.
''';

  @override
  void initState() {
    super.initState();
    final cap = widget.capability ?? const Dnd5eIngestionCapability();
    _service = widget.workbenchService ??
        IngestionWorkbenchService(capability: cap);
    _persistence = widget.persistenceService ?? HomebrewPersistenceService();

    _mobileTabController = TabController(length: 3, vsync: this);

    final initialText = widget.initialSourceText ?? _sampleMonsterText;
    _sourceController = TextEditingController(text: initialText);

    // Initial parse run
    _parseSource(initialText);

    _sourceController.addListener(_onSourceChanged);
  }

  @override
  void dispose() {
    _sourceController.removeListener(_onSourceChanged);
    _sourceController.dispose();
    _mobileTabController.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    if (_isAutoParse) {
      _parseSource(_sourceController.text);
    }
  }

  void _parseSource(String text) {
    final result = _service.parse(text);
    setState(() {
      _parseResult = result;
      if (_selectedCandidateIndex >= result.candidates.length) {
        _selectedCandidateIndex =
            result.candidates.isEmpty ? 0 : result.candidates.length - 1;
      }
    });
  }

  void _onSelectCandidate(int index) {
    if (index >= 0 && index < _parseResult.candidates.length) {
      setState(() {
        _selectedCandidateIndex = index;
      });
      // On mobile, auto-switch to Editor tab
      if (_mobileTabController.index != 2) {
        _mobileTabController.animateTo(2);
      }
    }
  }

  void _onFieldEdited(String fieldKey, dynamic newValue) {
    if (_parseResult.candidates.isEmpty) return;
    final candidate = _parseResult.candidates[_selectedCandidateIndex];
    final updated =
        _service.updateCandidateField(candidate, fieldKey, newValue);

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
      await _service.capability.persistEntity(entity, _persistence);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: const Text(
              'Successfully created and committed candidate to Codex!',
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
        title: const Text('Homebrew Ingestion Workbench'),
        actions: [
          // Auto-parse toggle
          Tooltip(
            message: _isAutoParse
                ? 'Auto-parse on change: ACTIVE'
                : 'Auto-parse: PAUSED (Explicit Refresh)',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAutoParse ? Icons.sync : Icons.sync_disabled,
                  size: 18,
                  color: _isAutoParse
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _isAutoParse ? 'Live' : 'Manual',
                  style: const TextStyle(fontSize: 12),
                ),
                Switch(
                  value: _isAutoParse,
                  onChanged: (val) => setState(() => _isAutoParse = val),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText:
                    'Paste creature stat blocks, spell cards, or homebrew text here...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkbenchPane(ThemeData theme) {
    return Column(
      children: [
        // Top candidate selector strip if multiple candidates exist
        if (_parseResult.candidates.isNotEmpty)
          Container(
            height: 104,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _parseResult.candidates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final candidate = _parseResult.candidates[index];
                return CandidateCard(
                  candidate: candidate,
                  isSelected: index == _selectedCandidateIndex,
                  onSelect: () => _onSelectCandidate(index),
                );
              },
            ),
          ),

        // Unassigned text banner if present
        if (_parseResult.unassignedBlocks.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amberAccent.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_parseResult.unassignedBlocks.length} text block(s) were not assigned to any candidate.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Bottom area: Candidate Editor
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              const Text(
                'No candidate objects detected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Paste text in the Source tab or select a sample above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _parseResult.candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final candidate = _parseResult.candidates[index];
        return CandidateCard(
          candidate: candidate,
          isSelected: index == _selectedCandidateIndex,
          onSelect: () => _onSelectCandidate(index),
        );
      },
    );
  }

  Widget _buildCandidateEditor(ThemeData theme) {
    if (_parseResult.candidates.isEmpty) {
      return Center(
        child: Text(
          'No candidate objects detected in source.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final candidate = _parseResult.candidates[_selectedCandidateIndex];
    final validation = _service.validate(candidate);
    final descriptor = candidate.isTypeResolved
        ? _service.capability.getTargetDescriptor(candidate.targetTypeKey)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Object Type Selector + Commit Button
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
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
                              candidate.isTypeResolved
                                  ? '${(candidate.identification.confidence * 100).toStringAsFixed(0)}% parser confidence'
                                  : candidate.identification.summaryLabel,
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
                        itemBuilder: (context) => _service
                            .capability.supportedTargets
                            .map((t) {
                          return PopupMenuItem<String>(
                            value: t.typeKey,
                            child: Text(t.displayName),
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
                                    (candidate.targetTypeKey ?? 'Select Type'),
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

                  // Unresolved Candidate Resolution Banner
                  if (!candidate.isTypeResolved) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline,
                                  size: 18, color: Colors.amberAccent),
                              const SizedBox(width: 8),
                              Text(
                                candidate.identification.isAmbiguous
                                    ? 'Ambiguous Object Type'
                                    : 'Unknown Object Type',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            candidate.identification.isAmbiguous
                                ? 'Multiple plausible types detected. Select the intended type to continue extraction:'
                                : 'Could not confidently identify object type. Select an object type to begin extraction:',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: (candidate.identification.isAmbiguous
                                    ? candidate.identification.plausibleTypeKeys
                                    : _service.capability.supportedTargets
                                        .map((t) => t.typeKey))
                                .map((typeKey) {
                              final d = _service.capability
                                  .getTargetDescriptor(typeKey);
                              return ActionChip(
                                avatar: const Icon(Icons.check, size: 14),
                                label: Text(d?.displayName ?? typeKey),
                                onPressed: () =>
                                    _onChangeCandidateType(typeKey),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                                candidate.isTypeResolved
                                    ? 'Cannot create ${descriptor?.displayName ?? candidate.targetTypeKey}'
                                    : 'Cannot create Candidate (Unresolved Type)',
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
                                padding:
                                    const EdgeInsets.only(left: 26, top: 2),
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        validation.isValid
                            ? 'Commit ${descriptor?.displayName ?? "Entity"} to Codex'
                            : (candidate.isTypeResolved
                                ? 'Resolve Missing/Invalid Fields to Commit'
                                : 'Select Object Type to Commit'),
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
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              children: candidate.identification.evidence.map((ev) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.check,
                      size: 14, color: Colors.greenAccent),
                  title: Text(ev.category,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle:
                      Text(ev.description, style: const TextStyle(fontSize: 11)),
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
            candidate.isTypeResolved
                ? 'Extracted, inferred, missing, and invalid fields are displayed below. You can correct values in place.'
                : 'Select an object type above to display schema fields.',
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
