import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/utils/report_ranges.dart';

void main() {
  final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  void expectAllFullDates(ReportRange r) {
    for (final d in [r.start, r.end, r.prevStart, r.prevEnd]) {
      expect(d, matches(datePattern), reason: 'el backend ignora fechas que no sean yyyy-MM-dd');
    }
  }

  group('reportRange', () {
    final now = DateTime(2026, 9, 21);

    test('quarter: el período anterior termina un día antes de empezar el actual, con fecha completa (#104)', () {
      final r = reportRange(filter: 'quarter', now: now);
      // Antes prevEnd salía como "2026-06" (sin día) y el backend lo ignoraba →
      // el "anterior" incluía al actual y las tarjetas mostraban +0%.
      expect(r.start, '2026-06-01');
      expect(r.end, '2026-09-21');
      expect(r.prevEnd, '2026-05-31');
      expectAllFullDates(r);
      // Misma duración: 113 días (1 jun – 21 sep) → el anterior empieza 113 días antes.
      expect(r.prevStart, '2026-02-08');
    });

    test('el período anterior nunca se solapa con el actual', () {
      for (final f in ['quarter', 'month', 'week', 'custom']) {
        final r = reportRange(
          filter: f,
          now: now,
          customStart: DateTime(2026, 9, 1),
          customEnd: DateTime(2026, 9, 10),
        );
        expectAllFullDates(r);
        expect(r.prevEnd.compareTo(r.start), lessThan(0), reason: f);
        expect(r.prevStart.compareTo(r.prevEnd), lessThanOrEqualTo(0), reason: f);
      }
    });

    test('month: mes calendario contra mes calendario anterior', () {
      final r = reportRange(filter: 'month', now: now);
      expect(r, (start: '2026-09-01', end: '2026-09-21', prevStart: '2026-08-01', prevEnd: '2026-08-31'));
    });

    test('month en enero compara contra diciembre del año anterior', () {
      final r = reportRange(filter: 'month', now: DateTime(2026, 1, 15));
      expect(r.prevStart, '2025-12-01');
      expect(r.prevEnd, '2025-12-31');
    });

    test('week (por defecto): últimos 7 días y los 7 anteriores', () {
      final r = reportRange(filter: '7d', now: now);
      expect(r, (start: '2026-09-15', end: '2026-09-21', prevStart: '2026-09-08', prevEnd: '2026-09-14'));
    });

    test('custom: rango elegido y el anterior de igual duración', () {
      final r = reportRange(filter: 'custom', now: now, customStart: DateTime(2026, 9, 1), customEnd: DateTime(2026, 9, 10));
      expect(r, (start: '2026-09-01', end: '2026-09-10', prevStart: '2026-08-22', prevEnd: '2026-08-31'));
    });

    test('custom sin fechas cae al filtro por defecto', () {
      final r = reportRange(filter: 'custom', now: now);
      expect(r.start, '2026-09-15');
    });
  });

  group('trendGridInterval', () {
    test('da ~4 divisiones con un paso redondo', () {
      expect(trendGridInterval(8670000), 2500000);
      expect(trendGridInterval(1000000), 250000);
      expect(trendGridInterval(400000), 100000);
      expect(trendGridInterval(12000000), 5000000);
    });

    test('nunca genera más de ~5 líneas para valores en millones (antes ~40 con 200.000 fijo)', () {
      for (final maxY in [500000.0, 3000000.0, 8670000.0, 25000000.0]) {
        expect(maxY / trendGridInterval(maxY), lessThanOrEqualTo(5.0), reason: '$maxY');
      }
    });

    test('con maxY <= 0 devuelve un intervalo válido', () {
      expect(trendGridInterval(0), greaterThan(0));
    });
  });
}
