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

/// Servidor local LENTO: responde 500 tras [delay]. Simula una red lenta o un
/// servidor caído en la que el usuario navega mientras los fetch siguen pendientes.
Future<HttpServer> _startSlowFailingServer(Duration delay, List<String> hits) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    hits.add('${req.method} ${req.uri.path}');
    await req.drain<void>();
    await Future<void>.delayed(delay);
    req.response.statusCode = 500;
    req.response.write('{}');
    await req.response.close();
  });
  return server;
}

/// El token del mock usa timers del reloj falso y el HTTP usa sockets reales:
/// se alternan ambos para que la cadena termine.
Future<void> _settleNetwork(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  // #76: Gastos/Reportes/Perfil se construyen (y hacen su fetch) al abrir la app,
  // aunque no sean la pestaña visible. Si el fetch falla cuando el usuario ya está
  // en otra pestaña, el `catch` muestra un SnackBar sobre un elemento que puede
  // estar inactivo.
  testWidgets('cambiar de pestaña con fetch lento que termina en error no lanza excepciones (#76)', (tester) async {
    HttpOverrides.global = null; // sockets reales
    SharedPreferences.setMockInitialValues({});

    final hits = <String>[];
    final server = (await tester.runAsync(() => _startSlowFailingServer(const Duration(milliseconds: 500), hits)))!;
    addTearDown(() => server.close(force: true));

    final config = ServerConfig();
    await config.init();
    await config.setServerUrl('http://127.0.0.1:${server.port}');
    await config.setShowIndicator(false);
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.markDataLoaded(); // evita el bloqueo de pestañas sin datos previos
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

    // Navega rápido entre pestañas mientras los fetch siguen pendientes.
    Future<void> goTo(String label) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pump(const Duration(milliseconds: 60));
    }

    for (final tab in ['Gastos', 'Reportes', 'Perfil', 'Inicio', 'Reportes', 'Perfil']) {
      await goTo(tab);
    }

    // Los fetch terminan en error con el usuario en otra pestaña.
    await _settleNetwork(tester);

    // El escenario realmente se ejerció: las pestañas pidieron datos (Inicio, Gastos,
    // Perfil…) y sus `catch` mostraron SnackBars de error.
    expect(hits, isNotEmpty);
    expect(hits.any((h) => h.contains('/api/expenses')), isTrue);
    expect(find.byType(SnackBar), findsWidgets);

    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}
