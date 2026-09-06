import 'package:flutter/material.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/haptic_service.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import '../common/formatted_markdown_text.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

/// Modal dialog allowing players and DMs to add standard, homebrew, or custom bonus feats
/// directly to a character sheet, with optional ability, skill, and expertise choices.
class AddFeatDialog extends StatefulWidget {
  final CharacterSheetController controller;

  const AddFeatDialog({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, CharacterSheetController controller) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddFeatDialog(controller: controller),
    );
  }

  @override
  State<AddFeatDialog> createState() => _AddFeatDialogState();
}

class _AddFeatDialogState extends State<AddFeatDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _customNameCtrl = TextEditingController();
  final TextEditingController _customDescCtrl = TextEditingController();

  List<Feat> _allFeats = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  Feat? _selectedFeat;
  bool _isCustomMode = false;

  // Selections for chosen feat
  AbilityType? _chosenAbility;
  SkillType? _chosenSkill;
  SkillType? _chosenExpertise;
  String? _chosenOptionId;

  // Custom feat properties
  AbilityType? _customAbility;
  SkillType? _customSkill;
  SkillType? _customExpertise;

  @override
  void initState() {
    super.initState();
    _loadFeats();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reasonCtrl.dispose();
    _customNameCtrl.dispose();
    _customDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFeats() async {
    final custom = await HomebrewPersistenceService().loadCustomFeats();
    final combined = <Feat>[...SrdFeatsLibrary.allFeats];

    for (final c in custom) {
      if (!combined.any((f) => f.id.slug == c.id.slug)) {
        combined.add(c);
      }
    }

    combined.sort((a, b) => a.name.compareTo(b.name));

    if (mounted) {
      setState(() {
        _allFeats = combined;
        _isLoading = false;
        if (combined.isNotEmpty) {
          _selectFeat(combined.first);
        }
      });
    }
  }

  void _selectFeat(Feat feat) {
    _selectedFeat = feat;
    _isCustomMode = false;

    // Default ability choice
    if (feat.hasAbilityScoreIncrease && feat.selectableAbilities.isNotEmpty) {
      _chosenAbility = feat.selectableAbilities.first;
    } else {
      _chosenAbility = null;
    }

    // Default skill choice
    if (feat.hasSkillProficiencyChoice && feat.selectableSkills.isNotEmpty) {
      _chosenSkill = feat.selectableSkills.first;
    } else {
      _chosenSkill = null;
    }

    // Default expertise choice
    if (feat.hasExpertiseChoice) {
      final eligible = _getEligibleExpertiseSkills(_chosenSkill);
      _chosenExpertise = eligible.isNotEmpty ? eligible.first : null;
    } else {
      _chosenExpertise = null;
    }

    // Default feature option choice (invocation, fighting style)
    if (feat.hasInvocationChoice) {
      final eligible = _getEligibleInvocations(feat);
      _chosenOptionId = eligible.isNotEmpty ? eligible.first.id : null;
    } else if (feat.hasFightingStyleChoice) {
      _chosenOptionId = SrdFeatureOptions.fightingStyles.isNotEmpty
          ? SrdFeatureOptions.fightingStyles.first.id
          : null;
    } else {
      _chosenOptionId = null;
    }
  }

  /// Calculates eligible invocations under RAW rules for a character taking Eldritch Adept.
  List<FeatureOption> _getEligibleInvocations(Feat feat) {
    final character = widget.controller.character;
    final isWarlock = character.progression.classes.any((c) => c.classRef.slug.toLowerCase() == 'warlock');
    final warlockClass = character.progression.classes.where((c) => c.classRef.slug.toLowerCase() == 'warlock').firstOrNull;
    final warlockLevel = warlockClass?.level ?? 0;
    final selectedPacts = character.progression.classes.expand((c) => c.selectedFeatureOptions.values.expand((opts) => opts));
    final knownSpells = character.spellsKnown.map((s) => s.slug).toSet();

    return SrdFeatureOptions.warlockInvocations.where((opt) {
      final eval = feat.evaluateInvocationPrerequisite(
        opt,
        isWarlock: isWarlock,
        warlockLevel: warlockLevel,
        selectedPacts: selectedPacts,
        knownSpellSlugs: knownSpells,
      );
      return eval.isMet;
    }).toList();
  }

  /// Calculates eligible skills for expertise:
  /// Any skill the character is already proficient in, PLUS the newly chosen skill from this feat.
  List<SkillType> _getEligibleExpertiseSkills(SkillType? newSkill) {
    final charSkills = widget.controller.character.skillProficiencies;
    final eligible = <SkillType>[];

    for (final entry in charSkills.entries) {
      if (entry.value == SkillProficiencyLevel.proficient ||
          entry.value == SkillProficiencyLevel.expertise) {
        eligible.add(entry.key);
      }
    }

    if (newSkill != null && !eligible.contains(newSkill)) {
      eligible.add(newSkill);
    }

    if (eligible.isEmpty) {
      eligible.addAll(SkillType.values);
    }

    eligible.sort((a, b) => a.displayName.compareTo(b.displayName));
    return eligible;
  }

  List<Feat> get _filteredFeats {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _allFeats.where((f) {
      final matchesCategory = _selectedCategory == 'All' ||
          f.category.toLowerCase().contains(_selectedCategory.toLowerCase());
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;
      return f.name.toLowerCase().contains(query) ||
          f.descriptionMarkdown.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _submit() async {
    HapticService.selectionTick(context);

    if (_isCustomMode) {
      final name = _customNameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name for the custom feat.')),
        );
        return;
      }

      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      final featRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: slug.isNotEmpty ? slug : 'custom-feat',
        displayName: name,
      );

      Navigator.of(context).pop();

      await widget.controller.addFeat(
        featRef,
        reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
        abilityBonus: _customAbility,
        bonusAmount: 1,
        skillGrant: _customSkill,
        expertiseGrant: _customExpertise,
      );
    } else if (_selectedFeat != null) {
      final feat = _selectedFeat!;
      final featRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: feat.id.slug,
        displayName: feat.name,
      );

      Navigator.of(context).pop();

      await widget.controller.addFeat(
        featRef,
        reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
        abilityBonus: _chosenAbility,
        bonusAmount: feat.statIncreaseAmount > 0 ? feat.statIncreaseAmount : 1,
        skillGrant: _chosenSkill,
        expertiseGrant: _chosenExpertise,
        featureOptions: _chosenOptionId != null ? [_chosenOptionId!] : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkedCampaigns = widget.controller.getLinkedCampaigns();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.military_tech, color: Colors.amberAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Feat / Bonus Feat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Assigning to ${widget.controller.character.name}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Campaign Audit Notice if linked
            if (linkedCampaigns.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade900.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Linked to Campaign: ${linkedCampaigns.first.campaignName}. This bonus will be logged in the campaign audit log.',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search & Category Filters
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Search feats by name or keyword...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    suffixIcon: _searchCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () => _searchCtrl.clear(),
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Custom Feat'),
                                selected: _isCustomMode,
                                selectedColor: Colors.purpleAccent.withValues(alpha: 0.3),
                                avatar: const Icon(Icons.add_circle_outline, size: 16),
                                onSelected: (val) {
                                  setState(() {
                                    _isCustomMode = val;
                                    if (val) _selectedFeat = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Category Chips
                          if (!_isCustomMode)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['All', 'Origin', 'General', 'Fighting Style', 'Epic Boon'].map((cat) {
                                  final isSel = _selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                                      selected: isSel,
                                      selectedColor: Colors.amberAccent.withValues(alpha: 0.25),
                                      onSelected: (sel) {
                                        if (sel) setState(() => _selectedCategory = cat);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 12),

                          if (_isCustomMode)
                            _buildCustomFeatForm(theme)
                          else
                            _buildStandardFeatSelector(theme),

                          const SizedBox(height: 16),

                          // Reason / Campaign Log Note Field
                          Text(
                            'Reason / Campaign Log Note (Optional):',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _reasonCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. DM granted bonus feat for completing trial, Level 1 human, etc.',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Dialog Actions Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (_isCustomMode || _selectedFeat != null) ? _submit : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(_isCustomMode ? 'Add Custom Feat' : 'Add Feat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardFeatSelector(ThemeData theme) {
    final filtered = _filteredFeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Feats Selection List
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: filtered.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No matching feats found.')))
              : ListView.separated(
                  padding: const EdgeInsets.all(4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 8, endIndent: 8),
                  itemBuilder: (context, idx) {
                    final f = filtered[idx];
                    final isSel = _selectedFeat?.id.slug == f.id.slug;
                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        dense: true,
                        selected: isSel,
                        selectedTileColor: Colors.amberAccent.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: DndGlyph.feat(
                          category: FeatCategory.parse(f.category),
                          featId: f.id.slug,
                          displayName: f.name,
                          size: 20,
                          isDarkMode: true,
                        ),
                        title: Text(
                          f.name,
                          style: TextStyle(
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.amberAccent : null,
                          ),
                        ),
                        subtitle: Text(
                          '${f.category}${f.prerequisite != null ? " • Prereq: ${f.prerequisite}" : ""}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isSel ? const Icon(Icons.check_circle, color: Colors.amberAccent, size: 18) : null,
                        onTap: () {
                          HapticService.selectionTick(context);
                          setState(() => _selectFeat(f));
                        },
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),

        // Chosen Feat Configuration Options
        if (_selectedFeat != null) ...[
          _buildFeatConfigurationPanel(_selectedFeat!, theme),
        ],
      ],
    );
  }

  Widget _buildFeatConfigurationPanel(Feat feat, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DndGlyph.feat(
                category: FeatCategory.parse(feat.category),
                featId: feat.id.slug,
                displayName: feat.name,
                size: 24,
                isDarkMode: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  feat.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amberAccent),
                ),
              ),
              Chip(
                label: Text(feat.category, style: const TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Feat Description Preview
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: FormattedMarkdownText(
                feat.descriptionMarkdown,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 1. Ability Score Improvement Choice
          if (feat.hasAbilityScoreIncrease) ...[
            Text(
              feat.requiresAbilityChoice
                  ? 'Choose Ability Score to Increase (+${feat.statIncreaseAmount}):'
                  : 'Ability Increase: +${feat.statIncreaseAmount} ${feat.selectableAbilities.first.shortName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 6),
            if (feat.requiresAbilityChoice)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: feat.selectableAbilities.map((ab) {
                  final isSel = (_chosenAbility ?? feat.selectableAbilities.first) == ab;
                  return ChoiceChip(
                    label: Text('${ab.shortName} (+${feat.statIncreaseAmount})', style: const TextStyle(fontSize: 11)),
                    selected: isSel,
                    selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    onSelected: (val) {
                      if (val) {
                        HapticService.selectionTick(context);
                        setState(() => _chosenAbility = ab);
                      }
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
          ],

          // 2. Skill Proficiency Choice
          if (feat.hasSkillProficiencyChoice) ...[
            const Text(
              'Choose Skill Proficiency (+1 Skill):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<SkillType>(
              initialValue: _chosenSkill ?? feat.selectableSkills.first,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: feat.selectableSkills.map((sk) {
                return DropdownMenuItem(
                  value: sk,
                  child: Text('${sk.displayName} (${sk.defaultAbility.shortName})', style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _chosenSkill = val;
                    // Recompute eligible expertise options to include this new skill!
                    if (feat.hasExpertiseChoice) {
                      final eligible = _getEligibleExpertiseSkills(val);
                      if (_chosenExpertise == null || !eligible.contains(_chosenExpertise)) {
                        _chosenExpertise = val; // Default to the same skill!
                      }
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // 3. Expertise Choice (supports choosing the same skill!)
          if (feat.hasExpertiseChoice) ...[
            const Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Choose Skill for Expertise (Double Proficiency):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You may select any proficient skill, or the newly chosen skill above.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 6),
            () {
              final eligible = _getEligibleExpertiseSkills(_chosenSkill);
              final activeValue = eligible.contains(_chosenExpertise)
                  ? _chosenExpertise
                  : (eligible.isNotEmpty ? eligible.first : null);

              return DropdownButtonFormField<SkillType>(
                initialValue: activeValue,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: eligible.map((sk) {
                  final isSameAsNew = sk == _chosenSkill;
                  return DropdownMenuItem(
                    value: sk,
                    child: Row(
                      children: [
                        Text('${sk.displayName} (${sk.defaultAbility.shortName})', style: const TextStyle(fontSize: 13)),
                        if (isSameAsNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                            ),
                            child: const Text('New Skill Selected Above', style: TextStyle(fontSize: 9.5, color: Colors.greenAccent)),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _chosenExpertise = val);
                  }
                },
              );
            }(),
            const SizedBox(height: 12),
          ],

          // 4. Eldritch Invocation Choice
          if (feat.hasInvocationChoice) ...[
            () {
              final character = widget.controller.character;
              final isWarlock = character.progression.classes.any((c) => c.classRef.slug.toLowerCase() == 'warlock');
              final eligibleInvocations = _getEligibleInvocations(feat);
              final activeInvocationId = eligibleInvocations.any((o) => o.id == _chosenOptionId)
                  ? _chosenOptionId
                  : (eligibleInvocations.isNotEmpty ? eligibleInvocations.first.id : null);
              final selectedOpt = eligibleInvocations.where((o) => o.id == activeInvocationId).firstOrNull;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: Colors.purpleAccent, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Choose Eldritch Invocation:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWarlock
                        ? 'As a Warlock, you may select any invocation whose prerequisites you meet.'
                        : 'Without the Warlock class, you may only select invocations with no prerequisites.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const Key('add_feat_invocation_dropdown'),
                    initialValue: activeInvocationId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: eligibleInvocations.map((opt) {
                      return DropdownMenuItem(
                        value: opt.id,
                        child: Text(opt.name, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _chosenOptionId = val);
                      }
                    },
                  ),
                  if (selectedOpt != null && selectedOpt.descriptionMarkdown.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade900.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        selectedOpt.descriptionMarkdown,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade300, fontStyle: FontStyle.italic),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            }(),
          ],

          // 5. Fighting Style Choice
          if (feat.hasFightingStyleChoice) ...[
            () {
              final activeStyleId = SrdFeatureOptions.fightingStyles.any((o) => o.id == _chosenOptionId)
                  ? _chosenOptionId
                  : (SrdFeatureOptions.fightingStyles.isNotEmpty ? SrdFeatureOptions.fightingStyles.first.id : null);
              final selectedOpt = SrdFeatureOptions.fightingStyles.where((o) => o.id == activeStyleId).firstOrNull;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.orangeAccent, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Choose Fighting Style:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const Key('add_feat_fighting_style_dropdown'),
                    initialValue: activeStyleId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: SrdFeatureOptions.fightingStyles.map((opt) {
                      return DropdownMenuItem(
                        value: opt.id,
                        child: Text(opt.name, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _chosenOptionId = val);
                      }
                    },
                  ),
                  if (selectedOpt != null && selectedOpt.descriptionMarkdown.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade900.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        selectedOpt.descriptionMarkdown,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade300, fontStyle: FontStyle.italic),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            }(),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomFeatForm(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade900.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Bonus Feat Details',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Feat Title *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customDescCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description / Rules Markdown',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Optional Custom Ability Boost
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AbilityType?>(
                  initialValue: _customAbility,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ability Boost (+1)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontSize: 12))),
                    ...AbilityType.values.map(
                      (a) => DropdownMenuItem(value: a, child: Text('+1 ${a.shortName}', style: const TextStyle(fontSize: 12))),
                    ),
                  ],
                  onChanged: (v) => setState(() => _customAbility = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<SkillType?>(
                  initialValue: _customSkill,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Skill Grant',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontSize: 12))),
                    ...SkillType.values.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.displayName, style: const TextStyle(fontSize: 12))),
                    ),
                  ],
                  onChanged: (v) => setState(() => _customSkill = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<SkillType?>(
            initialValue: _customExpertise,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Expertise Grant (Can match skill above)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontSize: 12))),
              ...SkillType.values.map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    '${s.displayName}${s == _customSkill ? " (Matches Skill Above)" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _customExpertise = v),
          ),
        ],
      ),
    );
  }
}
