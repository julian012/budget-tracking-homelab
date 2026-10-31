import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/widgets/wallet_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 340, child: child)),
        ),
      );

  Map<String, dynamic> baseCard({
    String name = 'Visa Signature',
    String franchise = 'visa',
    String color = '#1A1C1E',
    num? creditLimit = 5000000,
    int cutOffDay = 15,
    int paymentDay = 5,
  }) =>
      {
        'id': 'card-1',
        'name': name,
        'franchise': franchise,
        'color': color,
        'credit_limit': creditLimit,
        'cut_off_day': cutOffDay,
        'payment_day': paymentDay,
      };

  group('WalletCard', () {
    testWidgets('muestra nombre, límite formateado y corte/pago', (tester) async {
      await tester.pumpWidget(wrap(WalletCard(card: baseCard(), onTap: () {})));

      expect(find.text('Visa Signature'), findsOneWidget);
      expect(find.textContaining('5.000.000'), findsOneWidget);
      expect(find.text('Corte: 15 · Pago: 5'), findsOneWidget);
    });

    testWidgets('sin credit_limit muestra máscara ****', (tester) async {
      await tester.pumpWidget(wrap(WalletCard(
        card: baseCard(creditLimit: null),
        onTap: () {},
      )));

      expect(find.text('****'), findsOneWidget);
    });

    testWidgets('invoca onTap al tocar la tarjeta', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(WalletCard(card: baseCard(), onTap: () => taps++)));

      await tester.tap(find.text('Visa Signature'));
      expect(taps, 1);
    });

    testWidgets('color vacío usa fallback gris sin crashear', (tester) async {
      await tester.pumpWidget(wrap(WalletCard(
        card: baseCard(color: ''),
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Visa Signature'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hex malformado no rompe el render (parseHexColor robusto)', (tester) async {
      await tester.pumpWidget(wrap(WalletCard(
        card: baseCard(color: '#ZZZZZZ'),
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
