import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/currency_formatter.dart';
import '../utils/default_amount.dart';
import '../utils/shared_split.dart';
import 'person_form_sheet.dart';

class SharedSplitSection extends StatefulWidget {
  final double totalAmount;
  final List<dynamic> people;
  final bool initiallyEnabled;
  final List<Map<String, dynamic>> initialShares;
  final ValueChanged<List<Map<String, dynamic>>> onSharesChanged;
  final VoidCallback? onCreatePerson;

  const SharedSplitSection({
    super.key,
    required this.totalAmount,
    required this.people,
    this.initiallyEnabled = false,
    this.initialShares = const [],
    required this.onSharesChanged,
    this.onCreatePerson,
  });

  @override
  State<SharedSplitSection> createState() => _SharedSplitSectionState();
}

class _ShareRow {
  final Map<String, dynamic> person;
  final TextEditingController amountCtrl;

  _ShareRow({required this.person, String amount = ''})
      : amountCtrl = TextEditingController(text: amount);

  void dispose() => amountCtrl.dispose();
}

class _SharedSplitSectionState extends State<SharedSplitSection> {
  bool _enabled = false;
  final Map<String, _ShareRow> _selected = {};

  @override
  void initState() {
    super.initState();
    _enabled = widget.initiallyEnabled;
    for (final s in widget.initialShares) {
      final person = widget.people.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['id']?.toString() == s['person_id']?.toString(),
            orElse: () => null,
          );
      if (person != null) {
        final amount = (s['amount'] as num?)?.toDouble() ?? 0;
        _selected[person['id'] as String] = _ShareRow(
          person: person,
          amount: formatAmountInput(amount),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final row in _selected.values) {
      row.dispose();
    }
    super.dispose();
  }

  void _notify() {
    final shares = _selected.entries
        .where((e) => (parseDefaultAmount(e.value.amountCtrl.text) ?? 0) > 0)
        .map((e) => buildShareBody(e.key, parseDefaultAmount(e.value.amountCtrl.text) ?? 0))
        .toList();
    widget.onSharesChanged(_enabled ? shares : []);
  }

  void _togglePerson(String id) {
    setState(() {
      if (_selected.containsKey(id)) {
        _selected[id]!.dispose();
        _selected.remove(id);
      } else {
        final person = widget.people.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p?['id']?.toString() == id,
              orElse: () => null,
            );
        if (person == null) return;
        _selected[id] = _ShareRow(person: person);
      }
      _distributeEqually();
    });
    _notify();
  }

  void _distributeEqually() {
    if (_selected.isEmpty || widget.totalAmount <= 0) return;
    final amounts = equalSelectedAmounts(widget.totalAmount, _selected.length);
    var i = 0;
    for (final row in _selected.values) {
      row.amountCtrl.text = formatAmountInput(amounts[i]);
      i++;
    }
  }

  void _onAmountChanged() {
    setState(() {});
    _notify();
  }

  double get _sumSelected {
    return _selected.values.fold<double>(0, (s, row) {
      return s + (parseDefaultAmount(row.amountCtrl.text) ?? 0);
    });
  }

  double get _userPart => userPart(widget.totalAmount, _selected.values.map((r) => parseDefaultAmount(r.amountCtrl.text) ?? 0).toList());

  String? get _error {
    if (_sumSelected > widget.totalAmount) return 'La suma supera el gasto total';
    if (_enabled && _selected.isEmpty) return 'Seleccioná al menos una persona';
    return null;
  }

  Future<void> _createPerson() async {
    final refresh = ValueNotifier<int>(0);
    final created = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => PersonFormSheet(refresh: refresh, showCloseButton: false),
    );
    if (created != null && created['id'] != null) {
      widget.onCreatePerson?.call();
      setState(() {
        _selected[created['id'] as String] = _ShareRow(person: created);
        _distributeEqually();
      });
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            if (!v) {
              widget.onSharesChanged([]);
            } else {
              _notify();
            }
          },
          title: const Text('Gasto compartido', style: TextStyle(fontWeight: FontWeight.w500)),
          secondary: const Icon(LucideIcons.users),
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.people.map<Widget>((p) {
              final id = p['id'] as String;
              final selected = _selected.containsKey(id);
              final color = parseHexColor(p['color']?.toString());
              return FilterChip(
                selected: selected,
                onSelected: (_) => _togglePerson(id),
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: color.withAlpha(40),
                  child: Text(p['icon']?.toString() ?? '👤', style: const TextStyle(fontSize: 12)),
                ),
                label: Text(p['name']?.toString() ?? ''),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _createPerson,
            icon: const Icon(LucideIcons.user_plus, size: 18),
            label: const Text('Nueva persona'),
          ),
          const SizedBox(height: 12),
          ..._selected.entries.map((e) {
            final row = e.value;
            final color = parseHexColor(row.person['color']?.toString());
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withAlpha(40),
                    child: Text(row.person['icon']?.toString() ?? '👤', style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.person['name']?.toString() ?? '', style: theme.textTheme.bodyMedium)),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: row.amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(prefixText: '\$', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      inputFormatters: [ThousandsFormatter()],
                      onChanged: (_) => _onAmountChanged(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => _togglePerson(e.key),
                  ),
                ],
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(BudgetTheme.borderRadiusMedium),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.user, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Tu parte', style: theme.textTheme.bodyMedium)),
                Text(formatCurrency(_userPart), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colorScheme.expense, fontSize: 13)),
          ],
        ],
      ],
    );
  }
}
