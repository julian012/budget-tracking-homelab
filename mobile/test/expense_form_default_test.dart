import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/widgets/expense_form_sheet.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/services/theme_controller.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget _buildExpenseForm(ServerConfig config) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: config),
      Provider<AuthService>.value(
        value: AuthService(auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid', email: 'a@b.com'),
        )),
      ),
      ChangeNotifierProvider(create: (_) => ThemeController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ExpenseFormSheet(
          refresh: ValueNotifier(0),
          onSaved: () {},
        ),
      ),
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

  testWidgets('expense form renders without crash on initial load', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildExpenseForm(config));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo gasto'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('expense form shows amount field after loading state', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildExpenseForm(config));
    await tester.pumpAndSettle();

    // The form should transition from loading to loaded state
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsWidgets);
  });
}
