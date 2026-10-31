import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/icon_helper.dart';
import '../utils/pie_slices.dart';
import '../utils/report_ranges.dart';
import '../utils/reports_drilldown.dart';
import '../widgets/filter_chips_bar.dart';
import '../widgets/payment_legend.dart';

class ReportsScreen extends StatefulWidget {
  final ValueNotifier<int> refresh;
  const ReportsScreen({super.key, required this.refresh});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _prevStats;
  List<dynamic>? _allExpenses;
  List<dynamic> _cards = [];
  List<MapEntry<String, double>>? _monthlyData;
  List<({String month, List<({String label, Color color, double amount})> segments})> _monthlyPayments = [];
  List<Map<String, dynamic>>? _topCategories;
  bool _loading = true;
  String? _error;
  String _filter = 'quarter';
  String _topFilter = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_loadData);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final colorScheme = Theme.of(context).colorScheme;
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) throw Exception('No autenticado');
      final api = ApiService(url);

      final range = reportRange(filter: _filter, now: DateTime.now(), customStart: _customStart, customEnd: _customEnd);

      final results = await Future.wait([
        api.getStats(token, startDate: range.start, endDate: range.end),
        api.getStats(token, startDate: range.prevStart, endDate: range.prevEnd),
        api.getExpenses(token),
        api.getCards(token),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final prev = results[1] as Map<String, dynamic>;
      final all = results[2] as List<dynamic>;

      final months = <String, double>{};
      for (final e in all) {
        final date = DateTime.tryParse((e['expense_date'] as String).split('T').first);
        if (date != null) {
          final key = DateFormat('yyyy-MM', 'es').format(date);
          months[key] = (months[key] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
        }
      }
      final sortedMonths = months.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
      final monthly = sortedMonths.take(6).toList();

      final paymentsByMonth = <String, List<({String label, Color color, double amount})>>{};
      for (final e in all) {
        final date = DateTime.tryParse((e['expense_date'] as String).split('T').first);
        if (date == null) continue;
        final key = DateFormat('yyyy-MM', 'es').format(date);
        final amount = (e['amount'] as num?)?.toDouble() ?? 0;
        final card = e['card'] as Map<String, dynamic>?;
        final segments = paymentsByMonth.putIfAbsent(key, () => []);
        if (card == null) {
          segments.add((label: 'Efectivo', color: colorScheme.primary, amount: amount));
        } else {
          final name = card['name']?.toString() ?? 'Tarjeta';
          final color = parseHexColor(card['color']?.toString() ?? '');
          segments.add((label: name, color: color, amount: amount));
        }
      }
      final monthlyPayments = monthly.reversed.map((m) {
        final segs = paymentsByMonth[m.key] ?? [];
        final merged = <String, ({String label, Color color, double amount})>{};
        for (final s in segs) {
          final prev = merged[s.label];
          merged[s.label] = (label: s.label, color: s.color, amount: (prev?.amount ?? 0) + s.amount);
        }
        return (month: m.key, segments: merged.values.toList());
      }).toList();

      final topCats = _categoriesFromStats(stats);

      if (mounted) {
        setState(() {
          _stats = stats;
          _prevStats = prev;
          _allExpenses = all;
          _cards = results[3] as List<dynamic>;
          _topCategories = topCats;
          _monthlyData = monthly;
          _monthlyPayments = monthlyPayments;
          _loading = false;
          _error = null;
        });
        context.read<OfflineQueueService>().markDataLoaded();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }
  String _formatCurrency(double v) => '\$ ${NumberFormat.decimalPattern('es_CO').format(v)}';

  String _formatCurrencyShort(double v) => NumberFormat.compact(locale: 'es_CO').format(v);

  Widget _paymentCard(dynamic p) {
    final theme = Theme.of(context);
    final color = adaptCategoryColor(parseHexColor(p['color']?.toString() ?? ''), context);
    final franchise = p['franchise']?.toString() ?? 'other';
    final name = p['name']?.toString() ?? '';
    final total = (p['total'] as num?)?.toDouble() ?? 0;
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          franchiseIconWidget(franchise, size: 24, color: color),
          const SizedBox(height: 6),
          Text(name, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
          Text(_formatCurrency(total),
            style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _shortMonth(String ym) {
    final m = int.tryParse(ym.split('-').last) ?? 1;
    return ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][m];
  }

  bool _isFixed(Map<String, dynamic> cat) => (cat['type'] as int?) == 1;

  List<Map<String, dynamic>> _filterTopCategories() {
    if (_topCategories == null) return [];
    switch (_topFilter) {
      case 'fixed':
        return _topCategories!.where((c) => _isFixed(c)).toList();
      case 'variable':
        return _topCategories!.where((c) => !_isFixed(c)).toList();
      default:
        return _topCategories!;
    }
  }

  List<Map<String, dynamic>> _categoriesFromStats(Map<String, dynamic> stats) {
    return ((stats['by_category'] as List<dynamic>?) ?? [])
        .where((c) => ((c['total'] as num?)?.toDouble() ?? 0) > 0)
        .map((c) => {
              'id': c['category_id'],
              'name': c['category_name'],
              'icon': c['icon'],
              'color': c['color'],
              'type': c['type'],
              'total': (c['total'] as num?)?.toDouble() ?? 0,
              'count': (c['count'] as num?)?.toInt() ?? 0,
            })
        .toList()
      ..sort((a, b) => ((b['total'] as num?)?.toDouble() ?? 0).compareTo((a['total'] as num?)?.toDouble() ?? 0));
  }

  Future<void> _loadTopCategories() async {
    final range = _periodRange();
    final type = _topFilter == 'fixed' ? 'fixed' : (_topFilter == 'variable' ? 'variable' : null);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final stats = await ApiService(url).getStats(
        token,
        startDate: DateFormat('yyyy-MM-dd').format(range.start),
        endDate: DateFormat('yyyy-MM-dd').format(range.end),
        type: type,
      );
      if (mounted) setState(() => _topCategories = _categoriesFromStats(stats));
    } catch (_) {}
  }

  List<Map<String, dynamic>> _buildPieSlices(Color otherColor, BuildContext context) {
    final raw = consolidateTopSlices((_stats?['by_category'] as List<dynamic>?) ?? []);
    return raw.map((c) {
      if (c['is_other'] == true) {
        return {...c, 'color': otherColor};
      }
      return {...c, 'color': adaptCategoryColor(parseHexColor(c['color']?.toString() ?? ''), context)};
    }).toList();
  }

  String? _buildPaymentBreakdown() {
    final cash = (_stats?['cash_count'] as num?)?.toInt() ?? 0;
    final cards = (_stats?['card_count'] as num?)?.toInt() ?? 0;
    if (_cards.isEmpty || cards == 0) return '$cash transacciones en efectivo';
    return '$cash en efectivo • $cards gastos con tarjeta';
  }

  ({DateTime start, DateTime end}) _periodRange() {
    final now = DateTime.now();
    if (_filter == 'custom' && _customStart != null && _customEnd != null) {
      return (start: _customStart!, end: _customEnd!);
    } else if (_filter == 'month') {
      return (start: DateTime(now.year, now.month, 1), end: now);
    } else if (_filter == '7d') {
      return (start: now.subtract(const Duration(days: 6)), end: now);
    }
    return (start: now.subtract(const Duration(days: 90)), end: now);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
      locale: const Locale('es'),
      helpText: 'Seleccionar rango',
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _filter = 'custom';
      });
      _loadData();
    }
  }

  Future<void> _showCategoryDetail(Map<String, dynamic> cat) async {
    final range = _periodRange();
    final catId = cat['id'] as String;
    final transactions = (_allExpenses ?? []).where((e) {
      if (e['category'] is Map && (e['category'] as Map)['id']?.toString() == catId) {
        final date = DateTime.tryParse((e['expense_date'] as String).split('T').first);
        if (date != null) {
          return !date.isBefore(range.start) && !date.isAfter(range.end);
        }
      }
      return false;
    }).toList()
      ..sort((a, b) => ((b['expense_date'] as String?) ?? '').compareTo((a['expense_date'] as String?) ?? ''));

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catColor = adaptCategoryColor(parseHexColor(cat['color']?.toString() ?? ''), context);

    final startDay = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day);
    final totalDays = endDay.difference(startDay).inDays + 1;

    final dayAmounts = aggregateDailyAmounts(transactions, startDay, end: endDay);
    final maxDailyAmount = dayAmounts.isEmpty ? 0.0 : dayAmounts.values.reduce((a, b) => a > b ? a : b);

    final dailySpots = <FlSpot>[
      for (var i = 0; i < totalDays; i++) FlSpot(i.toDouble(), (dayAmounts[i] ?? 0)),
    ];
    final chartMax = chartMaxY(maxDailyAmount);
    final yInterval = chartYInterval(maxDailyAmount);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 16),
                categoryIconWidget(cat['icon']?.toString(), size: 22, color: catColor),
                const SizedBox(width: 8),
                Text(cat['name'] as String? ?? '', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_formatCurrency((cat['total'] as num?)?.toDouble() ?? 0), style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.primary)),
                  const SizedBox(width: 8),
                  Text('· ${cat['count'] ?? 0} transacciones', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (dailySpots.length >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 150,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: chartMax,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: yInterval,
                            getTitlesWidget: (v, _) => v <= 0
                                ? const SizedBox.shrink()
                                : Text(
                                    formatAxisAmount(v),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: totalDays > 20 ? (totalDays / 5).ceilToDouble() : 1,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= totalDays) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  DateFormat('dd/MM', 'es').format(startDay.add(Duration(days: idx))),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => colorScheme.surface,
                          getTooltipItems: (spots) => spots.map((spot) {
                            final idx = spot.x.toInt();
                            final text = idx >= 0 && idx < totalDays
                                ? '${DateFormat('dd MMM', 'es').format(startDay.add(Duration(days: idx)))} · ${_formatCurrency(spot.y)}'
                                : _formatCurrency(spot.y);
                            return LineTooltipItem(
                              text,
                              TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: dailySpots,
                          isCurved: false,
                          color: catColor,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, _) => spot.y > 0,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 3,
                              color: catColor,
                              strokeWidth: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('Sin transacciones en este período'))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: transactions.length,
                      itemBuilder: (_, i) {
                        final e = transactions[i];
                        final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                        final desc = e['description'] as String? ?? 'Gasto';
                        final date = DateTime.tryParse((e['expense_date'] as String).split('T').first);
                        final fmtDate = date != null ? DateFormat('dd MMM yyyy', 'es').format(date) : '';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(desc, style: theme.textTheme.labelLarge),
                          subtitle: Text(fmtDate, style: theme.textTheme.bodySmall),
                          trailing: Text(_formatCurrency(amount), style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.expense)),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final total = (_stats?['total'] as num?)?.toDouble() ?? 0;
    final prevTotal = (_prevStats?['total'] as num?)?.toDouble() ?? 0;
    final count = _allExpenses?.length ?? 0;
    final prevCount = (_prevStats?['by_category'] as List<dynamic>?)?.fold<int>(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0)) ?? 0;
    final threshold = _monthlyData != null && _monthlyData!.isNotEmpty ? _monthlyData!.map((e) => e.value).reduce((a, b) => a + b) / _monthlyData!.length : 0.0;
    final trendMaxY = _monthlyData != null && _monthlyData!.isNotEmpty
        ? [_monthlyData!.map((e) => e.value).reduce((a, b) => a > b ? a : b), threshold].reduce((a, b) => a > b ? a : b) * 1.3
        : 0.0;

    final List<Map<String, dynamic>> filteredTop = _filterTopCategories().take(8).toList();

    final cardPayments = ((_stats?['by_payment'] as List<dynamic>?) ?? [])
        .where((p) => p['card_id'] != null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChipsBar(
            options: const [
              (value: 'quarter', label: '3 meses'),
              (value: 'month', label: 'Este mes'),
              (value: '7d', label: '7 días'),
            ],
            selected: _filter,
            onChanged: (v) {
              setState(() => _filter = v);
              _loadData();
            },
            trailing: ActionChip(
              avatar: Icon(LucideIcons.calendar, size: 16, color: _filter == 'custom' ? colorScheme.primary : null),
              label: Text(
                _filter == 'custom' && _customStart != null
                    ? '${DateFormat('dd/MM').format(_customStart!)}-${DateFormat('dd/MM').format(_customEnd!)}'
                    : 'Personalizado',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: _pickCustomRange,
              backgroundColor: _filter == 'custom' ? colorScheme.primary.withAlpha(40) : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InsightCard(theme: theme, label: 'Total', value: _formatCurrency(total), prev: prevTotal, color: colorScheme.primary),
              const SizedBox(width: 12),
              _InsightCard(theme: theme, label: 'Transacciones', value: count.toString(), prev: prevCount.toDouble(), color: colorScheme.income, subtitle: _buildPaymentBreakdown()),
            ],
          ),
          const SizedBox(height: 24),
          Text('Tendencia mensual', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _monthlyData != null && _monthlyData!.isNotEmpty
                ? Column(
                    children: [
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    _formatCurrency(rod.toY),
                                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: threshold,
                                  color: Colors.orange.shade300,
                                  strokeWidth: 2,
                                  dashArray: [8, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    labelResolver: (_) => _formatCurrencyShort(threshold),
                                    style: TextStyle(color: Colors.orange.shade300, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            alignment: BarChartAlignment.spaceAround,
                            maxY: trendMaxY,
                            barGroups: _monthlyPayments.asMap().entries.map((en) {
                              final segs = en.value.segments;
                              var cum = 0.0;
                              final items = segs.map((s) {
                                final start = cum;
                                cum += s.amount;
                                return BarChartRodStackItem(start, cum, adaptCategoryColor(s.color, context));
                              }).toList();
                              return BarChartGroupData(
                                x: en.key,
                                barRods: [BarChartRodData(
                                  toY: cum,
                                  rodStackItems: items,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  width: 18,
                                )],
                              );
                            }).toList(),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(_formatCurrencyShort(v).replaceAll('\$', ''), style: const TextStyle(fontSize: 9)))),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_shortMonth(_monthlyData!.reversed.elementAt(v.toInt()).key), style: const TextStyle(fontSize: 10)),
                              ))),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: trendGridInterval(trendMaxY)),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 12, height: 2, decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(1))),
                            const SizedBox(width: 4),
                            Text('Bajo el promedio', style: TextStyle(fontSize: 9, color: colorScheme.primary)),
                            const SizedBox(width: 12),
                            Container(width: 12, height: 2, decoration: BoxDecoration(color: colorScheme.expense, borderRadius: BorderRadius.circular(1))),
                            const SizedBox(width: 4),
                            Text('Sobre el promedio', style: TextStyle(fontSize: 9, color: colorScheme.expense)),
                          ],
                        ),
                      ),
                      if (_monthlyPayments.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: PaymentLegend(items: uniquePaymentLegend(_monthlyPayments.expand((m) => m.segments))),
                        ),
                      ],
                    ],
                  )
                : Center(child: Text('Sin datos', style: theme.textTheme.bodyMedium)),
          ),
          const SizedBox(height: 24),
          if (_stats != null) ...[
            Text('Distribución por categoría', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSlices(
                          Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade700,
                          context,
                        ).map((c) {
                          final catTotal = (c['total'] as num?)?.toDouble() ?? 1;
                          final catColor = c['color'] as Color;
                          final pct = total > 0 ? (catTotal / total * 100).round() : 0;
                          return PieChartSectionData(
                            value: catTotal, title: pct > 5 ? '$pct%' : '',
                            color: catColor, radius: 55,
                            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }).toList(),
                        sectionsSpace: 2, centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildPieSlices(
                        Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade700,
                        context,
                      ).map((c) {
                        final catName = c['category_name'] as String? ?? '';
                        final catColor = c['color'] as Color;
                        final catTotal = (c['total'] as num?)?.toDouble() ?? 0;
                        final pct = total > 0 ? (catTotal / total * 100).round() : 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: catColor)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(catName, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('$pct%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_cards.isNotEmpty && cardPayments.isNotEmpty) ...[
            Text('Uso de Tarjetas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: cardPayments.map((p) => _paymentCard(p)).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_topCategories != null && _topCategories!.isNotEmpty) ...[
            Row(
              children: [
                Text('Mayores gastos', style: theme.textTheme.titleMedium),
                const Spacer(),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Todos', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'fixed', label: Text('Fijos', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'variable', label: Text('Var.', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_topFilter},
                  onSelectionChanged: (v) {
                    setState(() => _topFilter = v.first);
                    _loadTopCategories();
                  },
                  style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(36, 28))),
                ),
              ],
            ),
            ...List.generate(filteredTop.length, (i) {
              final c = filteredTop[i];
              final catName = c['name'] as String;
              final catColor = adaptCategoryColor(parseHexColor(c['color']?.toString() ?? ''), context);
              final catTotal = (c['total'] as num?)?.toDouble() ?? 0;
              final catCount = c['count'] as int? ?? 0;
              return ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 48,
                  child: Row(children: [
                    Text('#${i + 1}', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                    const SizedBox(width: 6),
                    categoryIconWidget(c['icon']?.toString(), size: 18, color: catColor),
                  ]),
                ),
                title: Text(catName, style: theme.textTheme.labelLarge),
                subtitle: Text('${_formatCurrency(catTotal)} · $catCount ${catCount == 1 ? "transacción" : "transacciones"}', style: theme.textTheme.bodySmall),
                trailing: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: catColor)),
                onTap: () => _showCategoryDetail(c),
              );
            }),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: colorScheme.expense, fontSize: 13)),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final String value;
  final double prev;
  final Color color;
  final String? subtitle;
  const _InsightCard({required this.theme, required this.label, required this.value, required this.prev, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final diff = prev > 0 ? ((double.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0) - prev) / prev * 100 : 0.0;
    final isDown = diff < 0;
    final absDiff = diff.abs().round();
    final semColor = isDown ? theme.colorScheme.income : (diff == 0 ? Colors.grey : theme.colorScheme.expense);
    final icon = isDown ? LucideIcons.trending_down : LucideIcons.trending_up;

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (subtitle != null) ...[
                Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                const SizedBox(height: 2),
              ],
              Row(
                children: [
                  if (prev > 0) ...[
                    Icon(icon, size: 14, color: semColor),
                    const SizedBox(width: 2),
                    Text('${isDown ? '-' : '+'}$absDiff%', style: TextStyle(color: semColor, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
