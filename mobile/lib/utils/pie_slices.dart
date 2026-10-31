const pieOtherLabel = 'Otros';

List<Map<String, dynamic>> consolidateTopSlices(List<dynamic> data, {int max = 5}) {
  final items = data
      .where((c) => ((c['total'] as num?)?.toDouble() ?? 0) > 0)
      .map((c) => Map<String, dynamic>.from(c as Map))
      .toList()
    ..sort((a, b) => ((b['total'] as num?)?.toDouble() ?? 0).compareTo((a['total'] as num?)?.toDouble() ?? 0));

  if (items.length <= max) return items;

  final top = items.take(max).toList();
  final rest = items.skip(max);
  final otherTotal = rest.fold<double>(0, (s, c) => s + ((c['total'] as num?)?.toDouble() ?? 0));
  top.add({
    'category_name': pieOtherLabel,
    'total': otherTotal,
    'is_other': true,
  });
  return top;
}
