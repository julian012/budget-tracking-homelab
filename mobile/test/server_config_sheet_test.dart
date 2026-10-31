import 'dart:io';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/screens/home_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/offline_queue_service.dart';
import 'package:budget_tracking/services/profile_controller.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/services/theme_controller.dart';
import 'package:budget_tracking/theme/budget_theme.dart';

/// Servidor local mínimo: `/health` responde 200 y el resto 500 (el Inicio
/// tolera que las demás rutas fallen).
Future<HttpServer> _startServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    await req.drain<void>();
    req.response.statusCode = req.uri.path == '/health' ? 200 : 500;
    req.response.write('{}');
    await req.response.close();
  });
  return server;
}

/// El token del mock usa timers del reloj falso y el HTTP usa sockets reales:
/// se alternan ambos para que la cadena termine.
Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

/// Monta el Inicio contra el servidor local y abre el sheet «Configurar servidor»
/// desde el indicador de conexión del AppBar (solo visible en debug).
Future<({ServerConfig config, HttpServer server})> _pumpAndOpenSheet(WidgetTester tester) async {
  HttpOverrides.global = null; // sockets reales (flutter_test los bloquea por defecto)
  SharedPreferences.setMockInitialValues({});

  final server = (await tester.runAsync(_startServer))!;
  addTearDown(() => server.close(force: true));

  final config = ServerConfig();
  await config.init();
  await config.setServerUrl('http://127.0.0.1:${server.port}');
  final offlineQueue = OfflineQueueService();
  await offlineQueue.init();
  final auth = AuthService(
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u', email: 'a@b.com')),
  );

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ProfileController()),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider.value(value: offlineQueue),
    ],
    child: MaterialApp(theme: BudgetTheme.dark, home: const HomeScreen()),
  ));
  await _settleNetwork(tester);

  expect(find.text('Conectado'), findsOneWidget);
  await tester.tap(find.text('Conectado'));
  await tester.pumpAndSettle();
  expect(find.text('Configurar servidor'), findsOneWidget);
  return (config: config, server: server);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  // #75: al pulsar «Guardar» la app se caía con `'_dependents.isEmpty'` y la URL
  // podía no persistir. Causas: el controller se destruía con
  // `.whenComplete(...)` (en el pop, con el sheet aún animándose) y
  // `setServerUrl` se llamaba sin `await` antes de cerrar el sheet.
  testWidgets('Guardar persiste la nueva URL y cierra el sheet sin excepciones', (tester) async {
    final (:config, :server) = await _pumpAndOpenSheet(tester);
    final newUrl = 'http://localhost:${server.port}';

    await tester.enterText(find.byType(TextField), newUrl);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await _settleNetwork(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(config.serverUrl, newUrl);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('server_url'), newUrl);
    expect(find.text('Configurar servidor'), findsNothing); // el sheet se cerró
  });

  testWidgets('Probar conexión muestra el resultado', (tester) async {
    await _pumpAndOpenSheet(tester);

    await tester.tap(find.text('Probar conexión'));
    await _settleNetwork(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Conexión exitosa'), findsOneWidget);
  });

  testWidgets('el switch «Mostrar indicador» refleja el cambio y oculta el indicador', (tester) async {
    final (:config, :server) = await _pumpAndOpenSheet(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(config.showIndicator, isFalse);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });
}
