import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budget_tracking/screens/reports_screen.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/services/server_config.dart';
import 'package:budget_tracking/widgets/filter_chips_bar.dart';

Future<ServerConfig> _buildConfig() async {
  final config = ServerConfig();
  await config.init();
  await config.setShowIndicator(false);
  return config;
}

Widget _buildReports(ServerConfig config, ValueNotifier<int> refresh) {
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
      home: Scaffold(body: ReportsScreen(refresh: refresh)),
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

  testWidgets('renders period filters as FilterChipsBar', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildReports(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    expect(find.byType(FilterChipsBar), findsOneWidget);
    expect(find.text('3 meses'), findsOneWidget);
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('7 días'), findsOneWidget);
    expect(find.text('Personalizado'), findsOneWidget);
  });

  testWidgets('selecting a different period updates the selected chip', (tester) async {
    final config = await _buildConfig();
    await tester.pumpWidget(_buildReports(config, ValueNotifier(0)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Este mes'));
    await tester.pumpAndSettle();

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    final quarter = chips.firstWhere((c) => (c.label as Text).data == '3 meses');
    final month = chips.firstWhere((c) => (c.label as Text).data == 'Este mes');
    expect(quarter.selected, isFalse);
    expect(month.selected, isTrue);
  });
}
