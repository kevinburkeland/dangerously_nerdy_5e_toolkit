import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/party/party_purse.dart';
import '../../services/logging_service.dart';
import '../../services/rules/character_factory.dart';

/// Persistence service for saving, loading, and deleting characters in local storage.
class CharacterPersistenceService {
  static const String _kSavedRosterKey = 'saved_characters_roster_v1';
  static const String _kActiveCharacterIdKey = 'saved_active_character_id_v1';

  static final CharacterPersistenceService _instance =
      CharacterPersistenceService._internal();
  factory CharacterPersistenceService() => _instance;
  CharacterPersistenceService._internal();

  /// Generates the default starter roster of sample heroes.
  static List<Character> getDefaultStarterRoster() {
    final valeros = CharacterFactory.createLevel1Character(
      const CharacterCreationRequest(
        characterName: 'Valeros Ironclad',
        ruleset: RulesetVersion.v2024,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'soldier',
          displayName: 'Soldier',
        ),
        startingClassSlug: 'fighter',
        startingClassDisplayName: 'Fighter',
        startingClassHitDie: 'd10',
        baseScores: AbilityScores.standardArray(),
        bonusScores: AbilityScores(strength: 2, constitution: 1),
        savingThrowProficiencies: {
          AbilityType.strength,
          AbilityType.constitution,
        },
        skillProficiencies: {
          SkillType.athletics: SkillProficiencyLevel.proficient,
          SkillType.intimidation: SkillProficiencyLevel.proficient,
          SkillType.perception: SkillProficiencyLevel.proficient,
        },
        originFeats: [
          EntityReference(
            refType: EntityType.feat,
            slug: 'savage-attacker',
            displayName: 'Savage Attacker',
          ),
        ],
        startingEquipment: [
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'chain-mail',
              displayName: 'Chain Mail',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.armor,
          ),
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'longsword',
              displayName: 'Longsword',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.mainHand,
          ),
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.shield,
          ),
        ],
        startingPurse: PartyPurse(gp: 25, sp: 40),
      ),
    );

    final eldrin = CharacterFactory.createLevel1Character(
      const CharacterCreationRequest(
        characterName: 'Eldrin Shadowbane',
        ruleset: RulesetVersion.v2024,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'criminal',
          displayName: 'Criminal',
        ),
        startingClassSlug: 'rogue',
        startingClassDisplayName: 'Rogue',
        startingClassHitDie: 'd8',
        baseScores: AbilityScores(
          strength: 8,
          dexterity: 15,
          constitution: 14,
          intelligence: 13,
          wisdom: 12,
          charisma: 10,
        ),
        bonusScores: AbilityScores(dexterity: 2, intelligence: 1),
        savingThrowProficiencies: {
          AbilityType.dexterity,
          AbilityType.intelligence,
        },
        skillProficiencies: {
          SkillType.stealth: SkillProficiencyLevel.expertise,
          SkillType.sleightOfHand: SkillProficiencyLevel.proficient,
          SkillType.acrobatics: SkillProficiencyLevel.proficient,
          SkillType.perception: SkillProficiencyLevel.proficient,
        },
        originFeats: [
          EntityReference(
            refType: EntityType.feat,
            slug: 'alert',
            displayName: 'Alert',
          ),
        ],
        startingEquipment: [
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'leather-armor',
              displayName: 'Leather Armor',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.armor,
          ),
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'shortsword',
              displayName: 'Shortsword',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.mainHand,
          ),
        ],
        startingPurse: PartyPurse(gp: 45, sp: 20),
      ),
    );

    final lyra = CharacterFactory.createLevel1Character(
      const CharacterCreationRequest(
        characterName: 'Lyra Sunseeker',
        ruleset: RulesetVersion.v2024,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        startingClassSlug: 'cleric',
        startingClassDisplayName: 'Cleric',
        startingClassHitDie: 'd8',
        baseScores: AbilityScores(
          strength: 14,
          dexterity: 10,
          constitution: 14,
          intelligence: 10,
          wisdom: 15,
          charisma: 11,
        ),
        bonusScores: AbilityScores(wisdom: 2, constitution: 1),
        savingThrowProficiencies: {
          AbilityType.wisdom,
          AbilityType.charisma,
        },
        skillProficiencies: {
          SkillType.insight: SkillProficiencyLevel.proficient,
          SkillType.religion: SkillProficiencyLevel.proficient,
          SkillType.medicine: SkillProficiencyLevel.proficient,
        },
        originFeats: [
          EntityReference(
            refType: EntityType.feat,
            slug: 'magic-initiate',
            displayName: 'Magic Initiate',
          ),
        ],
        startingEquipment: [
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'breastplate',
              displayName: 'Breastplate',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.armor,
          ),
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            equipImmediately: true,
            defaultSlot: EquipmentSlot.shield,
          ),
        ],
        startingPurse: PartyPurse(gp: 60, sp: 10),
      ),
    );

    return [valeros, eldrin, lyra];
  }

  /// Loads all saved characters from SharedPreferences. If empty, returns default starter roster.
  Future<List<Character>> loadCharacters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rosterJson = prefs.getString(_kSavedRosterKey);
      if (rosterJson != null && rosterJson.isNotEmpty) {
        final decoded = json.decode(rosterJson) as List<dynamic>;
        final list = decoded
            .map((item) => Character.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      LoggingService().logWarning(
        'Failed to load characters from persistence: $e',
        e,
      );
    }
    return getDefaultStarterRoster();
  }

  /// Saves the complete character roster to SharedPreferences.
  Future<void> saveRoster(List<Character> roster) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(roster.map((c) => c.toMap()).toList());
      await prefs.setString(_kSavedRosterKey, encoded);
    } catch (e) {
      LoggingService().logWarning(
        'Failed to save characters roster to persistence: $e',
        e,
      );
    }
  }

  /// Saves or updates a single character in the roster.
  Future<List<Character>> saveCharacter(Character character) async {
    final roster = await loadCharacters();
    final index = roster.indexWhere((c) => c.id.slug == character.id.slug);
    if (index >= 0) {
      roster[index] = character;
    } else {
      roster.add(character);
    }
    await saveRoster(roster);
    return roster;
  }

  /// Deletes a character by slug from the roster.
  Future<List<Character>> deleteCharacter(String characterSlug) async {
    final roster = await loadCharacters();
    roster.removeWhere((c) => c.id.slug == characterSlug);
    await saveRoster(roster);
    return roster;
  }

  /// Loads the active character ID.
  Future<String?> loadActiveCharacterId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kActiveCharacterIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Saves the active character ID.
  Future<void> saveActiveCharacterId(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveCharacterIdKey, slug);
    } catch (e) {
      // Non-fatal
    }
  }
}
