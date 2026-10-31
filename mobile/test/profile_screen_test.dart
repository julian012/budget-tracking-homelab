import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/screens/profile_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/profile_controller.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/services/theme_controller.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget _buildProfile(ServerConfig config, ValueNotifier<int> refresh) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(
        value: AuthService(
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'uid', email: 'a@b.com')),
        ),
      ),
      ChangeNotifierProvider(create: (_) => ProfileController()),
      ChangeNotifierProvider(create: (_) => ThemeController()),
    ],
    child: MaterialApp(
      home: Scaffold(body: ProfileScreen(refresh: refresh)),
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

  testWidgets('does not render a logout button in the body', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildProfile(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.text('Cerrar sesión'), findsNothing);
  });

  testWidgets('renders empty state when there are no cards', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildProfile(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.text('Sin tarjetas'), findsOneWidget);
    expect(find.text('Sin categorías'), findsNWidgets(2));
  });

  testWidgets('renders the Plantillas Rápidas section with its empty state', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildProfile(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.text('Plantillas Rápidas'), findsOneWidget);
    expect(find.text('Sin plantillas'), findsOneWidget);
  });

  testWidgets('renders the dark mode toggle switch', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildProfile(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.text('Modo oscuro'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('toggling dark mode updates the ThemeController', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildProfile(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MaterialApp));
    final themeController = context.read<ThemeController>();
    expect(themeController.isDark, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(themeController.isDark, isTrue);
  });

  testWidgets('shows a retry snackbar when loading fails', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildProfile(config, ValueNotifier(0)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No se pudo cargar el perfil'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Reintentar'), findsOneWidget);
  });
}
