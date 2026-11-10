import 'package:flutter/material.dart';

import '../../models/magic_items/magic_item_data.dart';
import 'visual_ui.dart';

extension MagicItemVisualUiExtension on MagicItem {
  Color? get glyphColor => glyphArgb?.toColor();
  Color? get effectiveGlyphColor => effectiveGlyphArgb?.toColor();
}

extension CurrencyCoinTypeVisualUiExtension on CurrencyCoinType {
  Color get darkColor => darkArgb.toColor();
  Color get lightColor => lightArgb.toColor();
  Color getLegibleColor(bool isDarkMode) =>
      getLegibleArgb(isDarkMode).toColor();
}

Color getCurrencyColor(String priceText, bool isDarkMode) {
  return CurrencyCoinType.resolve(priceText).getLegibleColor(isDarkMode);
}

