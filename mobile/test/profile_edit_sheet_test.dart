import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/widgets/profile_edit_sheet.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget buildSheet(ServerConfig config, Map<String, dynamic> profile) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(
        value: AuthService(auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid', email: 'a@b.com'),
        )),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ProfileEditSheet(profile: profile, refresh: ValueNotifier(0))),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProfileEditSheet', () {
    testWidgets('renderiza título "Editar perfil" y botón Guardar', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config, const {'display_name': '', 'avatar': ''}));
      await tester.pumpAndSettle();

      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
    });

    testWidgets('pre-rellena display_name existente', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config, const {'display_name': 'User', 'avatar': '😎'}));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'User');
    });

    testWidgets('avatar vacío no crashea y muestra el grid de presets', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config, const {'display_name': '', 'avatar': ''}));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // El primer preset (👤) debe estar disponible para seleccionar.
      expect(find.text('👤'), findsWidgets);
    });
  });
}
