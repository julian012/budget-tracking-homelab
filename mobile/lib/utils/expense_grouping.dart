List<List<dynamic>> groupConsecutiveExpenses(List<dynamic> items) {
  final blocks = <List<dynamic>>[];
  var i = 0;
  while (i < items.length) {
    final group = items[i]['transaction_group_id'] as String?;
    if (group == null) {
      blocks.add([items[i]]);
      i++;
      continue;
    }
    var j = i + 1;
    while (j < items.length && items[j]['transaction_group_id'] == group) {
      j++;
    }
    blocks.add(items.sublist(i, j));
    i = j;
  }
  return blocks;
}
