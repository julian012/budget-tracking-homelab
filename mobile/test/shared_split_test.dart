import 'package:budget_tracking/utils/shared_split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('equalSelectedAmounts', () {
    test('divide total en dos partes iguales (usuario + 1 persona)', () {
      expect(equalSelectedAmounts(50000, 1), [25000]);
    });

    test('residuo queda para el usuario (usuario + 2 personas)', () {
      expect(equalSelectedAmounts(50000, 2), [16666, 16666]);
    });

    test('devuelve lista vacía para count cero', () {
      expect(equalSelectedAmounts(50000, 0), []);
    });
  });

  group('userPart', () {
    test('calcula la parte del usuario', () {
      expect(userPart(50000, [25000]), 25000);
      expect(userPart(50000, [16666, 16666]), 16668);
    });

    test('no devuelve negativo', () {
      expect(userPart(50000, [60000]), 0);
    });
  });

  group('validateSplit', () {
    test('acepta split válido', () {
      expect(validateSplit(50000, [25000]), isNull);
    });

    test('rechaza suma mayor al total', () {
      expect(validateSplit(50000, [30000, 30000]), isNotNull);
    });

    test('rechaza montos negativos o cero', () {
      expect(validateSplit(50000, [0]), isNotNull);
    });

    test('rechaza lista vacía', () {
      expect(validateSplit(50000, []), isNotNull);
    });
  });
}
