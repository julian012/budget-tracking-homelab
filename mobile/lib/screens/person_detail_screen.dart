import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/currency_formatter.dart';
import '../utils/icon_helper.dart';
import '../widgets/payment_form_sheet.dart';
import '../widgets/person_form_sheet.dart';

class PersonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> person;
  final ValueNotifier<int> refresh;
  const PersonDetailScreen({super.key, required this.person, required this.refresh});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _shares = [];
  List<dynamic> _payments = [];
  String _filter = 'pending';

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
        ApiService(url).getPersonShares(token, widget.person['id'] as String, status: _filter),
        ApiService(url).getPersonPayments(token, widget.person['id'] as String),
      ]);
      if (mounted) {
        setState(() {
          _shares = results[0];
          _payments = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _registerPayment() async {
    final pending = _shares
        .where((s) => !(s['share']?['settled'] ?? false))
        .fold<double>(0, (sum, s) => sum + ((s['share']?['pending_amount'] as num?)?.toDouble() ?? 0));
    if (pending <= 0) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => PaymentFormSheet(
        personId: widget.person['id'] as String,
        maxAmount: pending,
        refresh: widget.refresh,
      ),
    );
  }

  Future<void> _editPerson() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => PersonFormSheet(existing: widget.person, refresh: widget.refresh, showCloseButton: false),
    );
    if (result != null && mounted) {
      widget.refresh.value++;
      Navigator.pop(context);
    }
  }

  Future<void> _deletePayment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar pago?'),
        content: const Text('El monto volverá a quedar como deuda pendiente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      await ApiService(url).deletePersonPayment(token, id);
      widget.refresh.value++;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = parseHexColor(widget.person['color']?.toString());
    final pendingTotal = _shares
        .where((s) => !(s['share']?['settled'] ?? false))
        .fold<double>(0, (sum, s) => sum + ((s['share']?['pending_amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person['name']?.toString() ?? 'Persona'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            tooltip: 'Editar',
            onPressed: _editPerson,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(theme, colorScheme)
              : _buildBody(theme, colorScheme, color, pendingTotal),
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.expense)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _loadData, icon: const Icon(LucideIcons.rotate_cw, size: 18), label: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme, Color color, double pendingTotal) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(BudgetTheme.spacing24),
          child: Padding(
            padding: const EdgeInsets.all(BudgetTheme.cardPadding),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withAlpha(40),
                  child: Text(widget.person['icon']?.toString() ?? '👤', style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 12),
                Text(widget.person['name']?.toString() ?? '', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Debe ${formatCurrency(pendingTotal)}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: pendingTotal > 0 ? _registerPayment : null,
                    icon: const Icon(LucideIcons.banknote, size: 18),
                    label: const Text('Registrar pago'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BudgetTheme.spacing24),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pendientes')),
              ButtonSegment(value: 'settled', label: Text('Cobrados')),
              ButtonSegment(value: 'all', label: Text('Todos')),
            ],
            selected: {_filter},
            onSelectionChanged: (v) {
              setState(() => _filter = v.first);
              _loadData();
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _shares.isEmpty
              ? Center(
                  child: Text(
                    'No hay gastos ${_filter == 'pending' ? 'pendientes' : _filter == 'settled' ? 'cobrados' : 'registrados'}',
                    style: TextStyle(color: colorScheme.textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: BudgetTheme.spacing24),
                  children: [
                    ..._shares.map((s) => _buildShareCard(theme, colorScheme, s)),
                    const SizedBox(height: 24),
                    if (_payments.isNotEmpty) ...[
                      Text('Historial de pagos', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ..._payments.map((p) => _buildPaymentTile(theme, colorScheme, p)),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildShareCard(ThemeData theme, ColorScheme colorScheme, dynamic item) {
    final share = item['share'] as Map<String, dynamic>? ?? {};
    final expense = item['expense'] as Map<String, dynamic>? ?? {};
    final category = expense['category'] as Map<String, dynamic>? ?? {};
    final catColor = parseHexColor(category['color']?.toString());
    final date = DateTime.tryParse((expense['expense_date'] as String?)?.split('T').first ?? '');
    final settled = share['settled'] == true;
    final pending = (share['pending_amount'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: categoryIconWidget(category['icon']?.toString(), size: 24, color: catColor),
        title: Text(expense['description']?.toString() ?? 'Gasto'),
        subtitle: Text(
          '${date != null ? DateFormat('dd/MM/yyyy').format(date) : ''} · Total ${formatCurrency((expense['amount'] as num?)?.toDouble() ?? 0)}',
          style: TextStyle(color: colorScheme.textSecondary, fontSize: 12),
        ),
        trailing: Chip(
          visualDensity: VisualDensity.compact,
          backgroundColor: settled ? colorScheme.income.withAlpha(40) : colorScheme.expense.withAlpha(40),
          label: Text(
            settled ? 'Cobrado' : 'Debe ${formatCurrency(pending)}',
            style: TextStyle(color: settled ? colorScheme.income : colorScheme.expense, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile(ThemeData theme, ColorScheme colorScheme, dynamic payment) {
    final date = DateTime.tryParse((payment['paid_at'] as String?) ?? '');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(LucideIcons.banknote),
      title: Text(formatCurrency((payment['amount'] as num?)?.toDouble() ?? 0)),
      subtitle: Text(
        '${date != null ? DateFormat('dd/MM/yyyy').format(date) : ''}${(payment['note']?.toString() ?? '').isNotEmpty ? ' · ${payment['note']}' : ''}',
        style: TextStyle(color: colorScheme.textSecondary, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(LucideIcons.trash_2, size: 18),
        onPressed: () => _deletePayment(payment['id'] as String),
      ),
    );
  }
}
