import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/theme/budget_theme.dart';
import 'package:budget_tracking/widgets/payment_legend.dart';

typedef _Seg = ({String label, Color color, double amount});

void main() {
  group('uniquePaymentLegend', () {
    test('un ítem por método aunque se repita en varios meses con montos distintos (#104)', () {
      final segments = <_Seg>[
        (label: 'Efectivo', color: Colors.blue, amount: 3000000), // ago
        (label: 'Life Miles', color: Colors.red, amount: 2000000),
        (label: 'Efectivo', color: Colors.blue, amount: 900000), // sep
        (label: 'Life Miles', color: Colors.red, amount: 1500000),
        (label: 'Fondavivienda', color: Colors.grey, amount: 100),
      ];
      expect(uniquePaymentLegend(segments).map((i) => i.label), ['Efectivo', 'Life Miles', 'Fondavivienda']);
    });

    test('conserva el orden de la primera aparición y no falla con vacío', () {
      expect(uniquePaymentLegend(const <_Seg>[]), isEmpty);
    });
  });

  testWidgets('PaymentLegend salta de línea en vez de desbordarse (pantalla angosta, 6 métodos)', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final items = [
      for (final name in ['Efectivo', 'Life Miles', 'Fondavivienda', 'e-Card Bancolombia', 'Nequi', 'Daviplata'])
        (label: name, color: Colors.teal),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: BudgetTheme.dark,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: PaymentLegend(items: items))),
    ));

    expect(tester.takeException(), isNull); // un Row largo lanzaba "RIGHT OVERFLOWED BY 151 PIXELS"
    for (final i in items) {
      expect(find.text(i.label), findsOneWidget);
    }
    expect(tester.getSize(find.byType(Wrap)).width, lessThanOrEqualTo(360 - 32));
  });
}
