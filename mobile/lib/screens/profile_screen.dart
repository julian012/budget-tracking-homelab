import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/profile_controller.dart';
import '../services/server_config.dart';
import '../services/theme_controller.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/icon_helper.dart';
import '../widgets/category_card.dart';
import '../widgets/category_form_sheet.dart';
import '../widgets/card_form_sheet.dart';
import '../widgets/preset_form_sheet.dart';
import '../widgets/profile_edit_sheet.dart';
import '../widgets/wallet_card.dart';

class ProfileScreen extends StatefulWidget {
  final ValueNotifier<int> refresh;
  const ProfileScreen({super.key, required this.refresh});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  Map<String, dynamic>? _profile;
  List<dynamic> _cards = [];
  List<dynamic> _categories = [];
  List<dynamic> _presets = [];
  bool _loading = true;

  String get _email => context.read<AuthService>().currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_loadAll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_loadAll);
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final profileController = context.read<ProfileController>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final api = ApiService(url);
      final results = await Future.wait([
        api.getProfile(token),
        api.getCards(token),
        api.getCategories(token),
        api.getPresets(token),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final cards = results[1] as List<dynamic>;
      final cats = results[2] as List<dynamic>;
      final presets = results[3] as List<dynamic>;
      profileController.update(profile);
      if (mounted) {
        setState(() { _profile = profile; _cards = cards; _categories = cats; _presets = presets; _loading = false; });
        context.read<OfflineQueueService>().markDataLoaded();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo cargar el perfil'),
            action: SnackBarAction(label: 'Reintentar', onPressed: _loadAll),
          ),
        );
      }
    }
  }

  String get _displayName {
    final dn = _profile?['display_name']?.toString() ?? '';
    if (dn.isNotEmpty) return dn;
    final name = _profile?['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return _email;
  }

  Widget _buildAvatar() {
    final colorScheme = Theme.of(context).colorScheme;
    final avatar = _profile?['avatar']?.toString() ?? '';
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '👤';

    return CircleAvatar(
      radius: 40,
      backgroundColor: colorScheme.primary.withAlpha(30),
      child: avatar.isNotEmpty
          ? Text(avatar, style: const TextStyle(fontSize: 40))
          : Text(initial, style: TextStyle(fontSize: 36, color: colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => ProfileEditSheet(profile: _profile!, refresh: widget.refresh),
    );
    await _loadAll();
  }

  // ── Cards ──────────────────────────────────────────────

  Future<void> _openCardForm({Map<String, dynamic>? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => CardFormSheet(existing: existing, refresh: widget.refresh),
    );
    await _loadAll();
  }

  Future<void> _showCardActions(Map<String, dynamic> card) async {
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(LucideIcons.pencil),
            title: const Text('Modificar'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: Icon(LucideIcons.trash_2, color: colorScheme.expense),
            title: Text('Eliminar', style: TextStyle(color: colorScheme.expense)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == 'edit') {
      await _openCardForm(existing: card);
    } else if (action == 'delete') {
      await _confirmDeleteCard(card);
    }
  }

  Future<void> _confirmDeleteCard(Map<String, dynamic> card) async {
    final auth = context.read<AuthService>();
    final config = context.read<ServerConfig>();
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('¿Seguro que deseas eliminar "${card['name']}"?', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: colorScheme.expense), onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR'))),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final token = await auth.getToken();
        final url = config.serverUrl;
        if (token == null) return;
        await ApiService(url).deleteCard(token, card['id'] as String);
        await _loadAll();
        widget.refresh.value++;
      } catch (_) {}
    }
  }

  // ── Categories ─────────────────────────────────────────

  Future<void> _openCategoryForm({int? defaultType, Map<String, dynamic>? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => CategoryFormSheet(existing: existing, refresh: widget.refresh, defaultType: defaultType),
    );
    await _loadAll();
  }

  Future<void> _showCategoryActions(Map<String, dynamic> cat) async {
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(leading: const Icon(LucideIcons.pencil), title: const Text('Modificar'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(leading: Icon(LucideIcons.trash_2, color: colorScheme.expense), title: Text('Eliminar', style: TextStyle(color: colorScheme.expense)), onTap: () => Navigator.pop(ctx, 'delete')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == 'edit') {
      await _openCategoryForm(existing: cat);
    } else if (action == 'delete') {
      await _confirmDeleteCategory(cat);
    }
  }

  Future<void> _confirmDeleteCategory(Map<String, dynamic> cat) async {
    final auth = context.read<AuthService>();
    final config = context.read<ServerConfig>();
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('¿Seguro que deseas eliminar "${cat['name']}"?', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: colorScheme.expense), onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR'))),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final token = await auth.getToken();
        final url = config.serverUrl;
        if (token == null) return;
        await ApiService(url).deleteCategory(token, cat['id'] as String);
        await _loadAll();
        widget.refresh.value++;
      } catch (_) {}
    }
  }

  // ── Presets ────────────────────────────────────────────

  Future<void> _openPresetForm({Map<String, dynamic>? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => PresetFormSheet(
        existing: existing,
        categories: _categories,
        cards: _cards,
        refresh: widget.refresh,
      ),
    );
    await _loadAll();
  }

  Future<void> _showPresetActions(Map<String, dynamic> preset) async {
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(leading: const Icon(LucideIcons.pencil), title: const Text('Modificar'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(leading: Icon(LucideIcons.trash_2, color: colorScheme.expense), title: Text('Eliminar', style: TextStyle(color: colorScheme.expense)), onTap: () => Navigator.pop(ctx, 'delete')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == 'edit') {
      await _openPresetForm(existing: preset);
    } else if (action == 'delete') {
      await _confirmDeletePreset(preset);
    }
  }

  Future<void> _confirmDeletePreset(Map<String, dynamic> preset) async {
    final auth = context.read<AuthService>();
    final config = context.read<ServerConfig>();
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('¿Seguro que deseas eliminar "${preset['name']}"?', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: colorScheme.expense), onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR'))),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final token = await auth.getToken();
        final url = config.serverUrl;
        if (token == null) return;
        await ApiService(url).deletePreset(token, preset['id'] as String);
        await _loadAll();
        widget.refresh.value++;
      } catch (_) {}
    }
  }

  Widget _buildPresetCarousel(List<dynamic> presets) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        itemBuilder: (_, i) {
          final p = presets[i] as Map<String, dynamic>;
          final amount = (p['amount'] as num?)?.toDouble() ?? 0;
          return GestureDetector(
            onTap: () => _showPresetActions(p),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  categoryIconWidget(p['icon']?.toString(), size: 24, color: colorScheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    p['name']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    '\$ ${NumberFormat.decimalPattern('es_CO').format(amount.toInt())}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCarousel(List<dynamic> cats) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i] as Map<String, dynamic>;
          final color = adaptCategoryColor(parseHexColor(c['color']?.toString()), context);
          final name = c['name']?.toString() ?? '';
          return GestureDetector(
            onTap: () => _showCategoryActions(c),
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  categoryIconWidget(c['icon']?.toString(), size: 24, color: color),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final variables = _categories.where((c) => (c['type'] ?? 0) == 0).toList();
    final fijos = _categories.where((c) => (c['type'] ?? 0) == 1).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BudgetTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _loading ? const CircularProgressIndicator() : _buildAvatar(),
          const SizedBox(height: 12),
          Text(_displayName, style: theme.textTheme.titleMedium),
          if (_email.isNotEmpty) Text(_email, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _editProfile, icon: const Icon(LucideIcons.pencil, size: 16), label: const Text('Editar Perfil')),
          const SizedBox(height: 24),

          // ── Apariencia ──
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BudgetTheme.spacing16),
              child: Row(
                children: [
                  Icon(LucideIcons.moon, size: BudgetTheme.actionIconSize, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Modo oscuro', style: theme.textTheme.titleMedium),
                  ),
                  Switch(
                    value: context.select<ThemeController, bool>((t) => t.isDark),
                    onChanged: (value) => context.read<ThemeController>().setDark(value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Plantillas Rápidas ──
          Row(
            children: [
              Text('Plantillas Rápidas', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(icon: const Icon(LucideIcons.plus), onPressed: () => _openPresetForm(), tooltip: 'Nueva plantilla'),
            ],
          ),
          const SizedBox(height: 4),
          _presets.isEmpty
              ? const EmptySection(icon: LucideIcons.bolt, message: 'Sin plantillas')
              : _buildPresetCarousel(_presets),
          const SizedBox(height: 24),

          // ── Carrusel de tarjetas ──
          Row(
            children: [
              Text('Métodos de Pago', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(icon: const Icon(LucideIcons.plus), onPressed: _openCardForm, tooltip: 'Nueva tarjeta'),
            ],
          ),
          const SizedBox(height: 4),
          _cards.isEmpty
              ? const EmptySection(icon: LucideIcons.credit_card, message: 'Sin tarjetas')
              : SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = _cards[i] as Map<String, dynamic>;
                      return SizedBox(
                        width: 220,
                        child: WalletCard(card: c, onTap: () => _showCardActions(c)),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 24),

          // ── Gastos Variables ──
          Row(
            children: [
              Text('Gastos Variables', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(icon: const Icon(LucideIcons.plus), onPressed: () => _openCategoryForm(defaultType: 0), tooltip: 'Nueva categoría variable'),
            ],
          ),
          const SizedBox(height: 4),
          variables.isEmpty
              ? const EmptySection(icon: LucideIcons.folder, message: 'Sin categorías')
              : _buildCategoryCarousel(variables),
          const SizedBox(height: 24),

          // ── Gastos Fijos ──
          Row(
            children: [
              Text('Gastos Fijos', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(icon: const Icon(LucideIcons.plus), onPressed: () => _openCategoryForm(defaultType: 1), tooltip: 'Nueva categoría fija'),
            ],
          ),
          const SizedBox(height: 4),
          fijos.isEmpty
              ? const EmptySection(icon: LucideIcons.folder, message: 'Sin categorías')
              : _buildCategoryCarousel(fijos),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
