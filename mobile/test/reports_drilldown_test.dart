import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/reports_drilldown.dart';

void main() {
  group('aggregateDailyAmounts', () {
    test('suma montos por día', () {
      final start = DateTime(2026, 8, 15);
      final end = DateTime(2026, 8, 20);
      final transactions = [
        {'expense_date': '2026-08-15', 'amount': 5000},
        {'expense_date': '2026-08-15', 'amount': 3000},
        {'expense_date': '2026-08-17', 'amount': 10000},
      ];

      final result = aggregateDailyAmounts(transactions, start, end: end);

      expect(result[0], 8000); // día 15
      expect(result[2], 10000); // día 17
      expect(result[1], isNull); // día 16 sin datos
    });

    test('ignora días fuera del rango', () {
      final start = DateTime(2026, 8, 15);
      final end = DateTime(2026, 8, 17);
      final transactions = [
        {'expense_date': '2026-08-14', 'amount': 5000}, // antes
        {'expense_date': '2026-08-18', 'amount': 3000}, // después
      ];

      final result = aggregateDailyAmounts(transactions, start, end: end);

      expect(result, isEmpty);
    });

    test('maneja lista vacía', () {
      final result = aggregateDailyAmounts([], DateTime(2026, 8, 15), end: DateTime(2026, 8, 17));
      expect(result, isEmpty);
    });

    test('maneja fechas inválidas sin errores', () {
      final start = DateTime(2026, 8, 15);
      final end = DateTime(2026, 8, 17);
      final transactions = [
        {'expense_date': 'invalid-date', 'amount': 5000},
        {'expense_date': null, 'amount': 3000},
      ];

      final result = aggregateDailyAmounts(transactions, start, end: end);

      expect(result, isEmpty);
    });
  });

  group('sortByDateDesc', () {
    test('ordena por fecha descendente', () {
      final expenses = [
        {'expense_date': '2026-08-15', 'amount': 100},
        {'expense_date': '2026-08-20', 'amount': 300},
        {'expense_date': '2026-08-17', 'amount': 200},
      ];

      final sorted = sortByDateDesc(expenses);

      expect((sorted[0]['expense_date'] as String).split('T').first, '2026-08-20');
      expect((sorted[1]['expense_date'] as String).split('T').first, '2026-08-17');
      expect((sorted[2]['expense_date'] as String).split('T').first, '2026-08-15');
    });

    test('no muta la lista original', () {
      final expenses = [
        {'expense_date': '2026-08-15', 'amount': 100},
        {'expense_date': '2026-08-20', 'amount': 300},
      ];

      sortByDateDesc(expenses);

      expect((expenses[0]['expense_date'] as String).split('T').first, '2026-08-15');
    });
  });

  group('chartMaxY', () {
    test('agrega margen del 15%', () {
      expect(chartMaxY(100000), closeTo(115000, 1));
    });

    test('devuelve 1.0 si no hay datos', () {
      expect(chartMaxY(0), 1.0);
    });
  });

  group('chartYInterval', () {
    test('divide el máximo en segmentos', () {
      expect(chartYInterval(100000), 25000);
    });

    test('nunca devuelve 0', () {
      expect(chartYInterval(0), 1.0);
      expect(chartYInterval(3), 1.0);
    });
  });

  group('formatAxisAmount', () {
    test('formatea miles con k', () {
      expect(formatAxisAmount(250000), '250k');
      expect(formatAxisAmount(999), '999');
    });

    test('formatea millones con M', () {
      expect(formatAxisAmount(1200000), '1.2M');
      expect(formatAxisAmount(2000000), '2M');
    });
  });
}
