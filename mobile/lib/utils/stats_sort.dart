List<dynamic> sortBreakdownByTotalDesc(List<dynamic> list) {
  final sorted = List<dynamic>.from(list);
  sorted.sort((a, b) {
    final ta = (a['total'] as num?)?.toDouble() ?? 0;
    final tb = (b['total'] as num?)?.toDouble() ?? 0;
    return tb.compareTo(ta);
  });
  return sorted;
}
