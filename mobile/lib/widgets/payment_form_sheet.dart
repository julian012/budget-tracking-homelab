import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/default_amount.dart';

class PaymentFormSheet extends StatefulWidget {
  final String personId;
  final double maxAmount;
  final ValueNotifier<int> refresh;
  const PaymentFormSheet({super.key, required this.personId, required this.maxAmount, required this.refresh});

  @override
  State<PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<PaymentFormSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _amountCtrl.text = formatAmountInput(widget.maxAmount);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = parseDefaultAmount(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
      return;
    }
    if (amount > widget.maxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El pago no puede superar los ${formatCurrency(widget.maxAmount)}')));
      return;
    }
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      await ApiService(url).createPersonPayment(token, widget.personId, {
        'amount': amount,
        'paid_at': DateFormat('yyyy-MM-dd').format(_date),
        'note': _noteCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.refresh.value++;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Registrar pago', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Máximo: ${formatCurrency(widget.maxAmount)}', style: TextStyle(color: theme.colorScheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto recibido',
            prefixIcon: Icon(LucideIcons.banknote, size: 18),
          ),
          inputFormatters: [ThousandsFormatter()],
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.calendar),
          title: const Text('Fecha del pago'),
          subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
          onTap: _pickDate,
        ),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: 'Nota (opcional)', prefixIcon: Icon(LucideIcons.file_text, size: 18)),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar pago'),
          ),
        ),
      ]),
    );
  }
}
