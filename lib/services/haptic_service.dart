import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';

/// Centralized haptic dispatcher respecting the user's configured HapticFeedbackLevel
class HapticService {
  static HapticFeedbackLevel _getLevel(BuildContext context) {
    return SettingsScope.maybeOf(context)?.settings.hapticLevel ?? HapticFeedbackLevel.light;
  }

  /// Fast 10ms tactile tick for button taps, chip selections, and segmented switches
  static void selectionTick(BuildContext context) {
    final level = _getLevel(context);
    if (level == HapticFeedbackLevel.off) return;
    HapticFeedback.selectionClick();
  }

  /// Light impact for cards press-down and small micro-interactions
  static void lightImpact(BuildContext context) {
    final level = _getLevel(context);
    if (level == HapticFeedbackLevel.off) return;
    HapticFeedback.lightImpact();
  }

  /// Heavy impact for critical fumbles, taking damage, or severe state changes
  static void heavyImpact(BuildContext context) {
    final level = _getLevel(context);
    if (level == HapticFeedbackLevel.off) return;
    if (level == HapticFeedbackLevel.heavy) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Double-pulse rhythmic rumble for Natural 20 critical hits
  static void critRumble(BuildContext context) async {
    final level = _getLevel(context);
    if (level == HapticFeedbackLevel.off) return;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.mediumImpact();
  }
}
