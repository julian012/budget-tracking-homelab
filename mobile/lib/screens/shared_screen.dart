import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/currency_formatter.dart';
import '../widgets/person_form_sheet.dart';
import 'person_detail_screen.dart';

class SharedScreen extends StatefulWidget {
  final ValueNotifier<int> refresh;
  const SharedScreen({super.key, required this.refresh});

  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<dynamic> _people = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.refresh.addListener(_onRefresh);
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) throw Exception('No autenticado');
      final results = await Future.wait([
        ApiService(url).getSharedSummary(token),
        ApiService(url).getPeople(token),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _people = results[1] as List<dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _addPerson() async {
    final created = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => PersonFormSheet(refresh: widget.refresh, showCloseButton: false),
    );
    if (created != null) {
      widget.refresh.value++;
    }
  }

  void _openPerson(dynamic person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonDetailScreen(person: person, refresh: widget.refresh),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pendingTotal = (_summary['pending_total'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compartidos'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.user_plus),
            tooltip: 'Nueva persona',
            onPressed: _addPerson,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(theme, colorScheme)
                : _buildBody(theme, colorScheme, pendingTotal),
      ),
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(BudgetTheme.spacing24),
      children: [
        Card(
          color: colorScheme.expense.withAlpha(20),
          child: ListTile(
            leading: Icon(LucideIcons.circle_alert, color: colorScheme.expense),
            title: Text(_error!, style: TextStyle(color: colorScheme.expense, fontSize: 13)),
            trailing: IconButton(
              icon: Icon(LucideIcons.rotate_cw, color: colorScheme.expense),
              onPressed: _loadData,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme, double pendingTotal) {
    if (_people.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(BudgetTheme.spacing24),
        children: [
          _buildSummaryCard(theme, colorScheme, pendingTotal),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(LucideIcons.users, size: 64, color: colorScheme.textSecondary),
                const SizedBox(height: 16),
                Text('Sin personas aún', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Agregá a tu roomie u otras personas con las que compartas gastos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _addPerson,
                  icon: const Icon(LucideIcons.user_plus, size: 18),
                  label: const Text('Agregar persona'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(BudgetTheme.spacing24),
      children: [
        _buildSummaryCard(theme, colorScheme, pendingTotal),
        const SizedBox(height: 24),
        Text('Personas', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        ..._people.map((p) => _buildPersonCard(theme, colorScheme, p)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSummaryCard(ThemeData theme, ColorScheme colorScheme, double pendingTotal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BudgetTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.hand_coins, color: colorScheme.income),
                const SizedBox(width: 8),
                Text('Te deben', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatCurrency(pendingTotal), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              pendingTotal == 0 ? 'No hay deudas pendientes' : 'Total pendiente de recuperar',
              style: TextStyle(color: colorScheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(ThemeData theme, ColorScheme colorScheme, dynamic person) {
    final summaries = (_summary['people'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final ps = summaries.firstWhere(
      (s) => (s['person'] as Map<String, dynamic>)['id']?.toString() == person['id']?.toString(),
      orElse: () => {'pending_total': 0.0, 'shared_total': 0.0},
    );
    final pending = (ps['pending_total'] as num?)?.toDouble() ?? 0;
    final shared = (ps['shared_total'] as num?)?.toDouble() ?? 0;
    final color = parseHexColor(person['color']?.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(40),
          child: Text(person['icon']?.toString() ?? '👤'),
        ),
        title: Text(person['name']?.toString() ?? ''),
        subtitle: Text('Debe ${formatCurrency(pending)} · Total compartido ${formatCurrency(shared)}'),
        trailing: const Icon(LucideIcons.chevron_right, size: 18),
        onTap: () => _openPerson(person),
      ),
    );
  }
}
