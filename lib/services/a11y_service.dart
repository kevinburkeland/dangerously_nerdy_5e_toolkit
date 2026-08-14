import 'package:flutter/rendering.dart';
import '../models/dice_roll.dart';
import '../models/spell_session.dart';

/// Centralized accessibility announcement and assistive technology support service
class A11yService {
  /// Announce a generic message to assistive screen readers (TalkBack / VoiceOver)
  static void announce(String message, {TextDirection textDirection = TextDirection.ltr}) {
    if (message.trim().isEmpty) return;
    // ignore: deprecated_member_use
    SemanticsService.announce(message, textDirection);
  }

  /// Format and announce a real-time dice roll result
  static void announceRoll(DiceRollResult result) {
    final critPrefix = result.isCrit
        ? 'Critical Hit! Natural 20. '
        : (result.isFumble ? 'Critical Fumble! Natural 1. ' : '');

    final formula = result.formulaString;
    final total = result.total;

    final announcement = '$critPrefix Rolled $formula. Total: $total.';
    announce(announcement);
  }

  /// Announce minion or creature hit point modifications
  static void announceHpChange(
    String creatureName, {
    required int currentHp,
    required int maxHp,
    int? delta,
    int tempHp = 0,
    bool isDead = false,
  }) {
    if (isDead || currentHp <= 0) {
      announce('$creatureName has been destroyed!');
      return;
    }

    final deltaStr = delta != null && delta != 0
        ? (delta > 0 ? 'gained $delta HP. ' : 'lost ${delta.abs()} HP. ')
        : '';
    final tempStr = tempHp > 0 ? ', plus $tempHp temporary hit points' : '';

    final announcement = '$creatureName $deltaStr Current HP: $currentHp of $maxHp$tempStr.';
    announce(announcement);
  }

  /// Announce batch attack combat summary
  static void announceBatchAttack(BatchAttackSummary summary, int targetAc) {
    final hitCount = summary.totalHits;
    final totalAttacks = summary.totalAttacks;
    final totalDamage = summary.totalDamage;
    final crits = summary.totalCrits;

    final critStr = crits > 0 ? ' with $crits critical hit${crits > 1 ? "s" : ""}' : '';
    final announcement =
        'Batch attack against Armor Class $targetAc completed: $hitCount of $totalAttacks attacks hit$critStr, dealing $totalDamage total damage.';
    announce(announcement);
  }

  /// Announce a quick DM action or rules lookup
  static void announceAction(String message) {
    announce(message);
  }
}
