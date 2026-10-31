import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/stats_sort.dart';

void main() {
  test('sortBreakdownByTotalDesc ordena de mayor a menor por total', () {
    final input = [
      {'name': 'a', 'total': 100},
      {'name': 'b', 'total': 300},
      {'name': 'c', 'total': 200},
    ];

    final sorted = sortBreakdownByTotalDesc(input);

    expect(sorted.map((e) => e['name']).toList(), ['b', 'c', 'a']);
    expect(sorted.first['total'], 300);
    expect(sorted.last['total'], 100);
  });

  test('sortBreakdownByTotalDesc maneja total nulo como 0', () {
    final input = [
      {'name': 'a', 'total': null},
      {'name': 'b', 'total': 50},
      {'name': 'c', 'total': 0},
    ];

    final sorted = sortBreakdownByTotalDesc(input);

    expect(sorted.first['name'], 'b');
    final totals = sorted.map((e) => (e['total'] as num?)?.toDouble() ?? 0).toList();
    expect(totals, [50, 0, 0]);
  });

  test('sortBreakdownByTotalDesc no muta la lista original', () {
    final input = [
      {'name': 'a', 'total': 100},
      {'name': 'b', 'total': 300},
    ];

    sortBreakdownByTotalDesc(input);

    expect(input.map((e) => e['name']).toList(), ['a', 'b']);
  });

  test('take(5) tras ordenar limita a 5 elementos', () {
    final input = [
      for (var i = 1; i <= 8; i++) {'name': 'c$i', 'total': i * 10},
    ];

    final top = sortBreakdownByTotalDesc(input).take(5).toList();

    expect(top.length, 5);
    expect(top.first['name'], 'c8');
    expect(top.last['name'], 'c4');
  });
}
