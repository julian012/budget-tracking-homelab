import 'package:flutter/material.dart';

/// Parsea un color hex (`#RGB`/`RRGGBB`/`AARRGGBB`, con o sin `#`) en un solo
/// lugar. Reemplaza las 7 copias locales (`_hexColor`/`_parseColor`/
/// `_sharedParseColor`) que la auditoría #53 marcó como duplicación.
///
/// A diferencia de las copias originales (que crasheaban con `int.parse` ante
/// un hex malformado), devuelve [fallback] si el valor no es parseable.
Color parseHexColor(String? hex, {Color fallback = Colors.grey}) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  if (value == null || h.length != 8) return fallback;
  return Color(value);
}

Color adaptColorForBrightness(Color color, Brightness brightness) {
  final luminance = color.computeLuminance();
  if (brightness == Brightness.dark && luminance < 0.1) {
    return HSLColor.fromColor(color).withLightness(0.6).toColor();
  }
  if (brightness == Brightness.light && luminance > 0.9) {
    return HSLColor.fromColor(color).withLightness(0.4).toColor();
  }
  return color;
}

Color adaptCategoryColor(Color color, BuildContext context) {
  return adaptColorForBrightness(color, Theme.of(context).brightness);
}
