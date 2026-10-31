double subExpensesTotal(Iterable<double> amounts) =>
    amounts.fold(0.0, (sum, a) => sum + a);

double principalAmount(double total, double subTotal) =>
    (total - subTotal).clamp(0.0, total);

List<Map<String, dynamic>> buildSplitExpenseBodies({
  required double principal,
  required String? principalCategoryId,
  required List<({String categoryId, double amount})> subs,
  required String description,
  required String? cardId,
  required String date,
  required String source,
  String? transactionGroupId,
}) {
  final bodies = <Map<String, dynamic>>[];
  if (principal > 0 && principalCategoryId != null) {
    bodies.add({
      'amount': principal,
      'description': description,
      'category_id': principalCategoryId,
      'card_id': cardId,
      'expense_date': date,
      'source': source,
      'transaction_group_id': transactionGroupId,
    });
  }
  for (final s in subs) {
    if (s.amount <= 0) continue;
    bodies.add({
      'amount': s.amount,
      'description': description,
      'category_id': s.categoryId,
      'card_id': cardId,
      'expense_date': date,
      'source': source,
      'transaction_group_id': transactionGroupId,
    });
  }
  return bodies;
}

List<dynamic> smartSortedSubCategories(List<dynamic> categories, {String? excludeId}) {
  final withDefault = <dynamic>[];
  final withoutDefault = <dynamic>[];
  for (final c in categories) {
    if (c['id'] == excludeId) continue;
    final def = (c['default_amount'] as num?)?.toDouble() ?? 0;
    if (def > 0) {
      withDefault.add(c);
    } else {
      withoutDefault.add(c);
    }
  }
  withDefault.sort((a, b) =>
      ((b['default_amount'] as num?)?.toDouble() ?? 0).compareTo((a['default_amount'] as num?)?.toDouble() ?? 0));
  return [...withDefault, ...withoutDefault];
}
