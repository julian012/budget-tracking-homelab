import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/screens/login_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/services/theme_controller.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

AuthService _buildAuth() {
  return AuthService(
    auth: MockFirebaseAuth(
      signedIn: false,
      mockUser: null,
    ),
  );
}

Widget buildTestableLoginScreen(ServerConfig config, AuthService auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeController()),
    ],
    child: const MaterialApp(home: LoginScreen()),
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

  testWidgets('login screen renders theme toggle (moon in light mode)', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(buildTestableLoginScreen(config, _buildAuth()));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.moon), findsOneWidget);
    expect(find.byIcon(LucideIcons.sun), findsNothing);
  });

  testWidgets('tapping the toggle switches to dark mode', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(buildTestableLoginScreen(config, _buildAuth()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.moon));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.sun), findsOneWidget);
    expect(find.byIcon(LucideIcons.moon), findsNothing);
  });
}
