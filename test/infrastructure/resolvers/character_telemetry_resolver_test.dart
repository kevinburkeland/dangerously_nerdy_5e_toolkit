import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/resolvers/character_telemetry_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterTelemetryResolver', () {
    test('formatSlugToTitle converts kebab and snake case to clean Title Case', () {
      expect(CharacterTelemetryResolver.formatSlugToTitle('blood-hunter'), 'Blood Hunter');
      expect(CharacterTelemetryResolver.formatSlugToTitle('order_of_the_ghostslayer'), 'Order Of The Ghostslayer');
      expect(CharacterTelemetryResolver.formatSlugToTitle('homebrew-shadow-mage'), 'Homebrew Shadow Mage');
      expect(CharacterTelemetryResolver.formatSlugToTitle('champion'), 'Champion');
      expect(CharacterTelemetryResolver.formatSlugToTitle(''), 'Unknown');
    });

    test('resolves canonical SRD species, background, class, subclass, feats, and equipment', () async {
      final dto = CharacterTelemetryDto(
        id: 'canonical-hero',
        name: 'Valeros',
        speciesSlug: 'human',
        backgroundSlug: 'acolyte',
        classPointers: const [
          ClassLevelPointerDto(classSlug: 'fighter', subclassSlug: 'champion', level: 5),
        ],
        currentHp: 45,
        maxHp: 50,
        tempHp: 5,
        armorClass: 18,
        speed: 30,
        level: 5,
        passivePerception: 12,
        featSlugs: const ['grappler'],
        equippedItemSlugs: const ['longsword', 'plate-armor'],
        conditions: const ['frightened'],
        spellSlots: const {'1': 2},
      );

      final resolved = await CharacterTelemetryResolver.resolve(dto);
      // print('UNRESOLVED: ${resolved.unresolvedSlugs}');
      expect(resolved.unresolvedSlugs, isEmpty, reason: 'Unresolved slugs: ${resolved.unresolvedSlugs}');
      expect(resolved.name, 'Valeros');
      expect(resolved.speciesName, 'Human');
      expect(resolved.backgroundName, 'Acolyte');
      expect(resolved.classes.length, 1);
      expect(resolved.classes.first.className, 'Fighter');
      expect(resolved.classes.first.subclassName, 'Champion');
      expect(resolved.classes.first.level, 5);
      expect(resolved.classes.first.displayName, 'Fighter (Champion) 5');
      expect(resolved.classSummary, 'Fighter (Champion) 5');
      expect(resolved.featNames, contains('Grappler'));
      expect(resolved.equippedItemNames, contains('Longsword'));
      expect(resolved.equippedItemNames.any((i) => i.contains('Plate Armor')), isTrue);
      expect(resolved.hasUnresolvedPointers, isFalse);
      expect(resolved.unresolvedSlugs, isEmpty);
    });

    test('gracefully falls back to title case with hasUnresolvedPointers for unknown slugs', () async {
      final dto = CharacterTelemetryDto(
        id: 'homebrew-hero',
        name: 'Kallista',
        speciesSlug: 'custom-alien-race',
        backgroundSlug: 'planar-refugee',
        classPointers: const [
          ClassLevelPointerDto(
            classSlug: 'blood-hunter',
            subclassSlug: 'order-of-the-mutant',
            level: 8,
          ),
        ],
        currentHp: 65,
        maxHp: 70,
        featSlugs: const ['void-touched-telepathy'],
        equippedItemSlugs: const ['blade-of-the-abyss'],
      );

      final resolved = await CharacterTelemetryResolver.resolve(dto);

      expect(resolved.speciesName, 'Custom Alien Race');
      expect(resolved.backgroundName, 'Planar Refugee');
      expect(resolved.classes.first.className, 'Blood Hunter');
      expect(resolved.classes.first.subclassName, 'Order Of The Mutant');
      expect(resolved.classSummary, 'Blood Hunter (Order Of The Mutant) 8');
      expect(resolved.featNames, ['Void Touched Telepathy']);
      expect(resolved.equippedItemNames, ['Blade Of The Abyss']);
      expect(resolved.hasUnresolvedPointers, isTrue);
      expect(resolved.unresolvedSlugs, contains('custom-alien-race'));
      expect(resolved.unresolvedSlugs, contains('planar-refugee'));
      expect(resolved.unresolvedSlugs, contains('blood-hunter'));
      expect(resolved.unresolvedSlugs, contains('order-of-the-mutant'));
      expect(resolved.unresolvedSlugs, contains('void-touched-telepathy'));
      expect(resolved.unresolvedSlugs, contains('blade-of-the-abyss'));
    });

    test('evaluates combat status getters (hpPercent, isConscious, isDying, isDead)', () {
      // 1. Healthy character
      const healthy = ResolvedCharacterDisplay(
        id: 'h1',
        name: 'Hero',
        speciesSlug: 'human',
        speciesName: 'Human',
        backgroundName: 'None',
        classSummary: 'Fighter 1',
        classes: [],
        currentHp: 25,
        maxHp: 50,
        tempHp: 0,
        armorClass: 16,
        speed: 30,
        totalLevel: 1,
        passivePerception: 10,
        exhaustionLevel: 0,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        conditions: [],
        spellSlots: {},
        featNames: [],
        equippedItemNames: [],
        hasUnresolvedPointers: false,
        unresolvedSlugs: [],
        rulesEdition: 'v2024',
        timestamp: 0,
      );
      expect(healthy.hpPercent, 0.5);
      expect(healthy.isConscious, isTrue);
      expect(healthy.isDying, isFalse);
      expect(healthy.isDead, isFalse);

      // 2. Dying character
      const dying = ResolvedCharacterDisplay(
        id: 'h2',
        name: 'Downed Hero',
        speciesSlug: 'human',
        speciesName: 'Human',
        backgroundName: 'None',
        classSummary: 'Fighter 1',
        classes: [],
        currentHp: 0,
        maxHp: 50,
        tempHp: 0,
        armorClass: 16,
        speed: 30,
        totalLevel: 1,
        passivePerception: 10,
        exhaustionLevel: 0,
        deathSaveSuccesses: 1,
        deathSaveFailures: 2,
        conditions: ['unconscious'],
        spellSlots: {},
        featNames: [],
        equippedItemNames: [],
        hasUnresolvedPointers: false,
        unresolvedSlugs: [],
        rulesEdition: 'v2024',
        timestamp: 0,
      );
      expect(dying.hpPercent, 0.0);
      expect(dying.isConscious, isFalse);
      expect(dying.isDying, isTrue);
      expect(dying.isDead, isFalse);

      // 3. Dead character (3 death save failures)
      const dead = ResolvedCharacterDisplay(
        id: 'h3',
        name: 'Fallen Hero',
        speciesSlug: 'human',
        speciesName: 'Human',
        backgroundName: 'None',
        classSummary: 'Fighter 1',
        classes: [],
        currentHp: 0,
        maxHp: 50,
        tempHp: 0,
        armorClass: 16,
        speed: 30,
        totalLevel: 1,
        passivePerception: 10,
        exhaustionLevel: 0,
        deathSaveSuccesses: 1,
        deathSaveFailures: 3,
        conditions: ['dead'],
        spellSlots: {},
        featNames: [],
        equippedItemNames: [],
        hasUnresolvedPointers: false,
        unresolvedSlugs: [],
        rulesEdition: 'v2024',
        timestamp: 0,
      );
      expect(dead.isConscious, isFalse);
      expect(dead.isDying, isFalse);
      expect(dead.isDead, isTrue);
    });

    test('resolves Breastplate to exact Breastplate entity without inheriting Plate Armor (Full Plate)', () async {
      final dto = CharacterTelemetryDto(
        id: 'skirmisher-hero',
        name: 'Ranger Dave',
        speciesSlug: 'human',
        classPointers: const [
          ClassLevelPointerDto(classSlug: 'ranger', level: 5),
        ],
        currentHp: 40,
        maxHp: 40,
        equippedItemSlugs: const ['breastplate'],
      );

      final resolved = await CharacterTelemetryResolver.resolve(dto);

      expect(resolved.equippedItemNames, contains('Breastplate'));
      expect(resolved.equippedItemNames.any((name) => name.contains('Full Plate') || name == 'Plate Armor'), isFalse);
      expect(resolved.unresolvedSlugs.contains('breastplate'), isFalse);
    });
  });
}
