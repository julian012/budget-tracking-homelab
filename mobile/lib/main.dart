import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/offline_queue_service.dart';
import 'services/profile_controller.dart';
import 'services/server_config.dart';
import 'services/theme_controller.dart';
import 'theme/budget_theme.dart';
import 'utils/default_categories.dart';

final routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es', null);

  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  final serverConfig = ServerConfig();
  await serverConfig.init();

  final themeController = ThemeController();
  await themeController.init();

  final offlineQueue = OfflineQueueService();
  await offlineQueue.init();

  runApp(BudgetApp(serverConfig: serverConfig, themeController: themeController, offlineQueue: offlineQueue));
}

class BudgetApp extends StatelessWidget {
  final ServerConfig serverConfig;
  final ThemeController? themeController;
  final AuthService? authService;
  final OfflineQueueService? offlineQueue;

  const BudgetApp({
    super.key,
    required this.serverConfig,
    this.themeController,
    this.authService,
    this.offlineQueue,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serverConfig),
        ChangeNotifierProvider(create: (_) => themeController ?? ThemeController()),
        Provider<AuthService>(create: (_) => authService ?? AuthService()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => offlineQueue ?? OfflineQueueService()),
      ],
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<ThemeController>().themeMode;
          return MaterialApp(
            title: 'Budget Tracker',
            debugShowCheckedModeBanner: false,
            theme: BudgetTheme.light,
            darkTheme: BudgetTheme.dark,
            themeMode: themeMode,
            navigatorObservers: [routeObserver],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('es')],
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _seeded = false;

  Future<void> _ensureCategories() async {
    if (_seeded) return;
    _seeded = true;
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      if (token == null) return;
      await ensureDefaultCategories(token, config.serverUrl);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
          );
        }
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCategories());
          return const HomeScreen();
        }
        _seeded = false;
        return const LoginScreen();
      },
    );
  }
}
