import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/split_expenses.dart';

void main() {
  group('subExpensesTotal', () {
    test('suma los montos', () {
      expect(subExpensesTotal([41500, 8500]), 50000);
      expect(subExpensesTotal([]), 0);
    });
  });

  group('principalAmount', () {
    test('resta los sub-gastos del total', () {
      expect(principalAmount(50000, 41500), 8500);
    });

    test('nunca es negativo', () {
      expect(principalAmount(50000, 60000), 0);
    });

    test('devuelve el total si no hay sub-gastos', () {
      expect(principalAmount(50000, 0), 50000);
    });
  });

  group('buildSplitExpenseBodies', () {
    test('construye principal + sub-gastos heredando fecha/tarjeta/descripción', () {
      final bodies = buildSplitExpenseBodies(
        principal: 8500,
        principalCategoryId: 'cat-main',
        subs: const [(categoryId: 'cat-a', amount: 41500), (categoryId: 'cat-b', amount: 8500)],
        description: 'Mercado',
        cardId: 'card-1',
        date: '2026-08-18',
        source: 'form',
      );

      expect(bodies.length, 3);
      expect(bodies[0], {
        'amount': 8500, 'description': 'Mercado', 'category_id': 'cat-main',
        'card_id': 'card-1', 'expense_date': '2026-08-18', 'source': 'form',
        'transaction_group_id': null,
      });
      expect(bodies[1]['category_id'], 'cat-a');
      expect(bodies[2]['amount'], 8500);
      expect(bodies[1]['card_id'], 'card-1');
      expect(bodies[1]['expense_date'], '2026-08-18');
      expect(bodies[1]['description'], 'Mercado');
    });

    test('asigna el mismo transaction_group_id a todos los gastos', () {
      final bodies = buildSplitExpenseBodies(
        principal: 8500,
        principalCategoryId: 'cat-main',
        subs: const [(categoryId: 'cat-a', amount: 41500), (categoryId: 'cat-b', amount: 8500)],
        description: 'Mercado',
        cardId: null,
        date: '2026-08-18',
        source: 'form',
        transactionGroupId: 'uuid-grupo-1',
      );

      expect(bodies.length, 3);
      for (final b in bodies) {
        expect(b['transaction_group_id'], 'uuid-grupo-1');
      }
    });

    test('omite el gasto principal si el monto es 0 o no hay categoría', () {
      final bodies = buildSplitExpenseBodies(
        principal: 0,
        principalCategoryId: 'cat-main',
        subs: const [(categoryId: 'cat-a', amount: 50000)],
        description: 'Gasto',
        cardId: null,
        date: '2026-08-18',
        source: 'form',
      );

      expect(bodies.length, 1);
      expect(bodies.first['category_id'], 'cat-a');
    });

    test('omite sub-gastos con monto <= 0', () {
      final bodies = buildSplitExpenseBodies(
        principal: 1000,
        principalCategoryId: 'cat-main',
        subs: const [(categoryId: 'cat-a', amount: 0), (categoryId: 'cat-b', amount: -5), (categoryId: 'cat-c', amount: 2000)],
        description: 'Gasto',
        cardId: null,
        date: '2026-08-18',
        source: 'form',
      );

      expect(bodies.length, 2);
      expect(bodies.any((b) => b['category_id'] == 'cat-a'), isFalse);
      expect(bodies.any((b) => b['category_id'] == 'cat-c'), isTrue);
    });

    test('devuelve lista vacía si no hay principal ni subs válidos', () {
      final bodies = buildSplitExpenseBodies(
        principal: 0,
        principalCategoryId: null,
        subs: const [(categoryId: 'cat-a', amount: 0)],
        description: 'Gasto',
        cardId: null,
        date: '2026-08-18',
        source: 'form',
      );

      expect(bodies, isEmpty);
    });
  });

  group('smartSortedSubCategories', () {
    test('pone primero las categorías con default_amount > 0 ordenadas desc', () {
      final categories = [
        {'id': 'a', 'name': 'A', 'default_amount': 0},
        {'id': 'b', 'name': 'B', 'default_amount': 8500},
        {'id': 'c', 'name': 'C', 'default_amount': 1500},
        {'id': 'd', 'name': 'D', 'default_amount': 0},
      ];

      final sorted = smartSortedSubCategories(categories);

      expect(sorted.map((c) => c['id']).toList(), ['b', 'c', 'a', 'd']);
    });

    test('excluye la categoría principal', () {
      final categories = [
        {'id': 'main', 'name': 'Main', 'default_amount': 10000},
        {'id': 'other', 'name': 'Other', 'default_amount': 5000},
      ];

      final sorted = smartSortedSubCategories(categories, excludeId: 'main');

      expect(sorted.length, 1);
      expect(sorted.first['id'], 'other');
    });
  });
}
