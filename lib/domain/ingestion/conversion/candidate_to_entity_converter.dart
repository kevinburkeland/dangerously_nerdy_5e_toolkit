import '../../../models/domain/core_types.dart';
import '../../../models/domain/entity_reference.dart';
import '../../../models/domain/spell_monster_equipment.dart';
import '../descriptors/descriptor_registry.dart';
import '../models/field_state.dart';
import '../models/ingestion_candidate.dart';

/// Validation report on whether a candidate is structurally ready to become a domain entity.
class CandidateValidationResult {
  final bool isValid;
  final List<String> blockingErrors;
  final List<String> nonBlockingWarnings;

  const CandidateValidationResult({
    required this.isValid,
    required this.blockingErrors,
    this.nonBlockingWarnings = const [],
  });

  factory CandidateValidationResult.valid({List<String> warnings = const []}) {
    return CandidateValidationResult(
      isValid: true,
      blockingErrors: const [],
      nonBlockingWarnings: warnings,
    );
  }

  factory CandidateValidationResult.invalid({
    required List<String> errors,
    List<String> warnings = const [],
  }) {
    return CandidateValidationResult(
      isValid: false,
      blockingErrors: errors,
      nonBlockingWarnings: warnings,
    );
  }
}

/// Result of converting an IngestionCandidate into a validated DomainEntity.
class DomainConversionResult {
  final bool isSuccess;
  final DomainEntity? entity;
  final List<String> errors;

  const DomainConversionResult.success(this.entity)
      : isSuccess = true,
        errors = const [];

  const DomainConversionResult.failure(this.errors)
      : isSuccess = false,
        entity = null;
}

/// Ruleset semantic interpreter that bridges intermediate candidate drafts
/// into fully instantiated, validated DomainEntity objects.
class CandidateToEntityConverter {
  const CandidateToEntityConverter();

  /// Validates [candidate] against the schema for its [candidate.targetTypeKey].
  CandidateValidationResult validate(IngestionCandidate candidate) {
    final descriptor = DescriptorRegistry.getDescriptor(candidate.targetTypeKey);
    final errors = <String>[];
    final warnings = <String>[...candidate.warnings];

    if (descriptor == null) {
      errors.add('Unsupported candidate type: "${candidate.targetTypeKey}".');
      return CandidateValidationResult.invalid(
        errors: errors,
        warnings: warnings,
      );
    }

    // 1. Check required fields
    for (final fieldDesc in descriptor.requiredFields) {
      final field = candidate.fields[fieldDesc.key];
      if (field == null || field.state == IngestionFieldState.missing) {
        errors.add('Missing required field: ${fieldDesc.label}');
      } else if (field.state == IngestionFieldState.invalid) {
        errors.add(
            'Invalid field ${fieldDesc.label}: ${field.validationError ?? "Failed validation"}');
      } else if (field.state == IngestionFieldState.ambiguous) {
        errors.add(
            'Ambiguous field ${fieldDesc.label}: source contains uncertainty');
      } else if (field.value == null ||
          field.value.toString().trim().isEmpty) {
        errors.add('Field ${fieldDesc.label} cannot be empty');
      }
    }

    // 2. Check other fields that are in invalid state
    for (final field in candidate.fields.values) {
      if (!field.isRequired && field.state == IngestionFieldState.invalid) {
        errors.add(
            'Invalid field ${field.label}: ${field.validationError ?? "Failed validation"}');
      }
    }

    // 3. Candidate-level errors
    errors.addAll(candidate.errors);

    // 4. Non-blocking warnings
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

  /// Converts a validated [candidate] into a concrete DomainEntity.
  DomainConversionResult convert(IngestionCandidate candidate) {
    final validation = validate(candidate);
    if (!validation.isValid) {
      return DomainConversionResult.failure(validation.blockingErrors);
    }

    switch (candidate.targetTypeKey.toLowerCase()) {
      case 'monster':
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

      final name = fields['name']?.value?.toString().trim() ?? 'Unnamed Monster';
      final size = fields['size']?.value?.toString().trim() ?? 'Medium';
      final type = fields['monsterType']?.value?.toString().trim() ?? 'Humanoid';
      final alignment = fields['alignment']?.value?.toString().trim() ?? 'unaligned';

      final acVal = fields['armorClass']?.value;
      final armorClass = acVal is int
          ? acVal
          : int.tryParse(acVal?.toString().trim() ?? '') ?? 10;

      final hpVal = fields['hitPoints']?.value;
      final hitPoints = hpVal is int
          ? hpVal
          : int.tryParse(hpVal?.toString().trim() ?? '') ?? 10;

      final hitDieFormula =
          fields['hitDieFormula']?.value?.toString().trim() ?? '';
      final challengeRating =
          fields['challengeRating']?.value?.toString().trim() ?? '1';
      final actionsMarkdown =
          fields['actionsMarkdown']?.value?.toString().trim() ?? '';

      final customProps = <String, dynamic>{
        'sourceText': candidate.rawSource,
      };

      if (fields['speed']?.value != null) {
        customProps['speed'] = fields['speed']!.value.toString();
      }
      if (fields['traitsMarkdown']?.value != null) {
        customProps['traitsMarkdown'] =
            fields['traitsMarkdown']!.value.toString();
      }
      if (fields['reactionsMarkdown']?.value != null) {
        customProps['reactionsMarkdown'] =
            fields['reactionsMarkdown']!.value.toString();
      }
      if (fields['legendaryActionsMarkdown']?.value != null) {
        customProps['legendaryActionsMarkdown'] =
            fields['legendaryActionsMarkdown']!.value.toString();
      }

      // Abilities
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
          ruleset: RulesetVersion.v2024,
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
      return DomainConversionResult.failure(['Failed to construct Monster: $e']);
    }
  }

  DomainConversionResult _convertSpell(IngestionCandidate candidate) {
    try {
      final fields = candidate.fields;

      final name = fields['name']?.value?.toString().trim() ?? 'Unnamed Spell';
      final lvlVal = fields['level']?.value;
      final level = lvlVal is int
          ? lvlVal
          : int.tryParse(lvlVal?.toString().trim() ?? '') ?? 0;

      final school = fields['school']?.value?.toString().trim() ?? 'Evocation';
      final ctRaw = fields['castingTime']?.value?.toString().trim() ?? '1 action';
      final range = fields['range']?.value?.toString().trim() ?? 'Self';
      final compRaw = fields['components']?.value?.toString().trim() ?? 'V, S';
      final durRaw =
          fields['duration']?.value?.toString().trim() ?? 'Instantaneous';
      final desc =
          fields['descriptionMarkdown']?.value?.toString().trim() ?? '';
      final higher = fields['higherLevelsMarkdown']?.value?.toString().trim();

      // Parse casting time
      ActionType actionType = ActionType.action;
      final lowerCt = ctRaw.toLowerCase();
      if (lowerCt.contains('bonus')) {
        actionType = ActionType.bonusAction;
      } else if (lowerCt.contains('reaction')) {
        actionType = ActionType.reaction;
      } else if (lowerCt.contains('minute')) {
        actionType = ActionType.minute;
      } else if (lowerCt.contains('hour')) {
        actionType = ActionType.hour;
      }

      final castingTime = CastingTime(
        cost: 1,
        actionType: actionType,
        triggerCondition: lowerCt.contains('which you take') ? ctRaw : null,
      );

      // Parse duration
      final lowerDur = durRaw.toLowerCase();
      DurationType durType = DurationType.instantaneous;
      if (lowerDur.contains('round') ||
          lowerDur.contains('minute') ||
          lowerDur.contains('hour') ||
          lowerDur.contains('day')) {
        durType = DurationType.timed;
      } else if (lowerDur.contains('until dispelled') ||
          lowerDur.contains('permanent')) {
        durType = DurationType.permanent;
      } else if (lowerDur.contains('special')) {
        durType = DurationType.special;
      }

      final duration = SpellDuration(
        type: durType,
        requiresConcentration: lowerDur.contains('concentration'),
        rawText: durRaw,
      );

      // Parse components
      final lowerComp = compRaw.toUpperCase();
      final hasV = lowerComp.contains('V');
      final hasS = lowerComp.contains('S');
      final hasM = lowerComp.contains('M');
      String? materialDesc;
      final matMatch = RegExp(r'\(([^)]+)\)').firstMatch(compRaw);
      if (matMatch != null) {
        materialDesc = matMatch.group(1)!.trim();
      }

      final components = SpellComponents(
        v: hasV,
        s: hasS,
        m: hasM,
        materialDescription: materialDesc,
      );

      final spell = Spell(
        id: EntityId(
          slug: _slugify(name),
          ruleset: RulesetVersion.v2024,
        ),
        name: name,
        level: level,
        school: school,
        castingTime: castingTime,
        duration: duration,
        range: range,
        components: components,
        descriptionMarkdown: desc,
        higherLevelsMarkdown: higher,
        customProperties: {
          'sourceText': candidate.rawSource,
        },
      );

      return DomainConversionResult.success(spell);
    } catch (e) {
      return DomainConversionResult.failure(['Failed to construct Spell: $e']);
    }
  }

  static String _slugify(String name) {
    final clean = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return clean.isEmpty ? 'unnamed-entity' : clean;
  }
}
