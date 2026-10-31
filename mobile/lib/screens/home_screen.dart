import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/profile_controller.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/connectivity_error.dart';
import '../utils/expense_grouping.dart';
import '../utils/expense_sort.dart';
import '../utils/icon_helper.dart';
import '../utils/recent_categories.dart';
import '../utils/stats_sort.dart';
import '../widgets/expense_form_sheet.dart';
import '../widgets/filter_chips_bar.dart';
import '../widgets/pending_expenses_sheet.dart';
import '../main.dart' show routeObserver;
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'shared_screen.dart';
import 'profile_screen.dart';

/// Mini formulario de carga rápida (solo monto) para una categoría.
///
/// El TextEditingController vive en el State y se destruye en `dispose()`, es
/// decir cuando el sheet ya se desmontó tras su animación de salida. Antes se
/// destruía con `showModalBottomSheet(...).whenComplete(...)`, pero ese Future
/// se completa en el `Navigator.pop`, con el sheet todavía animándose y el
/// teclado cerrándose: el TextField se reconstruía con un controller ya
/// destruido y la app terminaba en la pantalla roja `_dependents.isEmpty` (#87).
class _QuickAddSheet extends StatefulWidget {
  final Map<String, dynamic> cat;
  const _QuickAddSheet({required this.cat});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _amountCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(raw.isEmpty ? '0' : raw);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      if (token == null) {
        if (mounted) setState(() { _saving = false; _error = 'No autenticado'; });
        return;
      }
      await ApiService(config.serverUrl).createExpense(token, {
        'amount': amount,
        'description': '',
        'category_id': widget.cat['id'],
        'expense_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'source': 'form',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = isConnectivityError(e)
            ? 'Sin conexión. Inténtalo de nuevo cuando vuelva.'
            : 'No se pudo guardar el gasto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = widget.cat;
    return Padding(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Row(children: [
          categoryIconWidget(cat['icon']?.toString(), size: 22, color: adaptCategoryColor(parseHexColor(cat['color']?.toString()), context)),
          const SizedBox(width: 8),
          Text(cat['name'] as String? ?? '', style: theme.textTheme.titleMedium),
          const Spacer(),
          IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context, false)),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: theme.textTheme.headlineMedium,
          decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
          inputFormatters: [_ThousandsFormatter()],
          autofocus: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.expense, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ]),
    );
  }
}

/// Sheet «Configurar servidor» (solo debug): URL, probar conexión e indicador.
///
/// Es un StatefulWidget dueño de su TextEditingController (se destruye en
/// `dispose()`, con el sheet ya desmontado). Antes se destruía con
/// `showModalBottomSheet(...).whenComplete(...)`, que se completa en el
/// `Navigator.pop` con el sheet aún animándose → pantalla roja
/// `_dependents.isEmpty` al pulsar «Guardar» (#75). También se espera
/// (`await`) a que la URL se persista antes de cerrar.
class _ServerConfigSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final ValueChanged<bool> onShowIndicatorChanged;
  const _ServerConfigSheet({required this.onSaved, required this.onShowIndicatorChanged});

  @override
  State<_ServerConfigSheet> createState() => _ServerConfigSheetState();
}

class _ServerConfigSheetState extends State<_ServerConfigSheet> {
  late final TextEditingController _urlCtrl;
  bool _testing = false;
  bool _testOk = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: context.read<ServerConfig>().serverUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() { _testing = true; _testResult = null; });
    final result = await ApiService(_urlCtrl.text.trim()).healthCheck();
    if (!mounted) return; // el sheet pudo cerrarse mientras probaba
    setState(() {
      _testing = false;
      _testOk = result.ok;
      _testResult = result.ok ? 'Conexión exitosa' : 'Error: ${result.error ?? "sin respuesta"}';
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<ServerConfig>().setServerUrl(_urlCtrl.text.trim());
    if (!mounted) return;
    navigator.pop();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final config = context.watch<ServerConfig>();
    return Padding(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: colors.textSecondary, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Text('Configurar servidor', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL del servidor',
              prefixIcon: Icon(LucideIcons.link, size: 18),
              hintText: 'https://api.example.com',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                : const Icon(LucideIcons.wifi, size: 16),
            label: Text(_testing ? 'Probando...' : 'Probar conexión'),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!, style: TextStyle(color: _testOk ? colors.income : colors.expense, fontSize: 13)),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar indicador', style: TextStyle(fontSize: 14)),
            value: config.showIndicator,
            activeThumbColor: colors.primary,
            onChanged: (v) {
              config.setShowIndicator(v);
              widget.onShowIndicatorChanged(v);
            },
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    final formatted = NumberFormat.decimalPattern('es_CO').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  int _currentIndex = 0;
  bool _serverConnected = false;
  bool _serverChecked = false;
  bool _fabOpen = false;
  bool _nestedRouteActive = false;
  Timer? _pollTimer;
  final ValueNotifier<int> _refresh = ValueNotifier(0);
  final PageController _pageCtrl = PageController();
  List<Map<String, dynamic>> _recentCategories = [];
  List<Map<String, dynamic>> _presets = [];
  bool _loadingCategories = false;
  bool _loadingPresets = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
      _loadProfileEarly();
    });
  }

  Future<void> _loadProfileEarly() async {
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final profile = await ApiService(url).getProfile(token);
      if (mounted) context.read<ProfileController>().update(profile);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => _nestedRouteActive = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _nestedRouteActive = false);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pollTimer?.cancel();
    _refresh.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    final config = context.read<ServerConfig>();
    if (config.showIndicator) _checkHealth();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (config.showIndicator) _checkHealth();
    });
  }

  Future<void> _checkHealth() async {
    final config = context.read<ServerConfig>();
    final result = await ApiService(config.serverUrl).healthCheck();
    if (mounted) {
      setState(() {
        _serverConnected = result.ok;
        _serverChecked = true;
      });
    }
  }

  void _notifyRefresh() => _refresh.value++;

  Future<void> _openServerConfig() async {
    final config = context.read<ServerConfig>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => _ServerConfigSheet(
        onSaved: () {
          if (config.showIndicator) _checkHealth();
        },
        onShowIndicatorChanged: (show) {
          if (show) {
            _checkHealth();
          } else if (mounted) {
            setState(() => _serverChecked = false);
          }
        },
      ),
    );
  }

  Future<void> _showExpenseForm() async {
    setState(() => _fabOpen = false);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => ExpenseFormSheet(refresh: _refresh, onSaved: _notifyRefresh),
    );
  }

  void _openSharedTab() {
    setState(() => _currentIndex = 3);
    _pageCtrl.animateToPage(3, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _showComingSoon(String feature) {
    setState(() => _fabOpen = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature estará disponible próximamente')),
    );
  }

  Future<void> _loadRecentCategories() async {
    if (_loadingCategories) return;
    setState(() => _loadingCategories = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) { setState(() => _loadingCategories = false); return; }
      final expenses = await ApiService(url).getExpenses(token);
      final recent = extractRecentCategories(expenses);
      if (mounted) setState(() { _recentCategories = recent; _loadingCategories = false; });
    } catch (_) { if (mounted) setState(() => _loadingCategories = false); }
  }

  /// Carga las plantillas del usuario para el menú del FAB. Si no tiene
  /// ninguna, cae a las últimas categorías usadas (comportamiento anterior).
  Future<void> _loadFabItems() async {
    // Se refetchea en cada apertura del FAB: no se cachea la lista, porque el
    // usuario puede crear/editar/borrar plantillas desde Perfil y antes quedaba
    // pegada la primera carga (mostraba solo 1 plantilla, #122).
    if (_loadingPresets) return;
    setState(() => _loadingPresets = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) { setState(() => _loadingPresets = false); return; }
      final presets = await ApiService(url).getPresets(token);
      if (mounted) {
        setState(() {
          _presets = presets.map((e) => e as Map<String, dynamic>).toList();
          _loadingPresets = false;
        });
      }
      if (_presets.isEmpty) await _loadRecentCategories();
    } catch (_) {
      if (mounted) setState(() => _loadingPresets = false);
      if (_presets.isEmpty) await _loadRecentCategories();
    }
  }

  Future<void> _showExpenseFromPreset(Map<String, dynamic> preset) async {
    setState(() => _fabOpen = false);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => ExpenseFormSheet(refresh: _refresh, onSaved: _notifyRefresh, preset: preset),
    );
  }

  Future<void> _showQuickAdd(Map<String, dynamic> cat) async {
    setState(() => _fabOpen = false);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => _QuickAddSheet(cat: cat),
    );
    if (saved == true) {
      _notifyRefresh();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Gasto guardado')));
    }
  }

  /// Bandeja horizontal scrollable de chips del FAB (plantillas o, si no hay,
  /// últimas categorías). Alineada a la derecha (cerca del FAB) y con ancho
  /// acotado al de la pantalla para que el scroll horizontal nunca quede sin
  /// restricciones.
  Widget _buildFabTray(List<Widget> chips) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showFab = _currentIndex == 0 || _currentIndex == 1;
    // select (no watch): solo reconstruye el shell (PageView/NavigationBar)
    // cuando hasEverLoadedData cambia de verdad, no en cada mutación de la
    // cola de pendientes (eso lo maneja _buildPendingBanner por su cuenta).
    // Ojo: el gate SOLO debe aplicar mientras además estemos sin conexión —
    // si solo mirara hasEverLoadedData, un usuario nuevo con internet nunca
    // podría entrar a Gastos/Reportes/Perfil por primera vez, porque esa
    // primera carga exitosa (la que pone hasEverLoadedData en true) ocurre
    // justo en esas pantallas, bloqueadas por el propio gate.
    final neverLoaded = context.select<OfflineQueueService, bool>((s) => !s.hasEverLoadedData);
    final gatedTabs = neverLoaded && !_serverConnected;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Budget Tracker'),
            if (kDebugMode && _serverChecked) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openServerConfig,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _serverConnected ? colorScheme.income : colorScheme.expense,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _serverConnected ? 'Conectado' : 'Sin conexión',
                      style: TextStyle(
                        color: _serverConnected ? Colors.white : colorScheme.errorContainer,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: _serverConnected ? Colors.white : colorScheme.errorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_currentIndex == 4)
            IconButton(
              icon: const Icon(LucideIcons.log_out),
              tooltip: 'Cerrar sesión',
              onPressed: () => context.read<AuthService>().signOut(),
            ),
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageCtrl,
            physics: (_nestedRouteActive || gatedTabs) ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentIndex = i),
            children: [
              DashboardTab(refresh: _refresh, onAddExpense: _showExpenseForm, onOpenShared: _openSharedTab),
              ExpensesScreen(refresh: _refresh),
              ReportsScreen(refresh: _refresh),
              SharedScreen(refresh: _refresh),
              ProfileScreen(refresh: _refresh),
            ],
          ),
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _fabOpen = false),
                child: Container(color: Colors.black26),
              ),
            ),
        ],
      ),
      floatingActionButton: showFab
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_fabOpen) ...[
                  if ((_loadingPresets || _loadingCategories) && _presets.isEmpty && _recentCategories.isEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                      ],
                    )
                  else if (_presets.isNotEmpty) ...[
                    _buildFabTray([
                      for (final p in _presets)
                        _FabChip(
                          icon: p['icon']?.toString(),
                          label: p['name'] as String? ?? '',
                          color: colorScheme.primary,
                          onTap: () => _showExpenseFromPreset(p),
                        ),
                    ]),
                    const SizedBox(height: 12),
                  ] else if (_recentCategories.isNotEmpty) ...[
                    _buildFabTray([
                      for (final c in _recentCategories)
                        _FabChip(
                          icon: c['icon']?.toString(),
                          label: c['name'] as String? ?? '',
                          color: adaptCategoryColor(parseHexColor(c['color']?.toString()), context),
                          onTap: () => _showQuickAdd(c),
                        ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  _MiniFab(icon: LucideIcons.camera, label: 'Foto', color: colorScheme.primary, onTap: () => _showComingSoon('Foto de recibo')),
                  const SizedBox(height: 12),
                  _MiniFab(icon: LucideIcons.mic, label: 'Audio', color: colorScheme.secondary, onTap: () => _showComingSoon('Nota de voz')),
                  const SizedBox(height: 12),
                  _MiniFab(icon: LucideIcons.pen_line, label: 'Formulario', color: colorScheme.tertiary, onTap: _showExpenseForm),
                  const SizedBox(height: 16),
                ],
                FloatingActionButton(
                  onPressed: () {
                    setState(() => _fabOpen = !_fabOpen);
                    if (_fabOpen) _loadFabItems();
                  },
                  child: Icon(_fabOpen ? LucideIcons.x : LucideIcons.plus),
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (gatedTabs && (i == 1 || i == 2 || i == 3 || i == 4)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Necesitas conexión la primera vez para cargar tus datos')),
            );
            return;
          }
          setState(() { _currentIndex = i; _fabOpen = false; });
          _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        },
        destinations: [
          const NavigationDestination(icon: Icon(LucideIcons.house), selectedIcon: Icon(LucideIcons.house, size: 28), label: 'Inicio'),
          _gatedDestination(icon: LucideIcons.receipt_text, label: 'Gastos', gated: gatedTabs),
          _gatedDestination(icon: LucideIcons.chart_bar, label: 'Reportes', gated: gatedTabs),
          _gatedDestination(icon: LucideIcons.users_round, label: 'Compartidos', gated: gatedTabs),
          _profileDestination(gatedTabs),
        ],
      ),
    );
  }

  NavigationDestination _gatedDestination({required IconData icon, required String label, required bool gated}) {
    final color = gated ? Theme.of(context).disabledColor : null;
    return NavigationDestination(
      icon: Icon(icon, color: color),
      selectedIcon: Icon(icon, size: 28, color: color),
      label: label,
    );
  }

  NavigationDestination _profileDestination(bool gated) {
    final profile = context.watch<ProfileController>();
    final avatar = profile.avatar;
    final color = gated ? Theme.of(context).disabledColor : null;
    if (avatar.isEmpty) {
      return NavigationDestination(
        icon: Icon(LucideIcons.circle_user_round, color: color),
        selectedIcon: Icon(LucideIcons.circle_user_round, size: 28, color: color),
        label: 'Perfil',
      );
    }
    return NavigationDestination(
      icon: Text(avatar, style: TextStyle(fontSize: 24, color: color)),
      selectedIcon: Text(avatar, style: TextStyle(fontSize: 28, color: color)),
      label: 'Perfil',
    );
  }
}

/// Chip rectangular del menú del FAB: emoji + nombre, área táctil cómoda.
/// Reemplaza a los mini-FAB circulares (solo emoji, sin contexto ni scroll).
class _FabChip extends StatelessWidget {
  final String? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FabChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(BudgetTheme.borderRadiusMedium),
        color: theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(BudgetTheme.borderRadiusMedium),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                categoryIconWidget(icon, size: 22, color: color),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(label, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniFab({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          onPressed: onTap,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ],
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

enum _PeriodFilter { days7, days15, thisMonth, lastMonth, custom }
enum _ChartView { bars, pie }

class DashboardTab extends StatefulWidget {
  final ValueNotifier<int> refresh;
  final VoidCallback onAddExpense;
  final VoidCallback onOpenShared;

  const DashboardTab({super.key, required this.refresh, required this.onAddExpense, required this.onOpenShared});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _prevStats;
  List<dynamic>? _expenses;
  List<dynamic> _cards = [];
  Map<String, dynamic> _sharedSummary = {};
  bool _loading = true;
  String? _error;
  // Último fallo fue de red (#99): sin conexión no se puede completar un
  // pendiente, así que el banner lista los pendientes en vez de ofrecer «Completar».
  bool _offline = false;
  _PeriodFilter _selectedFilter = _PeriodFilter.days7;
  _ChartView _chartView = _ChartView.bars;
  int _breakdownView = 0;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_onRefresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    setState(() => _loading = true);
    _loadData();
  }

  ({DateTime start, DateTime end}) _getRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case _PeriodFilter.days7:
        return (start: now.subtract(const Duration(days: 6)), end: now);
      case _PeriodFilter.days15:
        return (start: now.subtract(const Duration(days: 14)), end: now);
      case _PeriodFilter.thisMonth:
        return (start: DateTime(now.year, now.month, 1), end: now);
      case _PeriodFilter.lastMonth:
        return (start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0));
      case _PeriodFilter.custom:
        return (start: _customStart ?? now.subtract(const Duration(days: 6)), end: _customEnd ?? now);
    }
  }

  ({DateTime start, DateTime end}) _getPrevRange() {
    final range = _getRange();
    final days = range.end.difference(range.start).inDays + 1;
    return (start: range.start.subtract(Duration(days: days)), end: range.start.subtract(const Duration(days: 1)));
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _formatCurrency(double amount) => '\$ ${NumberFormat.decimalPattern('es_CO').format(amount)}';

  Future<void> _loadData() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final config = context.read<ServerConfig>();
    try {
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) {
        if (mounted) setState(() { _loading = false; _offline = false; _error = 'No autenticado'; });
        return;
      }
      final api = ApiService(url);
      final range = _getRange();
      final prev = _getPrevRange();
      final results = await Future.wait([
        api.getStats(token, startDate: _fmt(range.start), endDate: _fmt(range.end)),
        api.getStats(token, startDate: _fmt(prev.start), endDate: _fmt(prev.end)),
        api.getExpenses(token, startDate: _fmt(range.start), endDate: _fmt(range.end)),
        api.getCards(token),
        api.getSharedSummary(token),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _prevStats = results[1] as Map<String, dynamic>;
          _expenses = sortExpensesDesc(results[2] as List).take(5).toList();
          _cards = results[3] as List<dynamic>;
          _sharedSummary = results[4] as Map<String, dynamic>;
          _loading = false;
          _offline = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _offline = isConnectivityError(e);
          _error = isConnectivityError(e)
              ? 'No hay conexión para cargar el resumen'
              : e.toString();
        });
      }
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
      locale: const Locale('es'),
      helpText: 'Seleccionar rango',
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = _PeriodFilter.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
        _loading = true;
      });
      _loadData();
    }
  }

  String _filterLabel() {
    switch (_selectedFilter) {
      case _PeriodFilter.days7: return 'Últimos 7 días';
      case _PeriodFilter.days15: return 'Últimos 15 días';
      case _PeriodFilter.thisMonth: return 'Este mes';
      case _PeriodFilter.lastMonth: return 'Mes anterior';
      case _PeriodFilter.custom: return 'Personalizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final total = (_stats?['total'] as num?)?.toDouble() ?? 0;
    final isEmpty = total == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPendingBanner(theme, colorScheme),
          _buildFilters(colorScheme),
          const SizedBox(height: 16),
          if (_stats != null) _buildSummary(theme, colorScheme),
          const SizedBox(height: 16),
          _buildSharedCard(theme, colorScheme),
          const SizedBox(height: 24),
          if (_error == null && isEmpty)
            _buildEmptyState(theme, colorScheme)
          else if (_error == null) ...[
            if (_stats != null) _buildCategories(theme, colorScheme),
            const SizedBox(height: 24),
            if (_expenses != null && _expenses!.isNotEmpty) _buildLatestExpenses(theme, colorScheme),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.expense.withAlpha(20),
              child: ListTile(
                leading: Icon(LucideIcons.circle_alert, color: colorScheme.expense),
                title: Text(_error!, style: TextStyle(color: colorScheme.expense, fontSize: 13)),
                trailing: IconButton(
                  icon: Icon(LucideIcons.rotate_cw, color: colorScheme.expense),
                  onPressed: () { setState(() { _loading = true; _error = null; }); _loadData(); },
                ),
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(ThemeData theme, ColorScheme colorScheme) {
    final pending = context.watch<OfflineQueueService>().pending;
    final pendingCount = pending.length;
    if (pendingCount == 0) return const SizedBox.shrink();
    final title = pendingCount == 1
        ? 'Tienes 1 gasto pendiente de completar'
        : 'Tienes $pendingCount gastos pendientes de completar';
    if (_offline) return _buildOfflinePendingList(theme, colorScheme, pending, title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: colorScheme.primary.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(BudgetTheme.cardPadding),
          child: Row(
            children: [
              Icon(LucideIcons.clock, color: colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: BudgetTheme.compactFilledButton,
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
                  ),
                  builder: (_) => PendingExpensesSheet(refresh: widget.refresh, onSaved: () {}),
                ),
                child: const Text('Completar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sin conexión completar no es posible (categorías/medios de pago vienen del
  /// servidor): se muestran los pendientes como lista de solo lectura (#99).
  Widget _buildOfflinePendingList(ThemeData theme, ColorScheme colorScheme, List<Map<String, dynamic>> pending, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: colorScheme.primary.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(BudgetTheme.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.wifi_off, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.bodyMedium),
                        Text(
                          pending.length == 1
                              ? 'Podrás completarlo cuando vuelva la conexión'
                              : 'Podrás completarlos cuando vuelva la conexión',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final p in pending) PendingExpenseTile(pending: p, trailing: PendingDiscardButton(pending: p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(ColorScheme colorScheme) {
    final items = [
      (_PeriodFilter.days7, '7 días'),
      (_PeriodFilter.days15, '15 días'),
      (_PeriodFilter.thisMonth, 'Este mes'),
      (_PeriodFilter.lastMonth, 'Mes anterior'),
    ];
    return FilterChipsBar(
      options: [
        for (final item in items) (value: item.$1.name, label: item.$2),
      ],
      selected: _selectedFilter.name,
      onChanged: (v) {
        final filter = _PeriodFilter.values.firstWhere((e) => e.name == v);
        setState(() { _selectedFilter = filter; _loading = true; });
        _loadData();
      },
      trailing: ActionChip(
        avatar: Icon(LucideIcons.calendar, size: 16, color: _selectedFilter == _PeriodFilter.custom ? colorScheme.primary : null),
        label: Text(
          _selectedFilter == _PeriodFilter.custom && _customStart != null
              ? '${DateFormat('dd/MM').format(_customStart!)}-${DateFormat('dd/MM').format(_customEnd!)}'
              : 'Personalizado',
          style: const TextStyle(fontSize: 12),
        ),
        onPressed: _pickCustomRange,
        backgroundColor: _selectedFilter == _PeriodFilter.custom ? colorScheme.primary.withAlpha(40) : null,
      ),
    );
  }

  Widget _buildSharedCard(ThemeData theme, ColorScheme colorScheme) {
    final owed = (_sharedSummary['total_pending'] as num?)?.toDouble() ?? 0;
    final count = _sharedSummary['people'] is List ? (_sharedSummary['people'] as List).length : 0;
    if (owed <= 0 && count == 0) return const SizedBox.shrink();
    return Card(
      color: colorScheme.primary.withAlpha(20),
      child: InkWell(
        onTap: widget.onOpenShared,
        borderRadius: BorderRadius.circular(BudgetTheme.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(BudgetTheme.cardPadding),
          child: Row(
            children: [
              Icon(LucideIcons.users_round, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Te deben', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.textSecondary)),
                    Text(_formatCurrency(owed), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (count > 0)
                      Text('$count ${count == 1 ? 'persona' : 'personas'}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.textSecondary)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevron_right, color: colorScheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme, ColorScheme colorScheme) {
    final total = (_stats?['total'] as num?)?.toDouble() ?? 0;
    final prevTotal = (_prevStats?['total'] as num?)?.toDouble() ?? 0;
    final range = _getRange();
    final label = '${DateFormat('dd MMM', 'es').format(range.start)} - ${DateFormat('dd MMM yyyy', 'es').format(range.end)}';
    final diff = total - prevTotal;
    final pctChange = prevTotal > 0 ? (diff / prevTotal * 100).round() : 0;
    final isUp = diff > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BudgetTheme.cardPadding),
        child: Column(
          children: [
            Text(_filterLabel(), style: theme.textTheme.bodyMedium),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(_formatCurrency(total), style: theme.textTheme.headlineLarge),
            if (prevTotal > 0 || total > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isUp ? LucideIcons.trending_up : LucideIcons.trending_down, size: 16,
                      color: isUp ? colorScheme.expense : colorScheme.income),
                  const SizedBox(width: 4),
                  Text('${isUp ? '+' : ''}$pctChange%',
                      style: TextStyle(color: isUp ? colorScheme.expense : colorScheme.income, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Text('vs período anterior', style: theme.textTheme.bodySmall),
                ],
              ),
              Text(_formatCurrency(prevTotal), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.wallet, size: 56, color: colorScheme.primary.withAlpha(100)),
            const SizedBox(height: 16),
            Text('No tienes gastos registrados', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('para estas fechas', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(ThemeData theme, ColorScheme colorScheme) {
    final total = (_stats!['total'] as num?)?.toDouble() ?? 1;
    final dataList = _breakdownView == 0
        ? (_stats!['by_category'] as List<dynamic>? ?? [])
        : (_stats!['by_payment'] as List<dynamic>? ?? []);
    final sorted = sortBreakdownByTotalDesc(dataList);
    final top = sorted.where((c) => ((c['total'] as num?)?.toDouble() ?? 0) > 0).take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_cards.isNotEmpty)
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Por Categoría')),
                  ButtonSegment(value: 1, label: Text('Por Método')),
                ],
                selected: {_breakdownView},
                onSelectionChanged: (v) => setState(() => _breakdownView = v.first),
                style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(36, 28))),
              )
            else
              Text('Categorías', style: theme.textTheme.titleMedium),
            const Spacer(),
            SegmentedButton<_ChartView>(
              segments: const [
                ButtonSegment(value: _ChartView.bars, icon: Icon(LucideIcons.chart_bar, size: 16)),
                ButtonSegment(value: _ChartView.pie, icon: Icon(LucideIcons.chart_pie, size: 16)),
              ],
              selected: {_chartView},
              onSelectionChanged: (v) => setState(() => _chartView = v.first),
              style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(40, 32))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_chartView == _ChartView.bars)
          ...top.map((c) {
            final itemTotal = (c['total'] as num?)?.toDouble() ?? 0;
            final itemName = _itemName(c);
            final itemColor = adaptCategoryColor(parseHexColor(c['color']?.toString() ?? ''), context);
            final pct = total > 0 ? (itemTotal / total * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _itemIcon(c, itemColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(itemName, style: theme.textTheme.labelLarge)),
                    Text(_formatCurrency(itemTotal), style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Text('$pct%', style: theme.textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: itemTotal / total, minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: itemColor.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation(itemColor),
                  ),
                ],
              ),
            );
          })
        else
          Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(PieChartData(
                  sections: top.map((c) {
                    final itemTotal = (c['total'] as num?)?.toDouble() ?? 0;
                    final itemColor = adaptCategoryColor(parseHexColor(c['color']?.toString() ?? ''), context);
                    final pct = total > 0 ? (itemTotal / total * 100).round() : 0;
                    return PieChartSectionData(
                      value: itemTotal, title: '$pct%', color: itemColor, radius: 60,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2, centerSpaceRadius: 40,
                )),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 8, alignment: WrapAlignment.center,
                children: top.map((c) {
                  final itemName = _itemName(c);
                  final itemColor = adaptCategoryColor(parseHexColor(c['color']?.toString() ?? ''), context);
                  final itemTotal = (c['total'] as num?)?.toDouble() ?? 0;
                  final pct = total > 0 ? (itemTotal / total * 100).round() : 0;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: itemColor)),
                    const SizedBox(width: 4),
                    Text('$itemName ($pct%)', style: theme.textTheme.bodySmall),
                  ]);
                }).toList(),
              ),
            ],
          ),
      ],
    );
  }

  String _itemName(dynamic item) {
    return (item['category_name'] ?? item['name'])?.toString() ?? '';
  }

  Widget _itemIcon(dynamic item, Color color) {
    if (item['icon'] != null) {
      return categoryIconWidget(item['icon']?.toString(), size: 18, color: color);
    }
    if ((item['franchise'] as String? ?? '') != '') {
      return franchiseIconWidget(item['franchise'].toString(), size: 18, color: color);
    }
    return Icon(LucideIcons.banknote, size: 18, color: color);
  }

  Widget _buildLatestExpenses(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Últimos gastos', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...groupConsecutiveExpenses(_expenses!).map((block) {
          final isGrouped = block.length > 1;
          if (!isGrouped) {
            return _buildLatestTicketTile(block[0], isMain: true, isGrouped: false);
          }
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.teal.shade400, width: 4)),
              color: Colors.teal.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < block.length; i++)
                  _buildLatestTicketTile(block[i], isMain: i == 0, isGrouped: true),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLatestTicketTile(dynamic e, {required bool isMain, required bool isGrouped}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final desc = e['description'] as String? ?? '';
    final date = e['expense_date'] as String? ?? '';
    final cat = e['category'] as Map<String, dynamic>?;
    final catName = cat?['name'] as String? ?? '';
    final catColor = adaptCategoryColor(parseHexColor(cat?['color']?.toString() ?? ''), context);
    final parsedDate = DateTime.tryParse(date.split('T').first);
    final formattedDate = parsedDate != null ? DateFormat('dd MMM', 'es').format(parsedDate) : '';
    return ListTile(
      visualDensity: isGrouped ? const VisualDensity(vertical: -2) : null,
      contentPadding: EdgeInsets.only(left: isGrouped ? 12 : 0, right: 0),
      leading: CircleAvatar(radius: 18, backgroundColor: catColor.withAlpha(30), child: categoryIconWidget(cat?['icon']?.toString(), size: 18, color: catColor)),
      title: Text(isMain ? desc : catName, style: theme.textTheme.labelLarge),
      subtitle: isMain ? Text('$catName · $formattedDate', style: theme.textTheme.bodySmall) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isMain && e['card'] is Map && (e['card'] as Map)['franchise'] != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: franchiseIconWidget(
              (e['card'] as Map)['franchise'].toString(),
              size: 16,
              color: parseHexColor((e['card'] as Map)['color']?.toString()),
            ),
          ),
        Text(_formatCurrency(amount), style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.expense)),
      ]),
    );
  }
}
