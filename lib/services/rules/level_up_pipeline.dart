import '../../models/domain/character_models.dart';
import '../repository/reference_resolver.dart';
import 'character_progression_engine.dart';

export 'character_progression_engine.dart';

/// Backward-compatible wrapper delegating to [CharacterProgressionEngine].
class LevelUpPipeline {
  LevelUpPipeline._();

  static Map<String, List<Map<dynamic, int>>> getMulticlassPrerequisites() =>
      CharacterProgressionEngine.getMulticlassPrerequisites();

  static LevelUpValidationResult validateMulticlass(Character character, String targetClassSlug) =>
      CharacterProgressionEngine.validateMulticlass(character, targetClassSlug);

  static Character applyLevelUp(
    Character character,
    LevelUpRequest request, {
    ReferenceResolver? resolver,
  }) =>
      CharacterProgressionEngine.applyLevelUp(character, request, resolver: resolver);
}
