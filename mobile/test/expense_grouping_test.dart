import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/expense_grouping.dart';

void main() {
  group('groupConsecutiveExpenses', () {
    test('agrupa gastos consecutivos con el mismo transaction_group_id', () {
      final items = [
        {'id': 'e1', 'transaction_group_id': 'g1'},
        {'id': 'e2', 'transaction_group_id': 'g1'},
        {'id': 'e3', 'transaction_group_id': 'g1'},
      ];

      final blocks = groupConsecutiveExpenses(items);

      expect(blocks.length, 1);
      expect(blocks.first.length, 3);
    });

    test('separa singletons (sin grupo) y bloques distintos', () {
      final items = [
        {'id': 'e1'}, // standalone
        {'id': 'e2', 'transaction_group_id': 'g1'},
        {'id': 'e3', 'transaction_group_id': 'g1'},
        {'id': 'e4', 'transaction_group_id': 'g2'},
        {'id': 'e5'}, // standalone
      ];

      final blocks = groupConsecutiveExpenses(items);

      expect(blocks.length, 4);
      expect(blocks[0].length, 1);
      expect(blocks[1].length, 2);
      expect(blocks[2].length, 1);
      expect(blocks[3].length, 1);
    });

    test('mismo id pero no consecutivo forma bloques separados', () {
      final items = [
        {'id': 'e1', 'transaction_group_id': 'g1'},
        {'id': 'e2'}, // standalone interrumpe
        {'id': 'e3', 'transaction_group_id': 'g1'},
      ];

      final blocks = groupConsecutiveExpenses(items);

      expect(blocks.length, 3);
      expect(blocks[0].length, 1);
      expect(blocks[1].length, 1);
      expect(blocks[2].length, 1);
    });

    test('devuelve lista vacía si no hay ítems', () {
      expect(groupConsecutiveExpenses([]), isEmpty);
    });
  });
}
