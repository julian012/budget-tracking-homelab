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

final Map<String, dynamic> _flota = {
  'id': 'p-flota',
  'name': 'Flota',
  'icon': '🚎',
  'amount': 25000,
  'category_id': 'c1',
  'card_id': null,
  'description': 'pasajes',
};

final Map<String, dynamic> _casino = {
  'id': 'p-casino',
  'name': 'Casino',
  'icon': '🎰',
  'amount': 18796,
  'category_id': 'c1',
  'card_id': null,
  'description': '',
};

/// Backend falso mínimo para ejercitar el flujo real (sin mockear ApiService):
/// el FAB de Inicio lista las plantillas y al tocarlas abre el formulario de
/// gasto con todos los datos precargados.
class _FakeBackend {
  final HttpServer server;
  final List<String> requests = [];
  List<Map<String, dynamic>> presets;

  _FakeBackend(this.server, {required this.presets}) {
    server.listen((req) async {
      requests.add('${req.method} ${req.uri.path}');
      await utf8.decoder.bind(req).join();
      final res = req.response;
      res.headers.contentType = ContentType.json;
      if (req.method == 'GET' && req.uri.path == '/api/presets') {
        res.write(jsonEncode(presets));
      } else if (req.method == 'GET' && req.uri.path == '/api/categories') {
        res.write(jsonEncode([
          {'id': 'c1', 'name': 'Transporte', 'icon': 'bus', 'color': '#0F52BA', 'type': 0, 'requires_description': true, 'default_amount': 9999},
          {'id': 'c2', 'name': 'Comida', 'icon': 'utensils', 'color': '#E53935', 'type': 0, 'requires_description': true, 'default_amount': 0},
        ]));
      } else if (req.method == 'GET' && req.uri.path == '/api/cards') {
        res.write(jsonEncode([]));
      } else if (req.method == 'GET' && req.uri.path == '/api/expenses') {
        res.write(jsonEncode([]));
      } else if (req.method == 'GET' && req.uri.path == '/api/stats') {
        res.write(jsonEncode({}));
      } else if (req.method == 'POST' && req.uri.path == '/api/expenses') {
        res.statusCode = 201;
        res.write(jsonEncode({'id': 'new-1'}));
      } else {
        res.statusCode = 500;
        res.write('{}');
      }
      await res.close();
    });
  }

  String get url => 'http://127.0.0.1:${server.port}';
}

Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

Future<_FakeBackend> _pumpHome(WidgetTester tester, List<Map<String, dynamic>> presets) async {
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  final backend = (await tester.runAsync(() async => _FakeBackend(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), presets: List.of(presets))))!;
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
  return backend;
}

Future<void> _openFab(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.plus));
  await _settleNetwork(tester);
  await tester.pumpAndSettle();
}

Future<void> _closeFab(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.x));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  testWidgets('el FAB lista todas las plantillas (chips con emoji + nombre)', (tester) async {
    await _pumpHome(tester, [_flota, _casino]);
    await _openFab(tester);

    expect(find.byTooltip('Flota'), findsOneWidget);
    expect(find.byTooltip('Casino'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refetchea al reabrir el FAB, sin caché stale (#122)', (tester) async {
    final backend = await _pumpHome(tester, [_flota]);
    await _openFab(tester);
    expect(find.byTooltip('Flota'), findsOneWidget);
    expect(find.byTooltip('Casino'), findsNothing);

    await _closeFab(tester);
    // El usuario crea "Casino" desde Perfil mientras el FAB estaba cerrado.
    backend.presets = [_casino, _flota];

    await _openFab(tester);
    expect(find.byTooltip('Flota'), findsOneWidget);
    expect(find.byTooltip('Casino'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al tocar una plantilla abre el formulario precargado (monto, categoría y descripción)', (tester) async {
    await _pumpHome(tester, [_flota, _casino]);
    await _openFab(tester);

    await tester.tap(find.byTooltip('Flota'));
    await _settleNetwork(tester);
    await tester.pumpAndSettle();

    expect(find.text('Nuevo gasto'), findsOneWidget);
    // Monto de la plantilla (no el default_amount de la categoría, que es 9999).
    expect(find.text('25.000'), findsOneWidget);
    expect(find.text('9999'), findsNothing);
    // Descripción precargada.
    expect(find.text('pasajes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
