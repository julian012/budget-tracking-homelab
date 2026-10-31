List<Map<String, dynamic>> extractRecentCategories(List<dynamic> expenses, {int limit = 5}) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final e in expenses) {
    final cat = e['category'] as Map<String, dynamic>?;
    final id = cat?['id']?.toString();
    if (id == null || seen.contains(id)) continue;
    seen.add(id);
    result.add({
      'id': id,
      'name': cat?['name'] ?? '',
      'icon': cat?['icon'],
      'color': cat?['color'],
    });
    if (result.length >= limit) break;
  }
  return result;
}
