import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';

AbilityType? _parseAbility(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final lower = raw.toLowerCase().trim();
  for (final ab in AbilityType.values) {
    if (ab.name.toLowerCase() == lower || ab.shortName.toLowerCase() == lower) {
      return ab;
    }
  }
  return null;
}

int _highestSlotLevelFromPool(SpellSlotPool pool) {
  var maxLvl = 0;
  for (final entry in pool.maxSlots.entries) {
    if (entry.value > 0 && entry.key > maxLvl) {
      maxLvl = entry.key;
    }
  }
  if (pool.pactMagicMax > 0 && pool.pactMagicSlotLevel > maxLvl) {
    maxLvl = pool.pactMagicSlotLevel;
  }
  return maxLvl;
}

void main() {
  group('Fix 7.1 App Law: resolveClassSpellcasterProfile agrees with SrdClassesLibrary',
      () {
    test('every SRD class and third-caster in both editions across levels 1..20',
        () {
      var cases = 0;
      for (final ruleset in const [RulesetVersion.v2014, RulesetVersion.v2024]) {
        final edition = ruleset == RulesetVersion.v2024
            ? RulesetEdition.v2024
            : RulesetEdition.v2014;

        for (final cls in SrdClassesLibrary.baseClasses) {
          final libraryAbility = _parseAbility(cls.spellcastingAbility);
          for (var lvl = 1; lvl <= 20; lvl++) {
            cases++;
            final profile = resolveClassSpellcasterProfile(
              classSlug: cls.id.slug,
              classLevel: lvl,
              edition: edition,
            );
            final slotPool = CharacterProgressionEngine.computeSpellSlots(
              [
                ClassLevelProgression(
                  classRef: EntityReference<DomainEntity>.empty(
                    refType: EntityType.classDefinition,
                    slug: cls.id.slug,
                    displayName: cls.name,
                  ),
                  level: lvl,
                  hitDie: cls.hitDie,
                  isStartingClass: true,
                ),
              ],
              edition: edition,
            );
            final expectedMaxSlot = _highestSlotLevelFromPool(slotPool);
            final expectedIsCaster =
                libraryAbility != null && expectedMaxSlot > 0;

            expect(
              profile.isSpellcaster,
              equals(expectedIsCaster),
              reason:
                  '${edition.name} ${cls.id.slug} L$lvl isSpellcaster mismatch',
            );
            expect(
              profile.highestSpellLevel,
              equals(expectedMaxSlot),
              reason:
                  '${edition.name} ${cls.id.slug} L$lvl highestSpellLevel mismatch',
            );
            if (expectedIsCaster) {
              expect(
                profile.castingAbility,
                equals(libraryAbility),
                reason:
                    '${edition.name} ${cls.id.slug} L$lvl castingAbility mismatch',
              );
            } else {
              expect(profile.castingAbility, isNull);
            }
          }
        }

        // Third-caster subclasses: Eldritch Knight (Fighter) & Arcane Trickster (Rogue)
        for (final pair in const [
          ('fighter', 'eldritch_knight'),
          ('rogue', 'arcane_trickster'),
        ]) {
          final cls = SrdClassesLibrary.findBySlug(pair.$1, ruleset: ruleset)!;
          for (var lvl = 1; lvl <= 20; lvl++) {
            cases++;
            final profile = resolveClassSpellcasterProfile(
              classSlug: pair.$1,
              classLevel: lvl,
              subclassSlug: pair.$2,
              edition: edition,
            );
            final slotPool = CharacterProgressionEngine.computeSpellSlots(
              [
                ClassLevelProgression(
                  classRef: EntityReference<DomainEntity>.empty(
                    refType: EntityType.classDefinition,
                    slug: cls.id.slug,
                    displayName: cls.name,
                  ),
                  subclassRef: EntityReference<DomainEntity>.empty(
                    refType: EntityType.subclass,
                    slug: pair.$2,
                    displayName: pair.$2,
                  ),
                  level: lvl,
                  hitDie: cls.hitDie,
                  isStartingClass: true,
                ),
              ],
              edition: edition,
            );
            final expectedMaxSlot = _highestSlotLevelFromPool(slotPool);
            final expectedIsCaster = expectedMaxSlot > 0;

            expect(profile.isSpellcaster, equals(expectedIsCaster));
            expect(profile.highestSpellLevel, equals(expectedMaxSlot));
            if (expectedIsCaster) {
              expect(profile.castingAbility, equals(AbilityType.intelligence));
              expect(profile.spellList, equals(SpellClass.wizard));
            }
          }
        }
      }
      stdout.writeln(
          'Fix 7.1 App Law verified $cases SRD class/third-caster cases.');
    });
  });
}
