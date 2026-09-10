import '../../services/logging_service.dart';
import '../dtos/animated_object_dto.dart';
import '../dtos/character_dto.dart';
import '../dtos/spell_dto.dart';

/// Anti-Corruption Layer (ACL) ingestor for external and homebrew JSON bundles.
///
/// Ensures fault-tolerant parsing where invalid or malformed entries are isolated
/// and logged without failing the ingestion of surviving valid entities.
class HomebrewIngestor {
  const HomebrewIngestor._();

  /// Ingests a raw list of homebrew spell JSON objects into validated [SpellDto] instances.
  ///
  /// Each item is parsed in an isolated try/catch block so that malformed entries
  /// do not abort processing of the remaining batch.
  static List<SpellDto> parseCustomSpells(List<dynamic> rawList) {
    final validSpells = <SpellDto>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = SpellDto.fromJson(map);
        if (dto.id.isNotEmpty && dto.name.isNotEmpty) {
          validSpells.add(dto);
        }
      } catch (e, st) {
        // Isolate the failure so the rest of the JSON bundle survives
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew spell ${map['name']}. Skipping.',
        );
      }
    }

    return validSpells;
  }

  /// Ingests a raw list of homebrew character JSON objects into validated [CharacterDto] instances.
  static List<CharacterDto> parseCustomCharacters(List<dynamic> rawList) {
    final validCharacters = <CharacterDto>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = CharacterDto.fromJson(map);
        if (dto.id.isNotEmpty && dto.name.isNotEmpty) {
          validCharacters.add(dto);
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew character ${map['name']}. Skipping.',
        );
      }
    }

    return validCharacters;
  }

  /// Ingests a raw list of animated object / minion JSON objects into validated [AnimatedObjectDto] instances.
  static List<AnimatedObjectDto> parseCustomAnimatedObjects(List<dynamic> rawList) {
    final validObjects = <AnimatedObjectDto>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = AnimatedObjectDto.fromMap(map);
        if (dto.id.isNotEmpty && dto.name.isNotEmpty) {
          validObjects.add(dto);
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew animated object ${map['name']}. Skipping.',
        );
      }
    }

    return validObjects;
  }
}
