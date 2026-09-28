import '../../../../domain/ingestion/capability/ruleset_ingestion_capability.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_candidate.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';
import '../../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../../models/domain/core_types.dart';
import '../../../../models/domain/spell_monster_equipment.dart';
import '../../../../services/persistence/homebrew_persistence_service.dart';
import 'dnd5e_monster_descriptor.dart';
import 'dnd5e_monster_field_extractor.dart';
import 'dnd5e_spell_descriptor.dart';
import 'dnd5e_spell_field_extractor.dart';

/// 5e Ruleset Ingestion Capability.
///
/// Encapsulates all 5e-specific ingestion knowledge, including target descriptors,
/// stat block / spell card extractors, domain validation, and entity construction.
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

  static const _monsterExtractor = Dnd5eMonsterFieldExtractor();
  static const _spellExtractor = Dnd5eSpellFieldExtractor();

  @override
  Iterable<IngestionTargetDescriptor> get supportedTargets => const [
        _monsterDescriptor,
        _spellDescriptor,
      ];

  @override
  IngestionTargetDescriptor? getTargetDescriptor(String? typeKey) {
    if (typeKey == null) return null;
    final lower = typeKey.toLowerCase().trim();
    if (lower == 'monster' || lower == 'creature') return _monsterDescriptor;
    if (lower == 'spell') return _spellDescriptor;
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
          .extract(
            blocks: blocks,
            descriptor: _monsterDescriptor,
            span: span,
          )
          .fields;
    } else if (lower == 'spell') {
      return _spellExtractor
          .extract(
            blocks: blocks,
            descriptor: _spellDescriptor,
            span: span,
          )
          .fields;
    }
    return const {};
  }

  @override
  CandidateValidationResult validateCandidate(IngestionCandidate candidate) {
    final errors = <String>[];
    final warnings = <String>[...candidate.warnings];

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
      errors.add('$label cannot be empty.');
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
    final intVal = val is int ? val : int.tryParse(val?.toString().trim() ?? '');
    if (intVal == null || intVal <= 0) {
      errors.add('$label must be a positive whole number.');
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
    final intVal = val is int ? val : int.tryParse(val?.toString().trim() ?? '');
    if (intVal == null || intVal < 0 || intVal > 9) {
      errors.add('$label must be between 0 (cantrip) and 9.');
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
      default:
        return DomainConversionResult.failure([
          'Unsupported domain entity type "${candidate.targetTypeKey}".',
        ]);
    }
  }

  DomainConversionResult _convertMonster(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      // Extract required fields - ZERO fabricated defaults!
      final name = _requireString(fields, 'name', 'Monster Name');
      final size = _requireString(fields, 'size', 'Size');
      final type = _requireString(fields, 'monsterType', 'Creature Type');
      final alignment = _requireString(fields, 'alignment', 'Alignment');
      final armorClass = _requirePositiveInt(fields, 'armorClass', 'Armor Class');
      final hitPoints = _requirePositiveInt(fields, 'hitPoints', 'Hit Points');
      final speed = _requireString(fields, 'speed', 'Speed');
      final challengeRating = _requireString(fields, 'challengeRating', 'Challenge Rating');

      // Optional fields
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

      // 6 Core Ability Scores
      for (final stat in [
        'strength',
        'dexterity',
        'constitution',
        'intelligence',
        'wisdom',
        'charisma'
      ]) {
        if (fields[stat]?.value != null) {
          customProps[stat] = fields[stat]!.value;
        }
      }

      final monster = Monster(
        id: EntityId(
          slug: _slugify(name),
          ruleset: _rulesetVersion,
        ),
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
      return DomainConversionResult.failure(['Conversion failed: $e']);
    }
  }

  DomainConversionResult _convertSpell(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      // Extract required fields - ZERO fabricated defaults!
      final name = _requireString(fields, 'name', 'Spell Name');
      final level = _requireIntInRange(fields, 'level', 'Spell Level', 0, 9);
      final school = _requireString(fields, 'school', 'School of Magic');
      final castingTime = _requireString(fields, 'castingTime', 'Casting Time');
      final range = _requireString(fields, 'range', 'Range');
      final components = _requireString(fields, 'components', 'Components');
      final duration = _requireString(fields, 'duration', 'Duration');
      final description = _requireString(fields, 'descriptionMarkdown', 'Description');

      final higherLevels = _optionalString(fields, 'higherLevelsMarkdown');

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };

      final compLower = components.toLowerCase();
      final spellComponents = SpellComponents(
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
        components: spellComponents,
        duration: durationObj,
        descriptionMarkdown: description,
        higherLevelsMarkdown: higherLevels,
        customProperties: customProps,
      );

      return DomainConversionResult.success(spell);
    } catch (e) {
      return DomainConversionResult.failure(['Conversion failed: $e']);
    }
  }

  String _requireString(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
  ) {
    final field = fields[key];
    if (field == null ||
        field.value == null ||
        field.value.toString().trim().isEmpty) {
      throw FormatException('$label is required but was not provided.');
    }
    return field.value.toString().trim();
  }

  int _requirePositiveInt(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
  ) {
    final field = fields[key];
    final val = field?.value;
    final intVal = val is int ? val : int.tryParse(val?.toString().trim() ?? '');
    if (intVal == null || intVal <= 0) {
      throw FormatException('$label must be a positive integer.');
    }
    return intVal;
  }

  int _requireIntInRange(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
    int min,
    int max,
  ) {
    final field = fields[key];
    final val = field?.value;
    final intVal = val is int ? val : int.tryParse(val?.toString().trim() ?? '');
    if (intVal == null || intVal < min || intVal > max) {
      throw FormatException('$label must be an integer between $min and $max.');
    }
    return intVal;
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
      } else {
        throw UnsupportedError('Unsupported 5e entity type: ${entity.runtimeType}');
      }
    } else {
      throw UnsupportedError('Unsupported persistence service: ${persistenceService.runtimeType}');
    }
  }
}
