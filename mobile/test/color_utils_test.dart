import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/color_utils.dart';

void main() {
  group('parseHexColor', () {
    test('parsea #RRGGBB agregando alfa opaca', () {
      expect(parseHexColor('#EF4444'), const Color(0xFFEF4444));
    });

    test('acepta RRGGBB sin #', () {
      expect(parseHexColor('10B981'), const Color(0xFF10B981));
    });

    test('acepta AARRGGBB con alfa explícita', () {
      expect(parseHexColor('80EF4444'), const Color(0x80EF4444));
    });

    test('null y vacío devuelven el fallback', () {
      expect(parseHexColor(null), Colors.grey);
      expect(parseHexColor(''), Colors.grey);
    });

    test('fallback personalizable', () {
      expect(parseHexColor('', fallback: Colors.red.shade800), Colors.red.shade800);
    });

    test('hex malformado NO crashea (diferencia con las copias eliminadas en #53)', () {
      expect(parseHexColor('#ZZZZZZ'), Colors.grey);
      expect(parseHexColor('#12345'), Colors.grey);
      expect(parseHexColor('no-es-color'), Colors.grey);
    });
  });

  group('adaptColorForBrightness', () {
    test('ilumina colores casi-negros en modo oscuro', () {
      final original = Colors.black; // luminance 0
      final adapted = adaptColorForBrightness(original, Brightness.dark);
      expect(adapted.computeLuminance(), greaterThan(0.1));
      expect(adapted, isNot(equals(original)));
    });

    test('preserva colores visibles en modo oscuro', () {
      final color = Color(0xFFEF4444); // rojo brillante
      final adapted = adaptColorForBrightness(color, Brightness.dark);
      expect(adapted, equals(color));
    });

    test('oscurece colores casi-blancos en modo claro', () {
      final original = Colors.white; // luminance 1
      final adapted = adaptColorForBrightness(original, Brightness.light);
      expect(adapted.computeLuminance(), lessThan(0.9));
      expect(adapted, isNot(equals(original)));
    });

    test('preserva colores normales en modo claro', () {
      final color = Color(0xFF10B981);
      expect(adaptColorForBrightness(color, Brightness.light), equals(color));
    });

    test('no modifica colores oscuros en modo claro', () {
      final color = Colors.black;
      expect(adaptColorForBrightness(color, Brightness.light), equals(color));
    });
  });
}
