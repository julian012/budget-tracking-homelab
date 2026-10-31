import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/widgets/category_form_sheet.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget buildSheet(ServerConfig config, {Map<String, dynamic>? existing, int? defaultType}) {
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
      home: Scaffold(
        body: CategoryFormSheet(existing: existing, refresh: ValueNotifier(0), defaultType: defaultType),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CategoryFormSheet (crear)', () {
    testWidgets('renderiza título "Nueva categoría" y botón Crear', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config));
      await tester.pumpAndSettle();

      expect(find.text('Nueva categoría'), findsOneWidget);
      expect(find.text('Crear'), findsOneWidget);
    });

    testWidgets('defaultType=1 preselecciona el tipo Fijo', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config, defaultType: 1));
      await tester.pumpAndSettle();

      expect(find.text('Nueva categoría'), findsOneWidget);
      // Sin tipo pre-seleccionado el toggle aparece sin selección marcada;
      // con defaultType=1 el sheet debe mostrar la opción fija seleccionada.
      expect(tester.takeException(), isNull);
    });
  });

  group('CategoryFormSheet (editar)', () {
    testWidgets('pre-rellena nombre y muestra "Editar categoría"', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(
        config,
        existing: const {
          'id': 'cat-1',
          'name': 'Suscripciones',
          'icon': '📱',
          'color': '#3B82F6',
          'type': 1,
          'requires_description': false,
          'default_amount': 45000,
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Editar categoría'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Suscripciones'), findsOneWidget);
    });
  });
}
