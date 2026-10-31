import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/widgets/card_form_sheet.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget buildSheet(ServerConfig config, {Map<String, dynamic>? existing}) {
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
        body: CardFormSheet(existing: existing, refresh: ValueNotifier(0)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CardFormSheet (crear)', () {
    testWidgets('renderiza título "Nueva tarjeta" y campos vacíos', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config));
      await tester.pumpAndSettle();

      expect(find.text('Nueva tarjeta'), findsOneWidget);
      expect(find.text('Guardar tarjeta'), findsOneWidget);
    });

    testWidgets('valida nombre vacío antes de guardar', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar tarjeta'));
      await tester.pump();

      expect(find.text('Ingresa el nombre de la tarjeta'), findsOneWidget);
    });
  });

  group('CardFormSheet (editar)', () {
    testWidgets('pre-rellena los datos de la tarjeta existente', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(
        config,
        existing: const {
          'id': 'card-1',
          'name': 'Amex Gold',
          'franchise': 'amex',
          'color': '#1A1C1E',
          'cut_off_day': 20,
          'payment_day': 10,
          'credit_limit': 3000000,
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Editar tarjeta'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Amex Gold'), findsWidgets);
    });
  });
}
