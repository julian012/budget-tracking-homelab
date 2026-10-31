import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/main.dart';
import 'package:budget_tracking/screens/login_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('BudgetApp widget can be instantiated', (tester) async {
    final config = ServerConfig();
    await config.init();
    await config.setShowIndicator(false);

    final auth = AuthService(auth: MockFirebaseAuth(signedIn: false));

    await tester.pumpWidget(BudgetApp(serverConfig: config, authService: auth));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
