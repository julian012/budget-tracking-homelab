import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/screens/expenses_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/widgets/filter_chips_bar.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget _buildExpenses(ServerConfig config, ValueNotifier<int> refresh) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(
        value: AuthService(
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'uid', email: 'a@b.com')),
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ExpensesScreen(refresh: refresh)),
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

  testWidgets('renders date filters before the search bar', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildExpenses(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.byType(FilterChipsBar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    final filtersTop = tester.getTopLeft(find.byType(FilterChipsBar)).dy;
    final searchTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(filtersTop, lessThan(searchTop));
  });

  testWidgets('renders the date filter options', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildExpenses(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('Mes anterior'), findsOneWidget);
    expect(find.text('Buscar...'), findsOneWidget);
  });

  testWidgets('shows a retry snackbar when loading fails', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildExpenses(config, ValueNotifier(0)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No se pudieron cargar los gastos'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Reintentar'), findsOneWidget);
  });
}
