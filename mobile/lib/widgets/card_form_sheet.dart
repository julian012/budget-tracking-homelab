import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/currency_formatter.dart';

class CardFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final ValueNotifier<int> refresh;
  const CardFormSheet({super.key, this.existing, required this.refresh});

  @override
  State<CardFormSheet> createState() => _CardFormSheetState();
}

const _cardColors = ['#EF4444', '#F59E0B', '#8B5CF6', '#EC4899', '#10B981', '#3B82F6', '#06B6D4', '#84CC16', '#F97316', '#1A1C1E'];

class _CardFormSheetState extends State<CardFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _limitCtrl;
  late int _cutOffDay;
  late int _paymentDay;
  late String _franchise;
  late String _color;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] ?? '');
    _franchise = e?['franchise'] ?? 'visa';
    _color = e?['color'] ?? '#1A1C1E';
    _cutOffDay = e?['cut_off_day'] ?? 1;
    _paymentDay = e?['payment_day'] ?? 1;
    final limit = (e?['credit_limit'] as num?)?.toDouble();
    _limitCtrl = TextEditingController(
      text: limit != null ? NumberFormat.decimalPattern('es_CO').format(limit.toInt()) : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el nombre de la tarjeta');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final rawLimit = _limitCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      double? limit = rawLimit.isEmpty ? null : double.tryParse(rawLimit);
      final body = {
        'name': _nameCtrl.text.trim(),
        'franchise': _franchise,
        'color': _color,
        'cut_off_day': _cutOffDay,
        'payment_day': _paymentDay,
        'credit_limit': limit,
      };
      if (_isEdit) {
        await ApiService(url).updateCard(token, widget.existing!['id'] as String, body);
      } else {
        await ApiService(url).createCard(token, body);
      }
      if (mounted) {
        Navigator.pop(context, true);
        widget.refresh.value++;
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
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
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text(_isEdit ? 'Editar tarjeta' : 'Nueva tarjeta', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre de la tarjeta', prefixIcon: Icon(LucideIcons.credit_card, size: 18)),
          autofocus: true,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _franchise,
          decoration: const InputDecoration(labelText: 'Franquicia'),
          items: const [
            DropdownMenuItem(value: 'visa', child: Text('Visa')),
            DropdownMenuItem(value: 'mastercard', child: Text('Mastercard')),
            DropdownMenuItem(value: 'amex', child: Text('American Express')),
            DropdownMenuItem(value: 'diners', child: Text('Diners Club')),
            DropdownMenuItem(value: 'other', child: Text('Otra')),
          ],
          onChanged: (v) => setState(() => _franchise = v ?? 'other'),
        ),
        const SizedBox(height: 16),
        const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _cardColors.map((c) {
          final selected = _color == c;
          final color = Color(int.parse(c.replaceFirst('#', 'FF'), radix: 16));
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _cutOffDay,
          decoration: const InputDecoration(labelText: 'Día de corte'),
          items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: (v) => setState(() => _cutOffDay = v ?? 1),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _paymentDay,
          decoration: const InputDecoration(labelText: 'Día de pago límite'),
          items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
          onChanged: (v) => setState(() => _paymentDay = v ?? 1),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _limitCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Cupo/Tope (Opcional)', prefixText: '\$ '),
          inputFormatters: [ThousandsFormatter()],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.expense, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
              : Text(_isEdit ? 'Guardar cambios' : 'Guardar tarjeta'),
        ),
      ]),
    );
  }
}
