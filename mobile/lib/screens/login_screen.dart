import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../services/theme_controller.dart';
import '../theme/budget_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  bool _serverConnected = false;
  bool _serverChecked = false;
  bool _serverTesting = false;
  String? _serverStatusText;

  @override
  void initState() {
    super.initState();
    final config = context.read<ServerConfig>();
    _serverUrlController.text = config.serverUrl;
    if (config.showIndicator) {
      _checkServerHealth();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkServerHealth() async {
    final config = context.read<ServerConfig>();
    if (!config.showIndicator) return;
    final api = ApiService(config.serverUrl);
    final result = await api.healthCheck();
    if (mounted) {
      setState(() {
        _serverConnected = result.ok;
        _serverChecked = true;
        _serverStatusText = result.ok ? 'Conectado' : 'Sin conexión';
      });
    }
  }

  Future<void> _testServerHealth() async {
    setState(() {
      _serverTesting = true;
      _serverStatusText = null;
    });
    final config = context.read<ServerConfig>();
    final api = ApiService(config.serverUrl);
    final result = await api.healthCheck();
    if (mounted) {
      setState(() {
        _serverTesting = false;
        _serverConnected = result.ok;
        _serverChecked = true;
        _serverStatusText = result.ok
            ? 'Conexión exitosa'
            : 'Error: ${result.error ?? "sin respuesta"}';
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      if (_isLogin) {
        await auth.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await auth.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (e) {
      setState(() => _error = 'Error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (e) {
      setState(() => _error = 'Error al conectar con Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El email no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'user-not-found':
        return 'No existe una cuenta con este email.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este email.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión. Verifica tu internet.';
      default:
        return e.message ?? 'Error de autenticación.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeController>().isDark
                  ? LucideIcons.sun
                  : LucideIcons.moon,
            ),
            tooltip: 'Cambiar tema',
            onPressed: () {
              final isDark = context.read<ThemeController>().isDark;
              context.read<ThemeController>().setDark(!isDark);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BudgetTheme.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.wallet, size: 72, color: colorScheme.primary),
                const SizedBox(height: 16),
                if (!kDebugMode)
                  Text('Budget Tracker', style: theme.textTheme.headlineMedium)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Budget Tracker',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(width: 8),
                      if (_serverChecked) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _serverConnected
                                ? colorScheme.income
                                : colorScheme.expense,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _serverStatusText ?? '',
                          style: TextStyle(
                            color: _serverConnected
                                ? colorScheme.income
                                : colorScheme.expense,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  'Controla tus finanzas personales',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(LucideIcons.mail),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(LucideIcons.lock),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BudgetTheme.borderRadiusMedium,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BudgetTheme.borderRadiusMedium,
                    ),
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  collapsedBackgroundColor: colorScheme.surfaceContainerHighest,
                  leading: Icon(
                    LucideIcons.settings,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    'Configurar servidor',
                    style: theme.textTheme.titleMedium,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: TextField(
                        controller: _serverUrlController,
                        style: theme.textTheme.bodySmall,
                        decoration: const InputDecoration(
                          labelText: 'URL del servidor',
                          prefixIcon: Icon(LucideIcons.link, size: 18),
                        ),
                        onChanged: (value) {
                          context.read<ServerConfig>().setServerUrl(
                            value.trim(),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ej: http://192.168.1.100:4000',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _serverTesting
                                  ? null
                                  : _testServerHealth,
                              icon: _serverTesting
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : Icon(LucideIcons.wifi, size: 16),
                              label: Text(
                                _serverTesting
                                    ? 'Probando...'
                                    : 'Probar conexión',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    BudgetTheme.borderRadiusSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_serverStatusText != null && !_serverTesting)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _serverConnected
                                        ? LucideIcons.circle_check
                                        : LucideIcons.circle_alert,
                                    size: 16,
                                    color: _serverConnected
                                        ? colorScheme.income
                                        : colorScheme.expense,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _serverStatusText!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _serverConnected
                                            ? colorScheme.income
                                            : colorScheme.expense,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        top: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.circle,
                            color: colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mostrar indicador de conexión',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: context.watch<ServerConfig>().showIndicator,
                            onChanged: (value) {
                              final config = context.read<ServerConfig>();
                              config.setShowIndicator(value);
                              if (value) {
                                _checkServerHealth();
                              } else {
                                setState(() {
                                  _serverChecked = false;
                                  _serverStatusText = null;
                                });
                              }
                            },
                            activeThumbColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: colorScheme.expense, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: const Icon(LucideIcons.log_in),
                  label: const Text('Continuar con Google'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _error = null;
                  }),
                  child: Text(
                    _isLogin
                        ? '¿No tienes cuenta? Regístrate'
                        : '¿Ya tienes cuenta? Inicia sesión',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
