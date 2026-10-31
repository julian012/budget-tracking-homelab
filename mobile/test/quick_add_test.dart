import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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

/// Servidor HTTP local mínimo: lo justo para que el Inicio arme los accesos
/// rápidos por categoría y acepte `POST /api/expenses`. Así se reproduce el
/// flujo real (sin mockear ApiService) sin tocar producción.
class _FakeBackend {
  final HttpServer server;
  final List<String> requests = [];
  bool failCreate = false;

  _FakeBackend(this.server) {
    server.listen((req) async {
      requests.add('${req.method} ${req.uri.path}');
      await utf8.decoder.bind(req).join();
      final res = req.response;
      res.headers.contentType = ContentType.json;
      if (req.method == 'POST' && req.uri.path == '/api/expenses') {
        res.statusCode = failCreate ? 500 : 201;
        res.write(jsonEncode({'id': 'new-1'}));
      } else if (req.method == 'GET' && req.uri.path == '/api/presets') {
        // Sin plantillas: el FAB cae a las últimas categorías (comportamiento previo).
        res.write(jsonEncode([]));
      } else if (req.method == 'GET' && req.uri.path == '/api/expenses') {
        res.write(jsonEncode([
          {
            'id': 'e1',
            'amount': 5000,
            'description': 'x',
            'expense_date': '2026-09-20',
            'category': {'id': 'c1', 'name': 'Comida', 'icon': 'utensils', 'color': '#E53935'},
          },
        ]));
      } else {
        // stats/cards/perfil: el Inicio lo tolera (muestra su card de error).
        res.statusCode = 500;
        res.write('{}');
      }
      await res.close();
    });
  }

  String get url => 'http://127.0.0.1:${server.port}';
}

/// El token del mock usa timers del reloj falso y el HTTP usa sockets reales:
/// se alternan ambos para que la cadena token → petición → respuesta termine.
Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

/// Monta el Inicio contra el servidor falso y abre el menú rápido.
Future<_FakeBackend> _pumpHomeWithQuickMenu(WidgetTester tester) async {
  HttpOverrides.global = null; // sockets reales (flutter_test los bloquea por defecto)
  SharedPreferences.setMockInitialValues({});

  final backend = (await tester.runAsync(() async => _FakeBackend(await HttpServer.bind(InternetAddress.loopbackIPv4, 0))))!;
  addTearDown(() => backend.server.close(force: true));

  final config = ServerConfig();
  await config.init();
  await config.setServerUrl(backend.url);
  await config.setShowIndicator(false);
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

  await tester.tap(find.byIcon(LucideIcons.plus));
  await _settleNetwork(tester);
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  // Reportado en #87 (y antes en #72): al guardar desde el mini formulario de
  // carga rápida (solo monto, sin descripción) la app mostraba la pantalla roja
  // "'_dependents.isEmpty': is not true". Causa: el TextEditingController se
  // destruía en el pop del sheet, con el TextField todavía animándose.
  testWidgets('guardar desde el mini formulario de carga rápida no lanza excepciones', (tester) async {
    final backend = await _pumpHomeWithQuickMenu(tester);
    expect(find.byTooltip('Comida'), findsOneWidget);

    // Mini formulario: solo el monto (sin descripción) y Guardar.
    await tester.tap(find.byTooltip('Comida'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await _settleNetwork(tester);
    await tester.pump(const Duration(milliseconds: 600)); // animación de salida del sheet

    expect(backend.requests, contains('POST /api/expenses'));
    expect(tester.takeException(), isNull);
    expect(find.text('Gasto guardado'), findsOneWidget);

    // Deja terminar el SnackBar y cualquier animación pendiente sin excepciones.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('si el servidor falla, el sheet sigue abierto y avisa (sin excepciones)', (tester) async {
    final backend = await _pumpHomeWithQuickMenu(tester);
    backend.failCreate = true;

    await tester.tap(find.byTooltip('Comida'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await _settleNetwork(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo guardar el gasto'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget); // el sheet no se cerró
    expect(find.text('Gasto guardado'), findsNothing);
  });

  testWidgets('con monto vacío pide un monto válido y no llama al servidor', (tester) async {
    final backend = await _pumpHomeWithQuickMenu(tester);

    await tester.tap(find.byTooltip('Comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Ingresa un monto válido'), findsOneWidget);
    expect(backend.requests.where((r) => r.startsWith('POST')), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
