import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/offline_queue_service.dart';
import '../theme/budget_theme.dart';
import 'expense_form_sheet.dart';

/// Fila de un gasto pendiente (monto · fecha · descripción). Compartida entre
/// el sheet de pendientes (con botón «Completar» como [trailing]) y la lista de
/// solo lectura del banner de Inicio sin conexión (sin [trailing]).
class PendingExpenseTile extends StatelessWidget {
  final Map<String, dynamic> pending;
  final Widget? trailing;
  const PendingExpenseTile({super.key, required this.pending, this.trailing});

  static String _formatCurrency(double v) => '\$ ${NumberFormat.decimalPattern('es_CO').format(v)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(pending['expense_date'] as String? ?? '');
    final desc = (pending['description'] as String?)?.trim();
    final subtitleParts = [
      if (date != null) DateFormat('dd MMM yyyy', 'es').format(date),
      if (desc != null && desc.isNotEmpty) desc,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(LucideIcons.clock, color: theme.colorScheme.onSurfaceVariant),
      title: Text(_formatCurrency((pending['amount'] as num).toDouble()), style: theme.textTheme.titleMedium),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: trailing,
    );
  }
}

/// Ícono «Descartar» de un gasto pendiente: pide confirmación (mismo patrón que
/// eliminar un gasto) y, si se confirma, lo quita de la cola local con
/// `removePending`. No toca el servidor, así que funciona sin conexión (#101).
class PendingDiscardButton extends StatelessWidget {
  final Map<String, dynamic> pending;
  const PendingDiscardButton({super.key, required this.pending});

  static String _formatCurrency(double v) => '\$ ${NumberFormat.decimalPattern('es_CO').format(v)}';

  Future<void> _discard(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final queue = context.read<OfflineQueueService>();
    final desc = (pending['description'] as String?)?.trim();
    final label = [
      _formatCurrency((pending['amount'] as num).toDouble()),
      if (desc != null && desc.isNotEmpty) desc,
    ].join(' · ');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '¿Descartar este gasto pendiente?',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$label\nNo se enviará al servidor y no se podrá recuperar.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colorScheme.expense),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('DESCARTAR'),
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
    if (confirmed == true) await queue.removePending(pending['local_id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Descartar',
      icon: Icon(LucideIcons.trash_2, color: Theme.of(context).colorScheme.expense),
      onPressed: () => _discard(context),
    );
  }
}

/// Lista los gastos capturados sin conexión (solo monto/fecha/descripción) y
/// deja abrir el formulario normal para completar cada uno (categoría, medio
/// de pago, split) cuando ya hay conexión. No sincroniza nada por sí sola.
class PendingExpensesSheet extends StatelessWidget {
  final ValueNotifier<int> refresh;
  final VoidCallback onSaved;
  const PendingExpensesSheet({super.key, required this.refresh, required this.onSaved});

  Future<void> _complete(BuildContext context, Map<String, dynamic> pending) async {
    Navigator.pop(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => ExpenseFormSheet(pendingToComplete: pending, refresh: refresh, onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = context.watch<OfflineQueueService>().pending;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Gastos pendientes de completar', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Se guardaron sin conexión. Elige la categoría y el medio de pago para sincronizarlos.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Todo sincronizado', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              )
            else
              ...pending.map((p) => PendingExpenseTile(
                    pending: p,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PendingDiscardButton(pending: p),
                        FilledButton(
                          style: BudgetTheme.compactFilledButton,
                          onPressed: () => _complete(context, p),
                          child: const Text('Completar'),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
