import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/screens/home_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/offline_queue_service.dart';
import 'package:budget_tracking/services/profile_controller.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/services/theme_controller.dart';
import 'package:budget_tracking/theme/budget_theme.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

MockFirebaseAuth _mockAuth({bool signedIn = true}) {
  return MockFirebaseAuth(
    signedIn: signedIn,
    mockUser: signedIn
        ? MockUser(uid: 'test-uid', email: 'test@example.com', displayName: 'Test')
        : null,
  );
}

AuthService _buildAuth({MockFirebaseAuth? mock}) {
  return AuthService(auth: mock ?? _mockAuth());
}

/// Simula el SDK intentando refrescar el token sin conexión: nunca resuelve.
// ignore: must_be_immutable
class _HangingTokenUser extends MockUser {
  _HangingTokenUser() : super(uid: 'test-uid', email: 'test@example.com');

  @override
  Future<String> getIdToken([bool forceRefresh = false]) => Completer<String>().future;
}

/// AuthService cuyo token falla como sin-conexión (TimeoutException) mientras
/// [offline] sea true; luego responde con un token normal.
class _SwitchableAuth extends AuthService {
  bool offline = false;
  _SwitchableAuth({required MockFirebaseAuth auth}) : super(auth: auth);

  @override
  Future<String?> getToken() async {
    if (offline) throw TimeoutException('sin conexión');
    return super.getToken();
  }
}

/// Token expirado sin red: el SDK falla rápido con network-request-failed.
class _NetworkFailAuth extends AuthService {
  _NetworkFailAuth({required MockFirebaseAuth auth}) : super(auth: auth);

  @override
  Future<String?> getToken() async => throw FirebaseAuthException(code: 'network-request-failed');
}

class _SignOutSpy extends AuthService {
  int calls = 0;
  _SignOutSpy({required MockFirebaseAuth auth}) : super(auth: auth);

  @override
  Future<void> signOut() async {
    calls++;
    await super.signOut();
  }
}

Widget buildTestableHomeScreen(ServerConfig config, AuthService auth, {OfflineQueueService? offlineQueue, ThemeData? theme}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ProfileController()),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider.value(value: offlineQueue ?? OfflineQueueService()),
    ],
    child: MaterialApp(
      theme: theme,
      home: const HomeScreen(),
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

  testWidgets('HomeScreen renders NavigationBar with all tabs', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth()));
    await tester.pumpAndSettle();

    expect(find.text('Budget Tracker'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('HomeScreen shows dashboard by default', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('does not show logout icon on the home tab', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth()));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.log_out), findsNothing);
    expect(find.byTooltip('Cerrar sesión'), findsNothing);
  });

  testWidgets('shows logout icon on the profile tab', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.markDataLoaded();
    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.log_out), findsOneWidget);
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('tapping logout signs out via AuthService', (tester) async {
    final config = await _buildConfig();
    final spy = _SignOutSpy(auth: _mockAuth());
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.markDataLoaded();
    await tester.pumpWidget(buildTestableHomeScreen(config, spy, offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(spy.calls, 0);
    await tester.tap(find.byIcon(LucideIcons.log_out));
    await tester.pumpAndSettle();

    expect(spy.calls, 1);
  });

  testWidgets('Gastos/Reportes tabs are gated when no data has ever loaded', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    expect(offlineQueue.hasEverLoadedData, isFalse);

    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();

    expect(find.text('Necesitas conexión la primera vez para cargar tus datos'), findsOneWidget);
    // No navegó a Gastos: su buscador no debería aparecer.
    expect(find.text('Buscar...'), findsNothing);
  });

  testWidgets('Perfil tab is gated when no data has ever loaded', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    expect(offlineQueue.hasEverLoadedData, isFalse);

    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Necesitas conexión la primera vez para cargar tus datos'), findsOneWidget);
    // No navegó a Perfil: su icono de logout no debería aparecer.
    expect(find.byIcon(LucideIcons.log_out), findsNothing);
  });

  testWidgets('Gastos/Reportes tabs work normally once data has loaded', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.markDataLoaded();

    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();

    expect(find.text('Necesitas conexión la primera vez para cargar tus datos'), findsNothing);
    // Sí navegó: el selector de período de Reportes está visible.
    expect(find.text('3 meses'), findsOneWidget);
  });

  testWidgets('shows a pending-sync banner on the dashboard when there are pending expenses', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 35000, expenseDate: '2026-08-25', description: 'Agua');

    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    expect(find.text('Tienes 1 gasto pendiente de completar'), findsOneWidget);
  });

  testWidgets('does not show the pending-sync banner when there is nothing pending', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();

    await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue));
    await tester.pumpAndSettle();

    expect(find.textContaining('pendiente'), findsNothing);
  });

  // Regresión #81: el tema real define FilledButton con minimumSize.width =
  // infinity; dentro del Row del banner eso rompía el layout de TODO el
  // Dashboard (pantalla en negro). Con el tema por defecto de Flutter no se veía.
  for (final entry in {'claro': BudgetTheme.light, 'oscuro': BudgetTheme.dark}.entries) {
    testWidgets('el banner de pendientes no rompe el layout con el tema real (${entry.key})', (tester) async {
      final config = await _buildConfig();
      final offlineQueue = OfflineQueueService();
      await offlineQueue.init();
      await offlineQueue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');

      await tester.pumpWidget(buildTestableHomeScreen(config, _buildAuth(), offlineQueue: offlineQueue, theme: entry.value));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tienes 1 gasto pendiente de completar'), findsOneWidget);

      final button = find.widgetWithText(FilledButton, 'Completar');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).width, lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio));
      // El resto del Dashboard también debe haberse layouteado.
      expect(tester.renderObject<RenderBox>(find.byType(SingleChildScrollView).first).hasSize, isTrue);
    });
  }

  // Regresión #81 (escenario completo): sin conexión, el refresh del token
  // nunca resuelve. Inicio debe terminar usable (card "sin conexión" + lista de
  // pendientes), no quedarse cargando para siempre.
  // #99: sin conexión no se puede completar, así que no hay botón «Completar»:
  // se muestran los pendientes como lista de solo lectura.
  testWidgets('sin conexión y con token colgado, Inicio sale del estado de carga y lista los pendientes sin botón', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');
    final auth = AuthService(
      auth: MockFirebaseAuth(signedIn: true, mockUser: _HangingTokenUser()),
      tokenTimeout: const Duration(milliseconds: 50),
    );

    await tester.pumpWidget(buildTestableHomeScreen(config, auth, offlineQueue: offlineQueue, theme: BudgetTheme.dark));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No hay conexión para cargar el resumen'), findsOneWidget);
    expect(find.text('Tienes 1 gasto pendiente de completar'), findsOneWidget);
    expect(find.text('Podrás completarlo cuando vuelva la conexión'), findsOneWidget);
    // La lista de solo lectura muestra el pendiente…
    expect(find.text('\$ 22.000'), findsOneWidget);
    expect(find.textContaining('Politas'), findsOneWidget);
    // …y no hay botón para completarlo.
    expect(find.widgetWithText(FilledButton, 'Completar'), findsNothing);
  });

  testWidgets('sin conexión lista todos los pendientes (plural)', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');
    await offlineQueue.addPending(amount: 13000, expenseDate: '2026-09-21', description: 'Prueba');
    final auth = AuthService(
      auth: MockFirebaseAuth(signedIn: true, mockUser: _HangingTokenUser()),
      tokenTimeout: const Duration(milliseconds: 50),
    );

    await tester.pumpWidget(buildTestableHomeScreen(config, auth, offlineQueue: offlineQueue, theme: BudgetTheme.dark));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tienes 2 gastos pendientes de completar'), findsOneWidget);
    expect(find.text('Podrás completarlos cuando vuelva la conexión'), findsOneWidget);
    expect(find.textContaining('Politas'), findsOneWidget);
    expect(find.textContaining('Prueba'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Completar'), findsNothing);
  });

  // Al reintentar con conexión (aquí el error ya no es de red: en tests el HTTP
  // devuelve 400) vuelve el banner con el botón.
  testWidgets('al recuperar la conexión (reintentar) vuelve el botón «Completar»', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');
    final auth = _SwitchableAuth(auth: _mockAuth())..offline = true;

    await tester.pumpWidget(buildTestableHomeScreen(config, auth, offlineQueue: offlineQueue, theme: BudgetTheme.dark));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Completar'), findsNothing);

    auth.offline = false;
    await tester.tap(find.byIcon(LucideIcons.rotate_cw));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Completar'), findsOneWidget);
    expect(find.text('Podrás completarlo cuando vuelva la conexión'), findsNothing);
  });

  // #99, caso real en dispositivo: token expirado + modo avión → FirebaseAuthException
  // (network-request-failed), no un timeout. Debe tratarse como sin conexión.
  testWidgets('sin conexión con token expirado (network-request-failed): mensaje amigable y lista sin botón', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');

    await tester.pumpWidget(buildTestableHomeScreen(config, _NetworkFailAuth(auth: _mockAuth()), offlineQueue: offlineQueue, theme: BudgetTheme.dark));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No hay conexión para cargar el resumen'), findsOneWidget);
    expect(find.textContaining('firebase_auth'), findsNothing);
    expect(find.textContaining('Politas'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Completar'), findsNothing);
  });

  // #101: sin conexión también se puede descartar (no requiere red).
  testWidgets('sin conexión se puede descartar un pendiente desde la lista; al descartar el último desaparece el banner', (tester) async {
    final config = await _buildConfig();
    final offlineQueue = OfflineQueueService();
    await offlineQueue.init();
    await offlineQueue.addPending(amount: 22000, expenseDate: '2026-09-19', description: 'Politas');
    await offlineQueue.addPending(amount: 13000, expenseDate: '2026-09-21', description: 'Prueba');

    await tester.pumpWidget(buildTestableHomeScreen(config, _NetworkFailAuth(auth: _mockAuth()), offlineQueue: offlineQueue, theme: BudgetTheme.dark));
    await tester.pumpAndSettle();
    expect(find.text('Tienes 2 gastos pendientes de completar'), findsOneWidget);
    expect(find.byTooltip('Descartar'), findsNWidgets(2));

    // Descarta "Prueba" (el segundo) → queda solo Politas.
    await tester.tap(find.byTooltip('Descartar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DESCARTAR'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(offlineQueue.pending.map((p) => p['description']), ['Politas']);
    expect(find.text('Tienes 1 gasto pendiente de completar'), findsOneWidget);
    expect(find.textContaining('Prueba'), findsNothing);
    expect(find.textContaining('Politas'), findsOneWidget);

    // Descarta el último → desaparece el banner.
    await tester.tap(find.byTooltip('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DESCARTAR'));
    await tester.pumpAndSettle();

    expect(offlineQueue.pending, isEmpty);
    expect(find.textContaining('pendiente'), findsNothing);
  });
}
