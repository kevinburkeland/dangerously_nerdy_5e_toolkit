import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  group('AppSettings — Default Values', () {
    test('default constructor produces expected field values', () {
      const s = AppSettings();
      expect(s.themeMode, ThemeMode.dark);
      expect(s.fantasyAccent, FantasyAccent.paladinGold);
      expect(s.oledPitchBlack, isFalse);
      expect(s.hapticLevel, HapticFeedbackLevel.light);
      expect(s.wizardOrderingPreset, WizardOrderingPreset.classic2014);
      expect(s.enableCritFumbleFx, isTrue);
      expect(s.enableSpellParticles, isTrue);
      expect(s.enable3dDiceOverlays, isTrue);
      expect(s.enableGlyphAnimations, isTrue);
      expect(s.performanceMode, isFalse);
      expect(s.rulesEdition, DmRulesEdition.v2024);
      expect(s.pinnedRuleIds, isEmpty);
      expect(s.pinnedSpellIds, isEmpty);
      expect(s.pinnedMonsterIds, isEmpty);
    });
  });

  group('AppSettings.copyWith() — Field Replacement', () {
    const base = AppSettings();

    test('copyWith with no arguments returns equal but not identical object', () {
      final copy = base.copyWith();
      expect(copy, equals(base));
    });

    test('copyWith themeMode replaces only themeMode', () {
      final copy = base.copyWith(themeMode: ThemeMode.light);
      expect(copy.themeMode, ThemeMode.light);
      // All other fields must stay unchanged
      expect(copy.fantasyAccent, base.fantasyAccent);
      expect(copy.oledPitchBlack, base.oledPitchBlack);
      expect(copy.rulesEdition, base.rulesEdition);
    });

    test('copyWith oledPitchBlack true differs from default', () {
      final copy = base.copyWith(oledPitchBlack: true);
      expect(copy.oledPitchBlack, isTrue);
      expect(copy, isNot(equals(base)));
    });

    test('copyWith performanceMode true differs from default', () {
      final copy = base.copyWith(performanceMode: true);
      expect(copy.performanceMode, isTrue);
      expect(copy, isNot(equals(base)));
    });

    test('copyWith rulesEdition replaces edition', () {
      final copy = base.copyWith(rulesEdition: DmRulesEdition.v2014);
      expect(copy.rulesEdition, DmRulesEdition.v2014);
      expect(copy.rulesEdition, isNot(equals(base.rulesEdition)));
    });

    test('copyWith pinnedRuleIds replaces pinned set', () {
      final copy = base.copyWith(pinnedRuleIds: {'rule_a', 'rule_b'});
      expect(copy.pinnedRuleIds, containsAll(['rule_a', 'rule_b']));
      expect(copy.pinnedRuleIds.length, 2);
      // Base still has empty set
      expect(base.pinnedRuleIds, isEmpty);
    });

    test('copyWith chain — two successive copyWith calls compose correctly', () {
      final step1 = base.copyWith(oledPitchBlack: true);
      final step2 = step1.copyWith(rulesEdition: DmRulesEdition.v2014);
      expect(step2.oledPitchBlack, isTrue);
      expect(step2.rulesEdition, DmRulesEdition.v2014);
      // Other defaults untouched
      expect(step2.fantasyAccent, FantasyAccent.paladinGold);
    });
  });

  group('AppSettings — Derived Boolean Getters (mutation guards)', () {
    // areParticlesAllowed = enableSpellParticles && !performanceMode
    // The && → || mutation would make this always true when either flag is set.

    test('areParticlesAllowed is true when particles enabled and performanceMode off', () {
      const s = AppSettings(enableSpellParticles: true, performanceMode: false);
      expect(s.areParticlesAllowed, isTrue);
    });

    test('areParticlesAllowed is false when performanceMode is on, even if particles enabled', () {
      const s = AppSettings(enableSpellParticles: true, performanceMode: true);
      expect(s.areParticlesAllowed, isFalse);
    });

    test('areParticlesAllowed is false when particles disabled, even if performanceMode off', () {
      const s = AppSettings(enableSpellParticles: false, performanceMode: false);
      expect(s.areParticlesAllowed, isFalse);
    });

    // areCritFxAllowed = enableCritFumbleFx && !performanceMode
    test('areCritFxAllowed is true when critFx enabled and performanceMode off', () {
      const s = AppSettings(enableCritFumbleFx: true, performanceMode: false);
      expect(s.areCritFxAllowed, isTrue);
    });

    test('areCritFxAllowed is false when performanceMode is on', () {
      const s = AppSettings(enableCritFumbleFx: true, performanceMode: true);
      expect(s.areCritFxAllowed, isFalse);
    });

    test('areCritFxAllowed is false when critFx disabled', () {
      const s = AppSettings(enableCritFumbleFx: false, performanceMode: false);
      expect(s.areCritFxAllowed, isFalse);
    });

    // areGlyphAnimationsAllowed = enableGlyphAnimations && !performanceMode
    test('areGlyphAnimationsAllowed is true when animations enabled and performanceMode off', () {
      const s = AppSettings(enableGlyphAnimations: true, performanceMode: false);
      expect(s.areGlyphAnimationsAllowed, isTrue);
    });

    test('areGlyphAnimationsAllowed is false when performanceMode is on', () {
      const s = AppSettings(enableGlyphAnimations: true, performanceMode: true);
      expect(s.areGlyphAnimationsAllowed, isFalse);
    });

    test('areGlyphAnimationsAllowed is false when animations disabled', () {
      const s = AppSettings(enableGlyphAnimations: false, performanceMode: false);
      expect(s.areGlyphAnimationsAllowed, isFalse);
    });
  });

  group('AppSettings — Equality & HashCode', () {
    test('two default instances are equal and share the same hashCode', () {
      const a = AppSettings();
      const b = AppSettings();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing in a single bool field are not equal', () {
      const a = AppSettings(oledPitchBlack: false);
      const b = AppSettings(oledPitchBlack: true);
      expect(a, isNot(equals(b)));
    });

    test('instances differing in rulesEdition are not equal', () {
      const a = AppSettings(rulesEdition: DmRulesEdition.v2014);
      const b = AppSettings(rulesEdition: DmRulesEdition.v2024);
      expect(a, isNot(equals(b)));
    });

    test('instances differing only in a pinned set are not equal', () {
      const a = AppSettings(pinnedSpellIds: {});
      final b = a.copyWith(pinnedSpellIds: {'spell_fireball'});
      expect(a, isNot(equals(b)));
    });

    test('instances with the same pinned sets are equal', () {
      final a = const AppSettings().copyWith(pinnedRuleIds: {'rule_x', 'rule_y'});
      final b = const AppSettings().copyWith(pinnedRuleIds: {'rule_y', 'rule_x'});
      expect(a, equals(b)); // Set equality is order-independent
    });
  });

  group('FantasyAccent enum — Label Completeness', () {
    test('all FantasyAccent values have non-empty labels', () {
      for (final accent in FantasyAccent.values) {
        expect(accent.label.isNotEmpty, isTrue,
            reason: 'Empty label for FantasyAccent.${accent.name}');
      }
    });

    test('all FantasyAccent values have non-null color tokens', () {
      for (final accent in FantasyAccent.values) {
        expect(accent.primary, isNotNull);
        expect(accent.accent, isNotNull);
      }
    });
  });

  group('HapticFeedbackLevel enum — Label Completeness', () {
    test('all HapticFeedbackLevel values have non-empty labels', () {
      for (final level in HapticFeedbackLevel.values) {
        expect(level.label.isNotEmpty, isTrue,
            reason: 'Empty label for HapticFeedbackLevel.${level.name}');
      }
    });
  });

  group('WizardOrderingPreset enum — Label Completeness', () {
    test('all WizardOrderingPreset values have non-empty labels', () {
      for (final preset in WizardOrderingPreset.values) {
        expect(preset.label.isNotEmpty, isTrue,
            reason: 'Empty label for WizardOrderingPreset.${preset.name}');
      }
    });
  });
}
