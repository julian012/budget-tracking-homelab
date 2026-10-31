Map<int, double> aggregateDailyAmounts(
  List<dynamic> transactions,
  DateTime start, {
  required DateTime end,
}) {
  final result = <int, double>{};
  for (final e in transactions) {
    final date = DateTime.tryParse((e['expense_date'] as String?)?.split('T').first ?? '');
    if (date == null) continue;
    final idx = date.difference(start).inDays;
    if (idx < 0 || idx > end.difference(start).inDays) continue;
    result[idx] = (result[idx] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
  }
  return result;
}

List<dynamic> sortByDateDesc(List<dynamic> expenses) {
  final sorted = List<dynamic>.from(expenses);
  sorted.sort((a, b) {
    final da = (a['expense_date'] as String?) ?? '';
    final db = (b['expense_date'] as String?) ?? '';
    return db.compareTo(da);
  });
  return sorted;
}

double chartMaxY(double maxAmount) => maxAmount > 0 ? maxAmount * 1.15 : 1.0;

double chartYInterval(double maxAmount, {int segments = 4}) {
  if (maxAmount <= 0) return 1.0;
  return (maxAmount / segments).ceilToDouble().clamp(1.0, double.infinity);
}

String formatAxisAmount(double value) {
  if (value >= 1000000) {
    final v = value / 1000000;
    return '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)}M';
  }
  if (value >= 1000) return '${(value / 1000).round()}k';
  return value.toInt().toString();
}
