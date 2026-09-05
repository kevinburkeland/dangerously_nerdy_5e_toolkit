import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_proficiencies_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';

void main() {
  group('SrdProficienciesLibrary Tests', () {
    test('standardLanguages contains standard 5e languages', () {
      expect(SrdProficienciesLibrary.standardLanguages, contains('Common'));
      expect(SrdProficienciesLibrary.standardLanguages, contains('Elvish'));
      expect(SrdProficienciesLibrary.standardLanguages, contains('Dwarvish'));
      expect(SrdProficienciesLibrary.standardLanguages, contains('Halfling'));
    });

    test('exoticLanguages contains exotic 5e languages', () {
      expect(SrdProficienciesLibrary.exoticLanguages, contains('Draconic'));
      expect(SrdProficienciesLibrary.exoticLanguages, contains('Infernal'));
      expect(SrdProficienciesLibrary.exoticLanguages, contains('Abyssal'));
      expect(SrdProficienciesLibrary.exoticLanguages, contains('Celestial'));
    });

    test('secretLanguages contains Thieves\' Cant and Druidic', () {
      expect(SrdProficienciesLibrary.secretLanguages, contains("Thieves' Cant"));
      expect(SrdProficienciesLibrary.secretLanguages, contains('Druidic'));
    });

    test('getLanguageCategory categorizes correctly', () {
      expect(SrdProficienciesLibrary.getLanguageCategory('Common'), equals(LanguageCategory.standard));
      expect(SrdProficienciesLibrary.getLanguageCategory('Draconic'), equals(LanguageCategory.exotic));
      expect(SrdProficienciesLibrary.getLanguageCategory("Thieves' Cant"), equals(LanguageCategory.secret));
      expect(SrdProficienciesLibrary.getLanguageCategory('Custom Alien'), equals(LanguageCategory.standard));
    });

    test('allTools contains all tool categories', () {
      expect(SrdProficienciesLibrary.allTools, contains("Thieves' Tools"));
      expect(SrdProficienciesLibrary.allTools, contains("Smith's Tools"));
      expect(SrdProficienciesLibrary.allTools, contains('Lute'));
      expect(SrdProficienciesLibrary.allTools, contains('Dice Set'));
      expect(SrdProficienciesLibrary.allTools, contains('Vehicles (Land)'));
    });

    test('getToolCategory categorizes correctly', () {
      expect(SrdProficienciesLibrary.getToolCategory("Smith's Tools"), equals(ToolCategory.artisansTools));
      expect(SrdProficienciesLibrary.getToolCategory('Lute'), equals(ToolCategory.musicalInstruments));
      expect(SrdProficienciesLibrary.getToolCategory('Dice Set'), equals(ToolCategory.gamingSets));
      expect(SrdProficienciesLibrary.getToolCategory('Vehicles (Water)'), equals(ToolCategory.vehicles));
      expect(SrdProficienciesLibrary.getToolCategory("Thieves' Tools"), equals(ToolCategory.kits));
    });

    test('getRecommendedAbility provides sensible 5e defaults', () {
      expect(SrdProficienciesLibrary.getRecommendedAbility("Thieves' Tools"), equals(AbilityType.dexterity));
      expect(SrdProficienciesLibrary.getRecommendedAbility("Herbalism Kit"), equals(AbilityType.wisdom));
      expect(SrdProficienciesLibrary.getRecommendedAbility("Disguise Kit"), equals(AbilityType.charisma));
      expect(SrdProficienciesLibrary.getRecommendedAbility("Alchemist's Supplies"), equals(AbilityType.intelligence));
      expect(SrdProficienciesLibrary.getRecommendedAbility("Smith's Tools"), equals(AbilityType.strength));
      expect(SrdProficienciesLibrary.getRecommendedAbility("Lute"), equals(AbilityType.charisma));
    });
  });
}
