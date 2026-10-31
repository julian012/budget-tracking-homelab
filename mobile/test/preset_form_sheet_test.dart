import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/widgets/preset_form_sheet.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';

const _categories = [
  {'id': 'c1', 'name': 'Transporte', 'icon': 'bus', 'color': '#0F52BA'},
  {'id': 'c2', 'name': 'Comida', 'icon': 'utensils', 'color': '#EF4444'},
];

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget buildSheet(ServerConfig config, {Map<String, dynamic>? existing, List<dynamic> cards = const []}) {
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
        body: PresetFormSheet(
          existing: existing,
          categories: _categories,
          cards: cards,
          refresh: ValueNotifier(0),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PresetFormSheet (crear)', () {
    testWidgets('renderiza título "Nueva plantilla" y botón Crear deshabilitado', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config));
      await tester.pumpAndSettle();

      expect(find.text('Nueva plantilla'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear'));
      expect(button.onPressed, isNull);
    });

    testWidgets('habilita Crear con nombre, monto y categoría', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Flota');
      await tester.enterText(find.widgetWithText(TextField, 'Monto'), '25000');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('sin categorías muestra el aviso y mantiene Crear deshabilitado', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: config),
          Provider<AuthService>.value(
            value: AuthService(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'uid', email: 'a@b.com'))),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PresetFormSheet(categories: const [], cards: const [], refresh: ValueNotifier(0)),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Crea una categoría primero'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Flota');
      await tester.pump();
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear'));
      expect(button.onPressed, isNull);
    });
  });

  group('PresetFormSheet (editar)', () {
    testWidgets('pre-rellena nombre, monto y descripción y muestra "Editar plantilla"', (tester) async {
      final config = await _buildConfig();
      await tester.pumpWidget(buildSheet(config, existing: const {
        'id': 'p1',
        'name': 'Flota Tunja-Bogotá',
        'icon': '🚌',
        'amount': 25000,
        'category_id': 'c1',
        'card_id': null,
        'description': 'pasajes ida y vuelta',
      }));
      await tester.pumpAndSettle();

      expect(find.text('Editar plantilla'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Flota Tunja-Bogotá'), findsOneWidget);
      expect(find.text('25.000'), findsOneWidget);
      expect(find.text('pasajes ida y vuelta'), findsOneWidget);
    });
  });
}
