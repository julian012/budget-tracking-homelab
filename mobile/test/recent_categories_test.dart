import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/recent_categories.dart';

void main() {
  group('extractRecentCategories', () {
    test('extrae categorías únicas de los gastos', () {
      final expenses = [
        {'category': {'id': 'c1', 'name': 'Comida', 'icon': 'food', 'color': '#FF0000'}},
        {'category': {'id': 'c2', 'name': 'Transporte', 'icon': 'bus', 'color': '#00FF00'}},
        {'category': {'id': 'c1', 'name': 'Comida', 'icon': 'food', 'color': '#FF0000'}},
      ];

      final result = extractRecentCategories(expenses);

      expect(result.length, 2);
      expect(result[0]['name'], 'Comida');
      expect(result[1]['name'], 'Transporte');
    });

    test('respeta el límite', () {
      final expenses = [
        for (var i = 1; i <= 10; i++)
          {'category': {'id': 'c$i', 'name': 'Cat $i'}},
      ];

      final result = extractRecentCategories(expenses, limit: 3);

      expect(result.length, 3);
      expect(result[0]['name'], 'Cat 1');
      expect(result[2]['name'], 'Cat 3');
    });

    test('maneja gastos sin categoría', () {
      final expenses = [
        {'category': null},
        {'amount': 100},
        {'category': {'id': 'c1', 'name': 'OK'}},
      ];

      final result = extractRecentCategories(expenses);

      expect(result.length, 1);
      expect(result[0]['name'], 'OK');
    });

    test('devuelve lista vacía si no hay gastos', () {
      expect(extractRecentCategories([]), isEmpty);
    });
  });
}
