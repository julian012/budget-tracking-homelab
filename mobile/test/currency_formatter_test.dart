import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/currency_formatter.dart';

void main() {
  group('formatCurrency', () {
    // NumberFormat.currency usa el locale por defecto (en tests, en_US) — se
    // fija el formato real observado; el símbolo \$ es el custom del formatter.
    test('formatea con símbolo de pesos y dos decimales', () {
      expect(formatCurrency(1500000), r'$1,500,000.00');
    });

    test('cero se formatea con decimales', () {
      expect(formatCurrency(0), r'$0.00');
    });

    test('valores negativos conservan el signo', () {
      expect(formatCurrency(-1234.5), r'-$1,234.50');
    });
  });

  group('ThousandsFormatter', () {
    late ThousandsFormatter formatter;

    setUp(() => formatter = ThousandsFormatter());

    TextEditingValue type(String text) => TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );

    test('agrega separador de miles', () {
      final result = formatter.formatEditUpdate(type(''), type('1500'));
      expect(result.text, '1.500');
    });

    test('descarta caracteres no numéricos', () {
      final result = formatter.formatEditUpdate(type(''), type('1a2b3'));
      expect(result.text, '123');
    });

    test('texto vacío devuelve string vacío', () {
      final result = formatter.formatEditUpdate(type('1.000'), type(''));
      expect(result.text, '');
    });

    test('solo símbolos devuelve string vacío', () {
      final result = formatter.formatEditUpdate(type(''), type('.-,'));
      expect(result.text, '');
    });

    test('mantiene el cursor al final del texto formateado', () {
      final result = formatter.formatEditUpdate(type(''), type('9999'));
      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
