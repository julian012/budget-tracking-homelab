import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Rango del período de Reportes y del período anterior con el que se compara.
/// Todas las fechas van como `yyyy-MM-dd`: el backend hace
/// `time.Parse("2006-01-02", ...)` e IGNORA en silencio cualquier otro formato
/// (p. ej. `2026-06`), dejando ese extremo sin límite.
typedef ReportRange = ({String start, String end, String prevStart, String prevEnd});

final _fmt = DateFormat('yyyy-MM-dd');

/// Calcula el rango de [filter] (`custom`, `month`, `quarter`; cualquier otro
/// valor = últimos 7 días). El período anterior es siempre contiguo y de la
/// misma duración que el actual (salvo `month`, que compara mes calendario con
/// mes calendario).
ReportRange reportRange({
  required String filter,
  required DateTime now,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = day(now);

  // Período [start, end] y anterior de igual duración inmediatamente antes.
  ReportRange sameLengthBefore(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    return (
      start: _fmt.format(start),
      end: _fmt.format(end),
      prevStart: _fmt.format(start.subtract(Duration(days: days))),
      prevEnd: _fmt.format(start.subtract(const Duration(days: 1))),
    );
  }

  if (filter == 'custom' && customStart != null && customEnd != null) {
    return sameLengthBefore(day(customStart), day(customEnd));
  }
  if (filter == 'month') {
    return (
      start: _fmt.format(DateTime(now.year, now.month, 1)),
      end: _fmt.format(today),
      prevStart: _fmt.format(DateTime(now.year, now.month - 1, 1)),
      prevEnd: _fmt.format(DateTime(now.year, now.month, 0)),
    );
  }
  if (filter == 'quarter') {
    final ago = today.subtract(const Duration(days: 90));
    return sameLengthBefore(DateTime(ago.year, ago.month, 1), today);
  }
  return sameLengthBefore(today.subtract(const Duration(days: 6)), today);
}

/// Intervalo de la grilla horizontal de «Tendencia mensual»: ~4 divisiones con
/// un paso «redondo» (1, 2, 2,5, 5 × 10^n). Con un intervalo fijo de 200.000 y
/// valores de millones había ~40 líneas y el gráfico era ilegible.
double trendGridInterval(double maxY) {
  if (maxY <= 0) return 1;
  final raw = maxY / 4;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalized = raw / magnitude;
  const steps = [1.0, 2.0, 2.5, 5.0, 10.0];
  final step = steps.firstWhere((s) => s >= normalized, orElse: () => 10.0);
  return step * magnitude;
}
