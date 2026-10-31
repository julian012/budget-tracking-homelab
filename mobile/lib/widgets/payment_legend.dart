import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

typedef PaymentLegendItem = ({String label, Color color});

/// Un ítem por método de pago (por etiqueta), conservando el orden de la primera
/// aparición. Los segmentos llegan repetidos por mes y traen el monto de ese mes,
/// por eso no se puede deduplicar con `toSet()` (los registros de Dart comparan
/// también el monto).
List<PaymentLegendItem> uniquePaymentLegend(Iterable<({String label, Color color, double amount})> segments) {
  final seen = <String>{};
  return [
    for (final s in segments)
      if (seen.add(s.label)) (label: s.label, color: s.color),
  ];
}

/// Leyenda de métodos de pago. Usa `Wrap` para saltar de línea en vez de
/// desbordarse cuando hay varios métodos.
class PaymentLegend extends StatelessWidget {
  final List<PaymentLegendItem> items;
  const PaymentLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: adaptCategoryColor(item.color, context)),
              ),
              const SizedBox(width: 4),
              Text(item.label, style: TextStyle(fontSize: 9, color: adaptCategoryColor(item.color, context))),
            ],
          ),
      ],
    );
  }
}
