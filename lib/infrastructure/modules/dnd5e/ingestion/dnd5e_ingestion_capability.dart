import '../../../../domain/ingestion/capability/ruleset_ingestion_capability.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_candidate.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';
import '../../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../../models/domain/core_types.dart';
import '../../../../models/domain/homebrew_extended_entities.dart';
import '../../../../models/domain/spell_monster_equipment.dart';
import '../../../../services/persistence/homebrew_persistence_service.dart';
import 'dnd5e_background_descriptor.dart';
import 'dnd5e_background_field_extractor.dart';
import 'dnd5e_class_descriptor.dart';
import 'dnd5e_class_field_extractor.dart';
import 'dnd5e_feat_descriptor.dart';
import 'dnd5e_feat_field_extractor.dart';
import 'dnd5e_item_descriptor.dart';
import 'dnd5e_item_field_extractor.dart';
import 'dnd5e_monster_descriptor.dart';
import 'dnd5e_monster_field_extractor.dart';
import 'dnd5e_species_descriptor.dart';
import 'dnd5e_species_field_extractor.dart';
import 'dnd5e_spell_descriptor.dart';
import 'dnd5e_spell_field_extractor.dart';
import 'dnd5e_subclass_descriptor.dart';
import 'dnd5e_subclass_field_extractor.dart';

/// 5e Ruleset Ingestion Capability.
///
/// Encapsulates all 5e-specific ingestion knowledge, including target descriptors,
/// stat block / compendium extractors, domain validation, and entity construction.
/// The generic ingestion engine and UI interact with 5e only through this capability.
class Dnd5eIngestionCapability implements RulesetIngestionCapability {
  final DmRulesEdition edition;

  const Dnd5eIngestionCapability({
    this.edition = DmRulesEdition.v2024,
  });

  @override
  String get rulesetId =>
      edition == DmRulesEdition.v2024 ? 'dnd5e_2024' : 'dnd5e_2014';

  @override
  String get displayName => edition == DmRulesEdition.v2024
      ? 'D&D 5e (2024 Revised / SRD 5.2.1)'
      : 'D&D 5e (2014 Rules / SRD 5.1)';

  RulesetVersion get _rulesetVersion => edition == DmRulesEdition.v2024
      ? RulesetVersion.v2024
      : RulesetVersion.v2014;

  static const _monsterDescriptor = Dnd5eMonsterDescriptor();
  static const _spellDescriptor = Dnd5eSpellDescriptor();
  static const _itemDescriptor = Dnd5eItemDescriptor();
  static const _featDescriptor = Dnd5eFeatDescriptor();
  static const _classDescriptor = Dnd5eClassDescriptor();
  static const _subclassDescriptor = Dnd5eSubclassDescriptor();
  static const _speciesDescriptor = Dnd5eSpeciesDescriptor();
  static const _backgroundDescriptor = Dnd5eBackgroundDescriptor();

  static const _monsterExtractor = Dnd5eMonsterFieldExtractor();
  static const _spellExtractor = Dnd5eSpellFieldExtractor();
  static const _itemExtractor = Dnd5eItemFieldExtractor();
  static const _featExtractor = Dnd5eFeatFieldExtractor();
  static const _classExtractor = Dnd5eClassFieldExtractor();
  static const _subclassExtractor = Dnd5eSubclassFieldExtractor();
  static const _speciesExtractor = Dnd5eSpeciesFieldExtractor();
  static const _backgroundExtractor = Dnd5eBackgroundFieldExtractor();

  @override
  Iterable<IngestionTargetDescriptor> get supportedTargets => const [
        _monsterDescriptor,
        _spellDescriptor,
        _itemDescriptor,
        _featDescriptor,
        _classDescriptor,
        _subclassDescriptor,
        _speciesDescriptor,
        _backgroundDescriptor,
      ];

  @override
  IngestionTargetDescriptor? getTargetDescriptor(String? typeKey) {
    if (typeKey == null) return null;
    final lower = typeKey.toLowerCase().trim();
    if (lower == 'monster' || lower == 'creature') return _monsterDescriptor;
    if (lower == 'spell') return _spellDescriptor;
    if (lower == 'item' || lower == 'equipment') return _itemDescriptor;
    if (lower == 'feat') return _featDescriptor;
    if (lower == 'class' || lower == 'classdefinition') return _classDescriptor;
    if (lower == 'subclass') return _subclassDescriptor;
    if (lower == 'species' || lower == 'race') return _speciesDescriptor;
    if (lower == 'background') return _backgroundDescriptor;
    return null;
  }

  @override
  Map<String, IngestionField<dynamic>> extractFields({
    required String targetTypeKey,
    required List<SourceBlock> blocks,
    SourceSpan? span,
  }) {
    final lower = targetTypeKey.toLowerCase().trim();
    if (lower == 'monster' || lower == 'creature') {
      return _monsterExtractor
          .extract(blocks: blocks, descriptor: _monsterDescriptor, span: span)
          .fields;
    } else if (lower == 'spell') {
      return _spellExtractor
          .extract(blocks: blocks, descriptor: _spellDescriptor, span: span)
          .fields;
    } else if (lower == 'item' || lower == 'equipment') {
      return _itemExtractor
          .extract(blocks: blocks, descriptor: _itemDescriptor, span: span)
          .fields;
    } else if (lower == 'feat') {
      return _featExtractor
          .extract(blocks: blocks, descriptor: _featDescriptor, span: span)
          .fields;
    } else if (lower == 'class' || lower == 'classdefinition') {
      return _classExtractor
          .extract(blocks: blocks, descriptor: _classDescriptor, span: span)
          .fields;
    } else if (lower == 'subclass') {
      return _subclassExtractor
          .extract(blocks: blocks, descriptor: _subclassDescriptor, span: span)
          .fields;
    } else if (lower == 'species' || lower == 'race') {
      return _speciesExtractor
          .extract(blocks: blocks, descriptor: _speciesDescriptor, span: span)
          .fields;
    } else if (lower == 'background') {
      return _backgroundExtractor
          .extract(blocks: blocks, descriptor: _backgroundDescriptor, span: span)
          .fields;
    }
    return const {};
  }

  @override
  CandidateValidationResult validateCandidate(IngestionCandidate candidate) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. Candidate must have a resolved type
    if (!candidate.isTypeResolved) {
      errors.add(
        'Candidate object type is unresolved (${candidate.identification.summaryLabel}). '
        'Please select a candidate type before committing.',
      );
      return CandidateValidationResult.invalid(
        errors: errors,
        warnings: warnings,
      );
    }

    final descriptor = getTargetDescriptor(candidate.targetTypeKey);
    if (descriptor == null) {
      errors.add('Unsupported candidate type: "${candidate.targetTypeKey}".');
      return CandidateValidationResult.invalid(
        errors: errors,
        warnings: warnings,
      );
    }

    final lowerType = candidate.targetTypeKey!.toLowerCase().trim();
    if (lowerType == 'monster' || lowerType == 'creature') {
      _validateMonsterDomainInvariants(candidate, errors);
    } else if (lowerType == 'spell') {
      _validateSpellDomainInvariants(candidate, errors);
    } else if (lowerType == 'item' || lowerType == 'equipment') {
      _validateItemDomainInvariants(candidate, errors);
    } else if (lowerType == 'feat') {
      _validateFeatDomainInvariants(candidate, errors);
    } else if (lowerType == 'class' || lowerType == 'classdefinition') {
      _validateClassDomainInvariants(candidate, errors);
    } else if (lowerType == 'subclass') {
      _validateSubclassDomainInvariants(candidate, errors);
    } else if (lowerType == 'species' || lowerType == 'race') {
      _validateSpeciesDomainInvariants(candidate, errors);
    } else if (lowerType == 'background') {
      _validateBackgroundDomainInvariants(candidate, errors);
    }

    // 2. Syntactic / field-level invalid states
    for (final field in candidate.fields.values) {
      if (field.state == IngestionFieldState.invalid) {
        errors.add(
            'Invalid field ${field.label}: ${field.validationError ?? "Failed validation"}');
      } else if (field.state == IngestionFieldState.ambiguous) {
        errors.add(
            'Ambiguous field ${field.label}: source contains unresolved uncertainty.');
      }
    }

    // 3. Candidate-level errors
    errors.addAll(candidate.errors);

    // 4. Non-blocking warnings for unrecognized source blocks
    if (candidate.unrecognizedBlocks.isNotEmpty) {
      final unignored = candidate.unrecognizedBlocks
          .where((b) => !candidate.ignoredBlockIds.contains(b.id))
          .length;
      if (unignored > 0) {
        warnings.add(
            '$unignored unassigned text blocks will not be part of the final entity.');
      }
    }

    if (errors.isNotEmpty) {
      return CandidateValidationResult.invalid(
        errors: errors,
        warnings: warnings,
      );
    }

    return CandidateValidationResult.valid(warnings: warnings);
  }

  void _validateMonsterDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Monster Name', errors);
    _checkRequiredPositiveInt(candidate, 'armorClass', 'Armor Class', errors);
    _checkRequiredPositiveInt(candidate, 'hitPoints', 'Hit Points', errors);
    _checkRequiredString(candidate, 'speed', 'Speed', errors);
    _checkRequiredString(candidate, 'size', 'Size', errors);
    _checkRequiredString(candidate, 'monsterType', 'Creature Type', errors);
    _checkRequiredString(candidate, 'alignment', 'Alignment', errors);
    _checkRequiredString(candidate, 'challengeRating', 'Challenge Rating', errors);
  }

  void _validateSpellDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Spell Name', errors);
    _checkRequiredSpellLevel(candidate, 'level', 'Spell Level', errors);
    _checkRequiredString(candidate, 'school', 'School of Magic', errors);
    _checkRequiredString(candidate, 'castingTime', 'Casting Time', errors);
    _checkRequiredString(candidate, 'range', 'Range', errors);
    _checkRequiredString(candidate, 'components', 'Components', errors);
    _checkRequiredString(candidate, 'duration', 'Duration', errors);
    _checkRequiredString(candidate, 'descriptionMarkdown', 'Description', errors);
  }

  void _validateItemDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Item Name', errors);
    _checkRequiredString(candidate, 'itemType', 'Item Type', errors);
    _checkRequiredString(candidate, 'rarity', 'Rarity', errors);
    _checkRequiredString(candidate, 'descriptionMarkdown', 'Description', errors);
  }

  void _validateFeatDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Feat Name', errors);
    _checkRequiredString(candidate, 'descriptionMarkdown', 'Description', errors);
  }

  void _validateClassDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Class Name', errors);
    _checkRequiredHitDie(candidate, 'hitDie', 'Hit Die', errors);
    _checkRequiredStringList(candidate, 'savingThrows', 'Saving Throws', errors);
  }

  void _validateSubclassDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Subclass Name', errors);
    _checkRequiredString(candidate, 'classSlug', 'Parent Class', errors);
    _checkRequiredString(candidate, 'featuresMarkdown', 'Subclass Features', errors);
  }

  void _validateSpeciesDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Species Name', errors);
    _checkRequiredString(candidate, 'size', 'Size', errors);
    _checkRequiredString(candidate, 'speed', 'Speed', errors);
    _checkRequiredString(candidate, 'traitsMarkdown', 'Traits', errors);
  }

  void _validateBackgroundDomainInvariants(
    IngestionCandidate candidate,
    List<String> errors,
  ) {
    _checkRequiredString(candidate, 'name', 'Background Name', errors);
    _checkRequiredStringList(candidate, 'skillProficiencies', 'Skill Proficiencies', errors);
    _checkRequiredString(candidate, 'descriptionMarkdown', 'Description', errors);
  }

  void _checkRequiredString(
    IngestionCandidate candidate,
    String key,
    String label,
    List<String> errors,
  ) {
    final field = candidate.fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      errors.add('Missing required field: $label');
      return;
    }
    final val = field.value?.toString().trim();
    if (val == null || val.isEmpty) {
      errors.add('Missing required field: $label');
    }
  }

  void _checkRequiredPositiveInt(
    IngestionCandidate candidate,
    String key,
    String label,
    List<String> errors,
  ) {
    final field = candidate.fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      errors.add('Missing required field: $label');
      return;
    }
    final val = field.value;
    if (val is int) {
      if (val <= 0) errors.add('$label must be greater than 0');
      return;
    }
    final parsed = int.tryParse(val?.toString().trim() ?? '');
    if (parsed == null || parsed <= 0) {
      errors.add('Invalid $label: expected a positive integer');
    }
  }

  void _checkRequiredSpellLevel(
    IngestionCandidate candidate,
    String key,
    String label,
    List<String> errors,
  ) {
    final field = candidate.fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      errors.add('Missing required field: $label');
      return;
    }
    final val = field.value;
    int? parsed;
    if (val is int) {
      parsed = val;
    } else {
      parsed = int.tryParse(val?.toString().trim() ?? '');
    }
    if (parsed == null || parsed < 0 || parsed > 9) {
      errors.add('$label must be between 0 (cantrip) and 9');
    }
  }

  void _checkRequiredHitDie(
    IngestionCandidate candidate,
    String key,
    String label,
    List<String> errors,
  ) {
    final field = candidate.fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      errors.add('Missing required field: $label');
      return;
    }
    final val = field.value?.toString().trim().toLowerCase();
    if (val == null || !RegExp(r'^(?:1)?d(?:6|8|10|12)$').hasMatch(val)) {
      errors.add('$label must be valid hit die notation (d6, d8, d10, d12)');
    }
  }

  void _checkRequiredStringList(
    IngestionCandidate candidate,
    String key,
    String label,
    List<String> errors,
  ) {
    final field = candidate.fields[key];
    if (field == null || field.state == IngestionFieldState.missing || field.value == null) {
      errors.add('Missing required field: $label');
      return;
    }
    if (field.value is List) {
      final list = field.value as List;
      if (list.isEmpty) {
        errors.add('Missing required field: $label');
      }
      return;
    }
    final str = field.value.toString().trim();
    if (str.isEmpty) {
      errors.add('Missing required field: $label');
    }
  }

  @override
  DomainConversionResult convertCandidate(IngestionCandidate candidate) {
    final validation = validateCandidate(candidate);
    if (!validation.isValid) {
      return DomainConversionResult.failure(validation.blockingErrors);
    }

    final lower = candidate.targetTypeKey!.toLowerCase().trim();
    switch (lower) {
      case 'monster':
      case 'creature':
        return _convertMonster(candidate);
      case 'spell':
        return _convertSpell(candidate);
      case 'item':
      case 'equipment':
        return _convertItem(candidate);
      case 'feat':
        return _convertFeat(candidate);
      case 'class':
      case 'classdefinition':
        return _convertClass(candidate);
      case 'subclass':
        return _convertSubclass(candidate);
      case 'species':
      case 'race':
        return _convertSpecies(candidate);
      case 'background':
        return _convertBackground(candidate);
      default:
        return DomainConversionResult.failure([
          'Unsupported domain entity type "${candidate.targetTypeKey}".',
        ]);
    }
  }

  DomainConversionResult _convertMonster(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Monster Name');
      final size = _requireString(fields, 'size', 'Size');
      final type = _requireString(fields, 'monsterType', 'Creature Type');
      final alignment = _requireString(fields, 'alignment', 'Alignment');
      final armorClass = _requirePositiveInt(fields, 'armorClass', 'Armor Class');
      final hitPoints = _requirePositiveInt(fields, 'hitPoints', 'Hit Points');
      final speed = _requireString(fields, 'speed', 'Speed');
      final challengeRating = _requireString(fields, 'challengeRating', 'Challenge Rating');

      final hitDieFormula = _optionalString(fields, 'hitDieFormula') ?? '';
      final actionsMarkdown = _optionalString(fields, 'actionsMarkdown') ?? '';

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
        'speed': speed,
      };

      if (fields['traitsMarkdown']?.value != null) {
        customProps['traitsMarkdown'] = fields['traitsMarkdown']!.value.toString();
      }
      if (fields['reactionsMarkdown']?.value != null) {
        customProps['reactionsMarkdown'] = fields['reactionsMarkdown']!.value.toString();
      }
      if (fields['legendaryActionsMarkdown']?.value != null) {
        customProps['legendaryActionsMarkdown'] =
            fields['legendaryActionsMarkdown']!.value.toString();
      }

      for (final stat in [
        'strength',
        'dexterity',
        'constitution',
        'intelligence',
        'wisdom',
        'charisma',
      ]) {
        if (fields[stat]?.value != null) {
          customProps[stat] = fields[stat]!.value;
        }
      }

      final monster = Monster(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        size: size,
        monsterType: type,
        alignment: alignment,
        armorClass: armorClass,
        hitPoints: hitPoints,
        hitDieFormula: hitDieFormula,
        challengeRating: challengeRating,
        actionsMarkdown: actionsMarkdown,
        customProperties: customProps,
      );

      return DomainConversionResult.success(monster);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Monster: $e']);
    }
  }

  DomainConversionResult _convertSpell(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Spell Name');
      final level = _requireSpellLevel(fields, 'level', 'Spell Level');
      final school = _requireString(fields, 'school', 'School of Magic');
      final castingTime = _requireString(fields, 'castingTime', 'Casting Time');
      final range = _requireString(fields, 'range', 'Range');
      final components = _requireString(fields, 'components', 'Components');
      final duration = _requireString(fields, 'duration', 'Duration');
      final description = _requireString(fields, 'descriptionMarkdown', 'Description');
      final higherLevels = _optionalString(fields, 'higherLevelsMarkdown');

      final compLower = components.toLowerCase();
      final compObj = SpellComponents(
        v: compLower.contains('v'),
        s: compLower.contains('s'),
        m: compLower.contains('m'),
        materialDescription: components,
      );

      final actionType = ActionType.fromString(castingTime);
      final castTimeObj = CastingTime(cost: 1, actionType: actionType);

      final durLower = duration.toLowerCase();
      final isConc = durLower.contains('concentration');
      final durationType = durLower.contains('instant')
          ? DurationType.instantaneous
          : (durLower.contains('round')
              ? DurationType.rounds
              : (durLower.contains('minute') ||
                      durLower.contains('hour') ||
                      durLower.contains('day')
                  ? DurationType.timed
                  : (durLower.contains('permanent') ||
                          durLower.contains('dispelled')
                      ? DurationType.permanent
                      : DurationType.special)));
      final durationObj = SpellDuration(
        type: durationType,
        requiresConcentration: isConc,
        rawText: duration,
      );

      final spell = Spell(
        id: EntityId(
          slug: _slugify(name),
          ruleset: _rulesetVersion,
        ),
        name: name,
        level: level,
        school: school,
        castingTime: castTimeObj,
        range: range,
        components: compObj,
        duration: durationObj,
        descriptionMarkdown: description,
        higherLevelsMarkdown: higherLevels,
        customProperties: {
          'sourceText': candidate.rawSource,
          'castingTimeRaw': castingTime,
          'durationRaw': duration,
        },
      );

      return DomainConversionResult.success(spell);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Spell: $e']);
    }
  }

  DomainConversionResult _convertItem(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Item Name');
      final itemType = _requireString(fields, 'itemType', 'Item Type');
      final rarity = _requireString(fields, 'rarity', 'Rarity');
      final description = _requireString(fields, 'descriptionMarkdown', 'Description');
      final requiresAttunement = fields['requiresAttunement']?.value == true;
      final attunementDetails = _optionalString(fields, 'attunementDetails');

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };
      if (attunementDetails != null) {
        customProps['attunementDetails'] = attunementDetails;
      }

      final item = EquipmentItem(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        itemType: itemType,
        rarity: rarity,
        requiresAttunement: requiresAttunement,
        descriptionMarkdown: description,
        customProperties: customProps,
      );

      return DomainConversionResult.success(item);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct EquipmentItem: $e']);
    }
  }

  DomainConversionResult _convertFeat(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Feat Name');
      final description = _requireString(fields, 'descriptionMarkdown', 'Description');
      final prerequisite = _optionalString(fields, 'prerequisite');
      final category = _optionalString(fields, 'category') ?? 'General';

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };

      final feat = Feat(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        prerequisite: prerequisite,
        category: category,
        descriptionMarkdown: description,
        customProperties: customProps,
      );

      return DomainConversionResult.success(feat);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Feat: $e']);
    }
  }

  DomainConversionResult _convertClass(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Class Name');
      final hitDie = _requireString(fields, 'hitDie', 'Hit Die');
      final savingThrows = _requireStringList(fields, 'savingThrows', 'Saving Throws');
      final primaryAbility = _optionalString(fields, 'primaryAbility');
      final armorProficiencies = _optionalStringList(fields, 'armorProficiencies') ?? const [];
      final weaponProficiencies = _optionalStringList(fields, 'weaponProficiencies') ?? const [];
      final subclassSelectionLevel = _optionalPositiveInt(fields, 'subclassSelectionLevel') ?? 3;
      final featuresMarkdown = _optionalString(fields, 'featuresMarkdown') ?? '';

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };

      final characterClass = CharacterClass(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        hitDie: hitDie,
        primaryAbility: primaryAbility,
        savingThrows: savingThrows,
        armorProficiencies: armorProficiencies,
        weaponProficiencies: weaponProficiencies,
        subclassSelectionLevel: subclassSelectionLevel,
        featuresMarkdown: featuresMarkdown,
        customProperties: customProps,
      );

      return DomainConversionResult.success(characterClass);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct CharacterClass: $e']);
    }
  }

  DomainConversionResult _convertSubclass(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Subclass Name');
      final classSlug = _requireString(fields, 'classSlug', 'Parent Class');
      final featuresMarkdown = _requireString(fields, 'featuresMarkdown', 'Subclass Features');
      final shortName = _optionalString(fields, 'shortName');

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
        'classSlug': classSlug,
      };

      final subclass = Subclass(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        classSlug: classSlug,
        shortName: shortName,
        featuresMarkdown: featuresMarkdown,
        customProperties: customProps,
      );

      return DomainConversionResult.success(subclass);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Subclass: $e']);
    }
  }

  DomainConversionResult _convertSpecies(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Species Name');
      final size = _requireString(fields, 'size', 'Size');
      final speed = _requireString(fields, 'speed', 'Speed');
      final traitsMarkdown = _requireString(fields, 'traitsMarkdown', 'Traits');
      final abilityScoreSummary = _optionalString(fields, 'abilityScoreSummary');
      final creatureType = _optionalString(fields, 'creatureType');

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };
      if (creatureType != null) {
        customProps['creatureType'] = creatureType;
      }

      final race = Race(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        size: size,
        speed: speed,
        abilityScoreSummary: abilityScoreSummary,
        traitsMarkdown: traitsMarkdown,
        customProperties: customProps,
      );

      return DomainConversionResult.success(race);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Species: $e']);
    }
  }

  DomainConversionResult _convertBackground(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = _requireString(fields, 'name', 'Background Name');
      final skillProficiencies = _requireStringList(fields, 'skillProficiencies', 'Skill Proficiencies');
      final description = _requireString(fields, 'descriptionMarkdown', 'Description');
      final toolProficiencies = _optionalStringList(fields, 'toolProficiencies') ?? const [];
      final languages = _optionalStringList(fields, 'languages') ?? const [];
      final abilityScoreSummary = _optionalString(fields, 'abilityScoreSummary');
      final originFeat = _optionalString(fields, 'originFeat');

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };

      final background = Background(
        id: EntityId(slug: _slugify(name), ruleset: _rulesetVersion),
        name: name,
        skillProficiencies: skillProficiencies,
        toolProficiencies: toolProficiencies,
        languages: languages,
        abilityScoreSummary: abilityScoreSummary,
        originFeat: originFeat,
        descriptionMarkdown: description,
        customProperties: customProps,
      );

      return DomainConversionResult.success(background);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Background: $e']);
    }
  }

  String _requireString(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
  ) {
    final field = fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      throw FormatException('Missing required field: $label');
    }
    final val = field.value?.toString().trim();
    if (val == null || val.isEmpty) {
      throw FormatException('Missing required field: $label');
    }
    return val;
  }

  int _requirePositiveInt(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
  ) {
    final field = fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      throw FormatException('Missing required field: $label');
    }
    final val = field.value;
    int? intVal;
    if (val is int) {
      intVal = val;
    } else {
      intVal = int.tryParse(val?.toString().trim() ?? '');
    }
    if (intVal == null || intVal <= 0) {
      throw FormatException('Invalid positive integer for $label: "$val"');
    }
    return intVal;
  }

  int _requireSpellLevel(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
  ) {
    final field = fields[key];
    if (field == null || field.state == IngestionFieldState.missing) {
      throw FormatException('Missing required field: $label');
    }
    final val = field.value;
    int? intVal;
    if (val is int) {
      intVal = val;
    } else {
      intVal = int.tryParse(val?.toString().trim() ?? '');
    }
    if (intVal == null || intVal < 0 || intVal > 9) {
      throw FormatException('Invalid spell level for $label: "$val"');
    }
    return intVal;
  }

  List<String> _requireStringList(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
  ) {
    final field = fields[key];
    if (field == null || field.state == IngestionFieldState.missing || field.value == null) {
      throw FormatException('Missing required field: $label');
    }
    if (field.value is List) {
      final list = (field.value as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isEmpty) {
        throw FormatException('Required list field $label is empty');
      }
      return list;
    }
    if (field.value is String) {
      final str = field.value.toString().trim();
      if (str.isEmpty) throw FormatException('Missing required field: $label');
      return str
          .split(RegExp(r'[,/]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    throw FormatException('Invalid format for $label: expected list of strings');
  }

  List<String>? _optionalStringList(
    Map<String, IngestionField<dynamic>> fields,
    String key,
  ) {
    final field = fields[key];
    if (field == null || field.value == null) return null;
    if (field.value is List) {
      return (field.value as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (field.value is String) {
      return field.value
          .toString()
          .split(RegExp(r'[,/]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return null;
  }

  int? _optionalPositiveInt(
    Map<String, IngestionField<dynamic>> fields,
    String key,
  ) {
    final field = fields[key];
    final val = field?.value;
    if (val == null) return null;
    if (val is int && val > 0) return val;
    final parsed = int.tryParse(val.toString().trim());
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  String? _optionalString(
    Map<String, IngestionField<dynamic>> fields,
    String key,
  ) {
    final field = fields[key];
    final val = field?.value?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : null;
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Future<void> persistEntity(Object entity, dynamic persistenceService) async {
    if (persistenceService is HomebrewPersistenceService) {
      if (entity is Monster) {
        await persistenceService.saveCustomMonster(entity);
      } else if (entity is Spell) {
        await persistenceService.saveCustomSpell(entity);
      } else if (entity is EquipmentItem) {
        await persistenceService.saveCustomItem(entity);
      } else if (entity is Feat) {
        await persistenceService.saveCustomFeat(entity);
      } else if (entity is CharacterClass) {
        await persistenceService.saveCustomClass(entity);
      } else if (entity is Subclass) {
        await persistenceService.saveCustomSubclass(entity);
      } else if (entity is Race) {
        await persistenceService.saveCustomRace(entity);
      } else if (entity is Background) {
        await persistenceService.saveCustomBackground(entity);
      } else {
        throw UnsupportedError('Unsupported 5e entity type: ${entity.runtimeType}');
      }
    } else {
      throw UnsupportedError('Unsupported persistence service: ${persistenceService.runtimeType}');
    }
  }
}
