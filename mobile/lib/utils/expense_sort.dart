List<dynamic> sortExpensesDesc(List<dynamic> list) {
  final sorted = List<dynamic>.from(list);
  sorted.sort((a, b) {
    final da = DateTime.tryParse((a['expense_date'] as String).split('T').first) ?? DateTime(2000);
    final db = DateTime.tryParse((b['expense_date'] as String).split('T').first) ?? DateTime(2000);
    final byDate = db.compareTo(da);
    if (byDate != 0) return byDate;
    final ca = DateTime.tryParse((a['created_at'] as String?) ?? '') ?? DateTime(2000);
    final cb = DateTime.tryParse((b['created_at'] as String?) ?? '') ?? DateTime(2000);
    return cb.compareTo(ca);
  });
  return sorted;
}
