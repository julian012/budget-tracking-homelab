import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/expense_grouping.dart';
import '../utils/expense_sort.dart';
import '../utils/icon_helper.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/filter_chips_bar.dart';

class ExpensesScreen extends StatefulWidget {
  final ValueNotifier<int> refresh;
  const ExpensesScreen({super.key, required this.refresh});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<dynamic> _expenses = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _monthFilter = 'all';
  int _displayCount = 20;
  bool _showScrollTop = false;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_loadData);
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.hasClients && _scrollCtrl.offset > 300;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 100) {
        setState(() => _displayCount = (_displayCount + 20).clamp(0, _filtered.length));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_loadData);
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) throw Exception('No autenticado');
      final data = await ApiService(url).getExpenses(token);
      if (mounted) {
        setState(() { _expenses = data; _loading = false; _displayCount = 20; });
        _applyFilters();
        context.read<OfflineQueueService>().markDataLoaded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudieron cargar los gastos'),
            action: SnackBarAction(label: 'Reintentar', onPressed: _loadData),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    var list = _expenses;
    if (_monthFilter == 'this') {
      final now = DateTime.now();
      list = list.where((e) {
        final date = DateTime.tryParse((e['expense_date'] as String).split('T').first);
        return date != null && date.month == now.month && date.year == now.year;
      }).toList();
    } else if (_monthFilter == 'last') {
      final last = DateTime.now().month - 1;
      final year = last < 1 ? DateTime.now().year - 1 : DateTime.now().year;
      list = list.where((e) {
        final date = DateTime.tryParse((e['expense_date'] as String).split('T').first);
        return date != null && date.month == (last < 1 ? 12 : last) && date.year == year;
      }).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((e) => (e['description'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())).toList();
    }
    list = sortExpensesDesc(list);
    setState(() { _filtered = list; _displayCount = 20; });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search = v;
      _applyFilters();
    });
  }

  Widget _buildTicketTile(dynamic e, {required bool isMain, required bool isGrouped}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final desc = e['description'] as String? ?? '';
    final date = e['expense_date'] as String? ?? '';
    final cat = e['category'] as Map<String, dynamic>?;
    final catName = cat?['name'] as String? ?? '';
    final catColor = adaptCategoryColor(parseHexColor(cat?['color']?.toString() ?? ''), context);
    final parsedDate = DateTime.tryParse(date.split('T').first);
    final fmtDate = parsedDate != null ? DateFormat('dd MMM', 'es').format(parsedDate).toUpperCase() : '';
    final shares = e['shares'] is List ? e['shares'] as List : <dynamic>[];
    final isShared = isMain && shares.isNotEmpty;
    return ListTile(
      dense: true,
      visualDensity: isGrouped ? const VisualDensity(vertical: -2) : null,
      contentPadding: EdgeInsets.only(left: isGrouped ? 12 : 0, right: 0),
      leading: CircleAvatar(radius: 16, backgroundColor: catColor.withAlpha(30), child: categoryIconWidget(cat?['icon']?.toString(), size: 16, color: catColor)),
      title: Text(isMain ? desc : catName, style: theme.textTheme.labelLarge),
      subtitle: isMain ? Text('$catName · $fmtDate', style: theme.textTheme.bodySmall) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isMain && e['card'] is Map && (e['card'] as Map)['franchise'] != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: franchiseIconWidget(
              (e['card'] as Map)['franchise'].toString(),
              size: 16,
              color: adaptCategoryColor(parseHexColor((e['card'] as Map)['color']?.toString() ?? ''), context),
            ),
          ),
        if (isShared)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: const Text('Compartido', style: TextStyle(fontSize: 10)),
              backgroundColor: colorScheme.primary.withAlpha(40),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        Text(_formatCurrency(amount), style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.expense)),
      ]),
      onTap: () => _showExpenseActions(e as Map<String, dynamic>),
    );
  }

  Future<void> _showExpenseActions(Map<String, dynamic> e) async {
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(LucideIcons.pencil),
            title: const Text('Modificar'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: Icon(LucideIcons.trash_2, color: colorScheme.expense),
            title: Text('Eliminar', style: TextStyle(color: colorScheme.expense)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
        ),
        builder: (_) => ExpenseFormSheet(existing: e, refresh: widget.refresh, onSaved: _loadData),
      );
    } else if (action == 'delete') {
      await _confirmDeleteExpense(e);
    }
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> e) async {
    final auth = context.read<AuthService>();
    final config = context.read<ServerConfig>();
    final colorScheme = Theme.of(context).colorScheme;
    final desc = (e['description'] as String? ?? 'Gasto').length > 30 ? '${(e['description'] as String? ?? 'Gasto').substring(0, 27)}...' : (e['description'] as String? ?? 'Gasto');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '¿Seguro que deseas eliminar "$desc"?',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colorScheme.expense),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ELIMINAR'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR'),
            ),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final token = await auth.getToken();
        final url = config.serverUrl;
        if (token == null) return;
        await ApiService(url).deleteExpense(token, e['id'] as String);
        await _loadData();
      } catch (_) {}
    }
  }

  String _formatCurrency(double v) => '\$ ${NumberFormat.decimalPattern('es_CO').format(v)}';

  String _groupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDay = DateTime(date.year, date.month, date.day);
    if (expenseDay == today) return 'Hoy';
    if (expenseDay == today.subtract(const Duration(days: 1))) return 'Ayer';
    if (expenseDay.isAfter(today.subtract(const Duration(days: 7)))) return 'Esta semana';
    return DateFormat('dd MMM', 'es').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final visible = _filtered.take(_displayCount).toList();
    final grouped = <String, List<dynamic>>{};
    for (final e in visible) {
      final date = DateTime.tryParse((e['expense_date'] as String).split('T').first) ?? DateTime.now();
      final key = _groupLabel(date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final total = _filtered.fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilterChipsBar(
            options: const [
              (value: 'all', label: 'Todas'),
              (value: 'this', label: 'Este mes'),
              (value: 'last', label: 'Mes anterior'),
            ],
            selected: _monthFilter,
            onChanged: (v) {
              _monthFilter = v;
              _applyFilters();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.receipt_text, size: 56, color: colorScheme.primary.withAlpha(100)),
                      const SizedBox(height: 12),
                      Text('Sin gastos para este filtro', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: grouped.length + 1,
                      itemBuilder: (_, idx) {
                        if (idx == grouped.length) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 80),
                            child: SizedBox.shrink(),
                          );
                        }
                        final key = grouped.keys.elementAt(idx);
                        final items = grouped[key]!;
                        final groupTotal = items.fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 4),
                              child: Row(
                                children: [
                                  Text(key, style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(_formatCurrency(groupTotal), style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary)),
                                ],
                              ),
                            ),
                            ...groupConsecutiveExpenses(items).map((block) {
                              final isGrouped = block.length > 1;
                              if (!isGrouped) {
                                return _buildTicketTile(block[0], isMain: true, isGrouped: false);
                              }
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: Colors.teal.shade400, width: 4)),
                                  color: Colors.teal.withValues(alpha: 0.03),
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < block.length; i++)
                                      _buildTicketTile(block[i], isMain: i == 0, isGrouped: true),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    Positioned(
                      right: 16,
                      bottom: 80,
                      child: AnimatedOpacity(
                        opacity: _showScrollTop ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: FloatingActionButton.small(
                          heroTag: 'scrollTop',
                          backgroundColor: colorScheme.primary,
                          onPressed: () => _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                          child: Icon(LucideIcons.arrow_up, color: colorScheme.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (_filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Row(
              children: [
                Text('Total visible: ', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(_formatCurrency(total), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}
