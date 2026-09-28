import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';

void main() {
  group('D&D 5e Extended Entities Ingestion Tests', () {
    const capability = Dnd5eIngestionCapability();
    final service = IngestionWorkbenchService(capability: capability);

    // ==========================================
    // 1. ITEM / EQUIPMENT
    // ==========================================
    group('Item / Equipment Ingestion', () {
      test('representative valid item is identified and converts to EquipmentItem', () {
        const source = '''
### Sunforged Blade
Weapon (longsword), rare (requires attunement by a paladin)

You gain a +1 bonus to attack and damage rolls made with this magic weapon.
When you hit a fiend or undead with it, that creature takes an extra 1d8 radiant damage.
''';
        final result = service.parse(source);
        expect(result.candidates.length, equals(1));
        final candidate = result.candidates.first;

        expect(candidate.targetTypeKey, equals('item'));
        expect(candidate.fields['name']?.value, equals('Sunforged Blade'));
        expect(candidate.fields['itemType']?.value, equals('Weapon (longsword)'));
        expect(candidate.fields['rarity']?.value, equals('Rare'));
        expect(candidate.fields['requiresAttunement']?.value, isTrue);

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect(conversion.entity, isA<EquipmentItem>());

        final item = conversion.entity as EquipmentItem;
        expect(item.name, equals('Sunforged Blade'));
        expect(item.itemType, equals('Weapon (longsword)'));
        expect(item.rarity, equals('Rare'));
        expect(item.requiresAttunement, isTrue);
        expect(item.descriptionMarkdown, contains('extra 1d8 radiant damage'));
      });

      test('missing item rarity or description fails conversion without fabricated defaults', () {
        const source = '''
### Mystery Ring
Wondrous Item
''';
        final result = service.parse(source);
        final candidate = result.candidates.first;

        final validation = service.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(validation.blockingErrors.any((e) => e.contains('Rarity')), isTrue);
        expect(validation.blockingErrors.any((e) => e.contains('Description')), isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isFalse);
      });

      test('user edits resolve missing item fields and enable conversion', () {
        const source = '''
### Ancient Relic
Wondrous Item
''';
        final result = service.parse(source);
        var candidate = result.candidates.first;

        candidate = service.updateCandidateField(candidate, 'rarity', 'Very Rare');
        candidate = service.updateCandidateField(
          candidate,
          'descriptionMarkdown',
          'A shimmering orb humming with ancient magical energy.',
        );

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        final item = conversion.entity as EquipmentItem;
        expect(item.rarity, equals('Very Rare'));
      });
    });

    // ==========================================
    // 2. FEAT
    // ==========================================
    group('Feat Ingestion', () {
      test('representative valid feat is identified and converts to Feat entity', () {
        const source = '''
### War Caster
General Feat
Prerequisite: The ability to cast at least one spell

You have practiced casting spells in the midst of combat, learning techniques that grant you the following benefits:
- You have advantage on Constitution saving throws that you make to maintain concentration on a spell when you take damage.
- You can perform the somatic components of spells even when you have weapons or a shield in one or both hands.
''';
        final result = service.parse(source);
        expect(result.candidates.length, equals(1));
        final candidate = result.candidates.first;

        expect(candidate.targetTypeKey, equals('feat'));
        expect(candidate.fields['name']?.value, equals('War Caster'));
        expect(candidate.fields['category']?.value, equals('General'));
        expect(candidate.fields['prerequisite']?.value,
            equals('The ability to cast at least one spell'));

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect(conversion.entity, isA<Feat>());

        final feat = conversion.entity as Feat;
        expect(feat.name, equals('War Caster'));
        expect(feat.category, equals('General'));
        expect(feat.prerequisite, contains('cast at least one spell'));
        expect(feat.descriptionMarkdown, contains('advantage on Constitution'));
      });

      test('missing feat description fails conversion without fabricated defaults', () {
        const source = '''
### Incomplete Feat
General Feat
Prerequisite: Dexterity 13
''';
        final result = service.parse(source);
        final candidate = result.candidates.first;

        final validation = service.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(validation.blockingErrors.any((e) => e.contains('Description')), isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isFalse);
      });
    });

    // ==========================================
    // 3. CLASS
    // ==========================================
    group('Class Ingestion', () {
      test('representative valid class is identified and converts to CharacterClass', () {
        const source = '''
### Warlord
Hit Die: 1d10
Primary Ability: Strength
Saving Throws: Constitution, Charisma
Armor Proficiencies: Light armor, medium armor, shields
Weapon Proficiencies: Simple weapons, martial weapons

### Core Traits
A battle-tested commander who orchestrates their allies with precision tactical acumen.
''';
        final result = service.parse(source);
        expect(result.candidates.length, equals(1));
        final candidate = result.candidates.first;

        expect(candidate.targetTypeKey, equals('class'));
        expect(candidate.fields['name']?.value, equals('Warlord'));
        expect(candidate.fields['hitDie']?.value, equals('d10'));
        expect(candidate.fields['savingThrows']?.value,
            containsAll(['Constitution', 'Charisma']));

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect(conversion.entity, isA<CharacterClass>());

        final cls = conversion.entity as CharacterClass;
        expect(cls.name, equals('Warlord'));
        expect(cls.hitDie, equals('d10'));
        expect(cls.savingThrows, containsAll(['Constitution', 'Charisma']));
        expect(cls.armorProficiencies, contains('shields'));
      });

      test('malformed hit die or missing saving throws fails conversion', () {
        const source = '''
### Custom Mage
Hit Die: 1d17
Primary Ability: Intelligence
''';
        final result = service.parse(source);
        final candidate = result.candidates.first;

        final validation = service.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(validation.blockingErrors.any((e) => e.contains('Hit Die')), isTrue);
        expect(validation.blockingErrors.any((e) => e.contains('Saving Throws')), isTrue);
      });
    });

    // ==========================================
    // 4. SUBCLASS
    // ==========================================
    group('Subclass Ingestion', () {
      test('representative valid subclass is identified and converts to Subclass', () {
        const source = '''
### Echo Knight
Fighter Archetype

A mysterious warrior who summons temporal echos to confuse and conquer foes.

### Manifest Echo
3rd-Level Echo Knight Feature
You can use a bonus action to magically manifest an echo of yourself in an unoccupied space.
''';
        final result = service.parse(source);
        expect(result.candidates.length, equals(1));
        final candidate = result.candidates.first;

        expect(candidate.targetTypeKey, equals('subclass'));
        expect(candidate.fields['name']?.value, equals('Echo Knight'));
        expect(candidate.fields['classSlug']?.value, equals('fighter'));

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect(conversion.entity, isA<Subclass>());

        final sub = conversion.entity as Subclass;
        expect(sub.name, equals('Echo Knight'));
        expect(sub.classSlug, equals('fighter'));
        expect(sub.featuresMarkdown, contains('Manifest Echo'));
      });

      test('subclass missing parent class fails validation until user selects it', () {
        const source = '''
### Shadow Dancer
A nimble performer blending shadow magic and acrobatics.

### Shadow Step
6th-Level Feature
You can step from one shadow into another.
''';
        // Force candidate type to subclass
        final result = service.parse(source);
        var candidate = result.candidates.first;
        candidate = service.changeCandidateType(candidate, 'subclass');

        // Missing parent class blocks commit!
        var validation = service.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(validation.blockingErrors.any((e) => e.contains('Parent Class')), isTrue);

        // User resolves parent class to rogue
        candidate = service.updateCandidateField(candidate, 'classSlug', 'rogue');
        validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect((conversion.entity as Subclass).classSlug, equals('rogue'));
      });
    });

    // ==========================================
    // 5. SPECIES / RACE
    // ==========================================
    group('Species / Race Ingestion', () {
      test('representative valid species is identified and converts to Race', () {
        const source = '''
### Aasimar
Creature Type: Humanoid
Size: Medium
Speed: 30 ft.

### Celestial Resistance
You have resistance to necrotic damage and radiant damage.

### Healing Hands
As an action, you can touch a creature and heal them.
''';
        final result = service.parse(source);
        expect(result.candidates.length, equals(1));
        final candidate = result.candidates.first;

        expect(candidate.targetTypeKey, equals('species'));
        expect(candidate.fields['name']?.value, equals('Aasimar'));
        expect(candidate.fields['size']?.value, equals('Medium'));
        expect(candidate.fields['speed']?.value, equals('30 ft.'));

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect(conversion.entity, isA<Race>());

        final race = conversion.entity as Race;
        expect(race.name, equals('Aasimar'));
        expect(race.size, equals('Medium'));
        expect(race.speed, equals('30 ft.'));
        expect(race.traitsMarkdown, contains('Celestial Resistance'));
      });

      test('missing speed or size fails conversion without fabricated defaults', () {
        const source = '''
### Mystery Folk
Creature Type: Humanoid

### Inherent Magic
You know one cantrip of your choice.
''';
        final result = service.parse(source);
        final candidate = result.candidates.first;

        final validation = service.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(validation.blockingErrors.any((e) => e.contains('Size')), isTrue);
        expect(validation.blockingErrors.any((e) => e.contains('Speed')), isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isFalse);
      });
    });

    // ==========================================
    // 6. BACKGROUND
    // ==========================================
    group('Background Ingestion', () {
      test('representative valid background is identified and converts to Background', () {
        const source = '''
### Sailor
Skill Proficiencies: Athletics, Perception
Tool Proficiencies: Navigator's tools, vehicles (water)
Equipment: Belaying pin, 50 feet of silk rope, 10 gp

### Ship's Passage
When you need to, you can secure free passage on a sailing ship.
''';
        final result = service.parse(source);
        expect(result.candidates.length, equals(1));
        final candidate = result.candidates.first;

        expect(candidate.targetTypeKey, equals('background'));
        expect(candidate.fields['name']?.value, equals('Sailor'));
        expect(candidate.fields['skillProficiencies']?.value,
            containsAll(['Athletics', 'Perception']));

        final validation = service.validate(candidate);
        expect(validation.isValid, isTrue);

        final conversion = service.convertToDomainEntity(candidate);
        expect(conversion.isSuccess, isTrue);
        expect(conversion.entity, isA<Background>());

        final bg = conversion.entity as Background;
        expect(bg.name, equals('Sailor'));
        expect(bg.skillProficiencies, containsAll(['Athletics', 'Perception']));
        expect(bg.toolProficiencies, contains("Navigator's tools"));
        expect(bg.descriptionMarkdown, contains("Ship's Passage"));
      });

      test('missing skill proficiencies fails conversion', () {
        const source = '''
### Hermit
Tool Proficiencies: Herbalism kit
''';
        final result = service.parse(source);
        final candidate = result.candidates.first;

        final validation = service.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(validation.blockingErrors.any((e) => e.contains('Skill Proficiencies')),
            isTrue);
      });
    });
  });
}
