import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/services/offline_queue_service.dart';
import 'package:budget_tracking/theme/budget_theme.dart';
import 'package:budget_tracking/widgets/pending_expenses_sheet.dart';

Widget _build(OfflineQueueService queue, ThemeData theme) {
  return ChangeNotifierProvider.value(
    value: queue,
    child: MaterialApp(
      theme: theme,
      home: Scaffold(
        body: PendingExpensesSheet(refresh: ValueNotifier<int>(0), onSaved: () {}),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  testWidgets('muestra "Todo sincronizado" sin pendientes', (tester) async {
    final queue = OfflineQueueService();
    await queue.init();

    await tester.pumpWidget(_build(queue, BudgetTheme.dark));

    expect(find.text('Todo sincronizado'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Completar'), findsNothing);
  });

  // Regresión #81: mismo riesgo que el banner del Dashboard — el tema real
  // define FilledButton con minimumSize.width = infinity y aquí va como
  // `trailing` de un ListTile.
  for (final entry in {'claro': BudgetTheme.light, 'oscuro': BudgetTheme.dark}.entries) {
    testWidgets('lista el gasto pendiente con su botón Completar sin romper el layout (${entry.key})', (tester) async {
      final queue = OfflineQueueService();
      await queue.init();
      await queue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');

      await tester.pumpWidget(_build(queue, entry.value));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('\$ 22.000'), findsOneWidget);
      expect(find.textContaining('Politas'), findsOneWidget);

      final button = find.widgetWithText(FilledButton, 'Completar');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).width, lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio));
    });
  }

  group('PendingExpenseTile', () {
    Widget tile({Widget? trailing}) => MaterialApp(
          theme: BudgetTheme.dark,
          home: Scaffold(
            body: PendingExpenseTile(
              pending: const {'local_id': 'x', 'amount': 22000.0, 'expense_date': '2026-09-19', 'description': 'Politas'},
              trailing: trailing,
            ),
          ),
        );

    testWidgets('muestra monto, fecha y descripción sin botón cuando no hay trailing', (tester) async {
      await tester.pumpWidget(tile());

      expect(find.text('\$ 22.000'), findsOneWidget);
      expect(find.textContaining('Politas'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('muestra el trailing cuando se entrega', (tester) async {
      await tester.pumpWidget(tile(trailing: FilledButton(style: BudgetTheme.compactFilledButton, onPressed: () {}, child: const Text('Completar'))));

      expect(find.widgetWithText(FilledButton, 'Completar'), findsOneWidget);
    });
  });

  // #101: descartar un pendiente (registrado por error o de prueba) sin enviarlo al servidor.
  group('descartar pendiente', () {
    Future<OfflineQueueService> pumpWithOne(WidgetTester tester) async {
      final queue = OfflineQueueService();
      await queue.init();
      await queue.addPending(amount: 13000, expenseDate: '2026-09-21', description: 'Prueba');
      await tester.pumpWidget(_build(queue, BudgetTheme.dark));
      await tester.pumpAndSettle();
      return queue;
    }

    testWidgets('pide confirmación y CANCELAR no elimina nada', (tester) async {
      final queue = await pumpWithOne(tester);

      await tester.tap(find.byTooltip('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar este gasto pendiente?'), findsOneWidget);
      expect(find.textContaining('No se enviará al servidor'), findsOneWidget);

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(queue.pending, hasLength(1));
      expect(find.textContaining('Prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DESCARTAR elimina el pendiente de la cola y de la lista', (tester) async {
      final queue = await pumpWithOne(tester);

      await tester.tap(find.byTooltip('Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DESCARTAR'));
      await tester.pumpAndSettle();

      expect(queue.pending, isEmpty);
      expect(find.text('Todo sincronizado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('convive con el botón Completar sin romper el layout (tema real)', (tester) async {
      await pumpWithOne(tester);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Descartar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Completar'), findsOneWidget);
    });
  });
}
