import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/widgets/expense_form_sheet.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/offline_queue_service.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/services/theme_controller.dart';

// flutter_test intercepta todo el tráfico HTTP y siempre responde 400, nunca
// lanza una excepción real de conectividad — así que para simular "sin
// conexión" de forma determinista se inyecta un categoriesLoader que sí
// lanza SocketException, vía el seam @visibleForTesting del widget.
Future<List<dynamic>> _unreachableLoader(String url, String token) async {
  throw const SocketException('Connection refused');
}

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget _buildExpenseForm(
  ServerConfig config,
  OfflineQueueService offlineQueue, {
  Map<String, dynamic>? pendingToComplete,
  bool simulateOffline = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(
        value: AuthService(auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid', email: 'a@b.com'),
        )),
      ),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider.value(value: offlineQueue),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ExpenseFormSheet(
          pendingToComplete: pendingToComplete,
          refresh: ValueNotifier(0),
          onSaved: () {},
          categoriesLoader: simulateOffline ? _unreachableLoader : null,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('falls back to offline capture when categories fail with a connectivity error', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();

    await tester.pumpWidget(_buildExpenseForm(config, offlineQueue, simulateOffline: true));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo gasto (sin conexión)'), findsOneWidget);
    // Sin categoría/tarjeta/split en este modo.
    expect(find.text('Categoría'), findsNothing);
    expect(find.text('Guardar sin conexión'), findsOneWidget);
  });

  testWidgets('saving offline adds a pending item and closes the sheet', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();

    await tester.pumpWidget(_buildExpenseForm(config, offlineQueue, simulateOffline: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '35000');
    await tester.tap(find.text('Guardar sin conexión'));
    await tester.pumpAndSettle();

    expect(offlineQueue.pending.length, 1);
    expect(offlineQueue.pending.first['amount'], 35000.0);
    expect(find.byType(ExpenseFormSheet), findsNothing);
  });

  testWidgets('completing a pending item never falls back to offline mode, even if categories fail', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 35000, expenseDate: '2026-08-25', description: 'Agua');
    final pending = offlineQueue.pending.first;

    await tester.pumpWidget(_buildExpenseForm(
      config,
      offlineQueue,
      pendingToComplete: pending,
      simulateOffline: true,
    ));
    await tester.pumpAndSettle();

    // Aunque la carga de categorías falla igual (simulateOffline: true), al
    // estar completando un pendiente no debe caer en modo captura offline —
    // se muestra el form normal (con su error de carga interno).
    expect(find.text('Nuevo gasto (sin conexión)'), findsNothing);
    expect(find.text('Nuevo gasto'), findsOneWidget);

    final amountField = tester.widget<TextField>(find.byType(TextField).first);
    expect(amountField.controller?.text, contains('35.000'));

    final descField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(descField.controller?.text, 'Agua');
  });
}
