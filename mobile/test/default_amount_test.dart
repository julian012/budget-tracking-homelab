import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/default_amount.dart';

void main() {
  group('parseDefaultAmount', () {
    test('parsea texto con separadores de miles', () {
      expect(parseDefaultAmount('8.500'), 8500);
      expect(parseDefaultAmount('1.250.000'), 1250000);
    });

    test('parsea texto sin formato', () {
      expect(parseDefaultAmount('8500'), 8500);
    });

    test('devuelve null para texto vacío o solo símbolos', () {
      expect(parseDefaultAmount(''), isNull);
      expect(parseDefaultAmount(r'$ '), isNull);
    });
  });

  group('formatAmountInput', () {
    test('formatea con separador de miles', () {
      expect(formatAmountInput(8500), '8.500');
      expect(formatAmountInput(9000), '9.000');
    });

    test('devuelve string vacío para 0 o negativo', () {
      expect(formatAmountInput(0), '');
      expect(formatAmountInput(-5), '');
    });
  });

  group('shouldOfferDefaultUpdate', () {
    test('true si hay default > 0 y el monto difiere', () {
      expect(shouldOfferDefaultUpdate(currentDefault: 8500, amount: 9000), isTrue);
    });

    test('false si el monto es igual al default', () {
      expect(shouldOfferDefaultUpdate(currentDefault: 8500, amount: 8500), isFalse);
    });

    test('false si no hay default configurado', () {
      expect(shouldOfferDefaultUpdate(currentDefault: null, amount: 9000), isFalse);
      expect(shouldOfferDefaultUpdate(currentDefault: 0, amount: 9000), isFalse);
    });
  });
}
