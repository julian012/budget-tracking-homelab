import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/theme/budget_theme.dart';
import 'package:budget_tracking/widgets/shared_split_section.dart';

void main() {
  group('SharedSplitSection', () {
    const people = [
      {'id': 'p1', 'name': 'Juan', 'color': '#EF4444', 'icon': '👤'},
      {'id': 'p2', 'name': 'Ana', 'color': '#3B82F6', 'icon': '🧑'},
    ];

    testWidgets('inicia deshabilitado y notifica lista vacía', (tester) async {
      List<Map<String, dynamic>>? lastShares;
      await tester.pumpWidget(MaterialApp(
        theme: BudgetTheme.light,
        home: Scaffold(
          body: SharedSplitSection(
            totalAmount: 50000,
            people: people,
            onSharesChanged: (shares) => lastShares = shares,
          ),
        ),
      ));
      expect(find.text('Gasto compartido'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(lastShares, isNull);
    });

    testWidgets('al activar y seleccionar una persona divide igualitariamente', (tester) async {
      List<Map<String, dynamic>>? lastShares;
      await tester.pumpWidget(MaterialApp(
        theme: BudgetTheme.light,
        home: Scaffold(
          body: SharedSplitSection(
            totalAmount: 50000,
            people: people,
            onSharesChanged: (shares) => lastShares = shares,
          ),
        ),
      ));
      // Activa el switch.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsNWidgets(2));

      // Selecciona a Juan.
      await tester.tap(find.widgetWithText(FilterChip, 'Juan'));
      await tester.pumpAndSettle();

      expect(lastShares, isNotNull);
      expect(lastShares!.length, 1);
      expect(lastShares!.first['person_id'], 'p1');
      expect(lastShares!.first['amount'], 25000.0);
      expect(find.text('Tu parte'), findsOneWidget);
    });

    testWidgets('seleccionar dos personas ajusta el residuo para el usuario', (tester) async {
      List<Map<String, dynamic>>? lastShares;
      await tester.pumpWidget(MaterialApp(
        theme: BudgetTheme.light,
        home: Scaffold(
          body: SharedSplitSection(
            totalAmount: 50000,
            people: people,
            onSharesChanged: (shares) => lastShares = shares,
          ),
        ),
      ));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Juan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Ana'));
      await tester.pumpAndSettle();

      expect(lastShares, isNotNull);
      expect(lastShares!.length, 2);
      // Base floor 16666 para cada una, usuario se queda con 16668.
      expect(lastShares!.map((s) => s['amount']).toSet(), {16666.0});
    });

    testWidgets('respeta initialShares precargados', (tester) async {
      List<Map<String, dynamic>>? lastShares;
      await tester.pumpWidget(MaterialApp(
        theme: BudgetTheme.light,
        home: Scaffold(
          body: SharedSplitSection(
            totalAmount: 60000,
            people: people,
            initiallyEnabled: true,
            initialShares: [
              {'person_id': 'p2', 'amount': 20000.0},
            ],
            onSharesChanged: (shares) => lastShares = shares,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Ana'), findsOneWidget);
      // La fila de Ana muestra el monto precargado y "Tu parte" refleja el resto.
      expect(find.text('20.000'), findsOneWidget);
      expect(find.text(r'$40,000.00'), findsOneWidget);
      // El callback se dispara solo ante interacciones, no al montar.
      expect(lastShares, isNull);
    });
  });
}
