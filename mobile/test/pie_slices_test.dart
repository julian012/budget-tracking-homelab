import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/pie_slices.dart';

void main() {
  group('consolidateTopSlices', () {
    test('ordena desc y conserva hasta 5 ítems', () {
      final input = [
        for (var i = 1; i <= 5; i++) {'category_name': 'c$i', 'total': i * 10},
      ];
      final slices = consolidateTopSlices(input);

      expect(slices.length, 5);
      expect(slices.first['category_name'], 'c5');
      expect(slices.last['category_name'], 'c1');
      expect(slices.any((s) => s['is_other'] == true), isFalse);
    });

    test('agrupa el resto en "Otros" cuando hay más de 5', () {
      final input = [
        for (var i = 1; i <= 8; i++) {'category_name': 'c$i', 'total': i * 10},
      ];
      final slices = consolidateTopSlices(input);

      expect(slices.length, 6);
      expect(slices.first['category_name'], 'c8');
      expect(slices[5]['category_name'], 'Otros');
      expect(slices[5]['is_other'], true);
      expect(slices[5]['total'], 30 + 20 + 10); // c3+c2+c1
    });

    test('filtra totales <= 0 antes de consolidar', () {
      final input = [
        {'category_name': 'a', 'total': 0},
        {'category_name': 'b', 'total': 100},
        {'category_name': 'c', 'total': -5},
      ];
      final slices = consolidateTopSlices(input);

      expect(slices.length, 1);
      expect(slices.first['category_name'], 'b');
    });

    test('no muta la lista original', () {
      final input = [
        {'category_name': 'a', 'total': 100},
        {'category_name': 'b', 'total': 200},
      ];
      consolidateTopSlices(input);

      expect(input.first['category_name'], 'a');
    });
  });
}
