import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/screens/shared_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/theme/budget_theme.dart';

class _FakeBackend {
  final HttpServer server;
  _FakeBackend(this.server);

  String get url => 'http://127.0.0.1:${server.port}';
}

Future<_FakeBackend> _startBackend() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final backend = _FakeBackend(server);
  server.listen((req) async {
    await utf8.decoder.bind(req).join();
    final res = req.response..headers.contentType = ContentType.json;
    if (req.method == 'GET' && req.uri.path == '/api/shared/summary') {
      res.write(jsonEncode({
        'pending_total': 35000.0,
        'people_count': 1,
        'people': [
          {
            'person': {'id': 'p1', 'name': 'Juan', 'color': '#EF4444', 'icon': '👤'},
            'pending_total': 35000.0,
            'paid_total': 0.0,
            'shared_total': 70000.0,
          },
        ],
      }));
    } else if (req.method == 'GET' && req.uri.path == '/api/people') {
      res.write(jsonEncode([
        {'id': 'p1', 'name': 'Juan', 'color': '#EF4444', 'icon': '👤', 'archived': false},
      ]));
    } else {
      res.statusCode = 404;
      res.write('{}');
    }
    await res.close();
  });
  return backend;
}

Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('SharedScreen carga y muestra resumen + persona', (tester) async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    final backend = (await tester.runAsync(_startBackend))!;
    addTearDown(() => backend.server.close(force: true));

    final config = ServerConfig();
    await config.init();
    await config.setServerUrl(backend.url);
    await config.setShowIndicator(false);
    final auth = AuthService(
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u', email: 'a@b.com')),
    );

    await tester.pumpWidget(MaterialApp(
      theme: BudgetTheme.light,
      home: MultiProvider(
        providers: [
          Provider<AuthService>.value(value: auth),
          ChangeNotifierProvider.value(value: config),
        ],
        child: SharedScreen(refresh: ValueNotifier<int>(0)),
      ),
    ));

    await _settleNetwork(tester);

    expect(find.text('Compartidos'), findsOneWidget);
    expect(find.text('Te deben'), findsOneWidget);
    expect(find.text(r'$35,000.00'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
  });
}
