import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/connectivity_error.dart';
import '../utils/currency_formatter.dart';
import '../utils/default_amount.dart';
import '../utils/icon_helper.dart';
import '../utils/shared_split.dart';
import '../utils/split_expenses.dart';
import 'category_form_sheet.dart';
import 'shared_split_section.dart';

class ExpenseFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  /// Si se está completando un gasto capturado sin conexión (ver
  /// OfflineQueueService/PendingExpensesSheet): trae {local_id, amount,
  /// expense_date, description}. El form pre-llena esos campos pero sigue
  /// siendo un create normal (categoría/tarjeta/split reales, porque para
  /// llegar acá ya hay conexión) y al guardar saca el ítem de la cola.
  final Map<String, dynamic>? pendingToComplete;
  /// Si se abrió desde una plantilla (FAB): trae {name, icon, amount,
  /// category_id, card_id, description}. El form pre-llena todo (monto,
  /// categoría, método de pago y descripción) con la fecha de hoy, y sigue
  /// siendo un create normal: el usuario solo confirma o ajusta el medio de
  /// pago.
  final Map<String, dynamic>? preset;
  final ValueNotifier<int> refresh;
  final VoidCallback onSaved;
  /// Solo para tests: reemplaza la carga real de categorías. flutter_test
  /// intercepta todo el tráfico HTTP y siempre responde 400 (nunca lanza una
  /// excepción real de conectividad), así que no hay forma de simular "sin
  /// conexión" a través de la red real en un widget test — este seam permite
  /// inyectar un loader que sí lance SocketException/etc.
  @visibleForTesting
  final Future<List<dynamic>> Function(String url, String token)? categoriesLoader;
  const ExpenseFormSheet({
    super.key,
    this.existing,
    this.pendingToComplete,
    this.preset,
    required this.refresh,
    required this.onSaved,
    this.categoriesLoader,
  });

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _SubExpense {
  Map<String, dynamic> category;
  final TextEditingController amountCtrl;
  _SubExpense({required this.category, String amount = ''})
      : amountCtrl = TextEditingController(text: amount);

  double get amount => double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  void dispose() => amountCtrl.dispose();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  List<dynamic> _categories = [];
  List<dynamic> _cards = [];
  List<dynamic> _people = [];
  String? _selectedCategoryId;
  String? _selectedCardId;
  bool _sharedEnabled = false;
  List<Map<String, dynamic>> _shares = [];
  int _categoryFilter = 0;
  late DateTime _date;
  final _paymentScrollCtrl = ScrollController();
  final _categoryScrollCtrl = ScrollController();
  bool _loading = true;
  bool _saving = false;
  bool _showSplitPicker = false;
  bool _splitOverWarned = false;
  bool _offlineMode = false;
  String? _error;
  final List<_SubExpense> _subExpenses = [];

  bool get _isEdit => widget.existing != null;
  bool get _isCompletingPending => widget.pendingToComplete != null;
  bool get _isFromPreset => widget.preset != null;

  double get _currentTotal => double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  double get _subTotal => subExpensesTotal(_subExpenses.map((s) => s.amount));
  double get _principalAmount => principalAmount(_currentTotal, _subTotal);
  bool get _splitInvalid => _subExpenses.isNotEmpty && _subTotal > _currentTotal;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final pending = widget.pendingToComplete;
    final preset = widget.preset;
    final prefillAmount = preset != null
        ? (preset['amount'] as num?)?.toDouble()
        : (pending != null
            ? (pending['amount'] as num?)?.toDouble()
            : (e != null ? (e['amount'] as num?)?.toDouble() : null));
    _amountCtrl = TextEditingController(
      text: prefillAmount != null ? NumberFormat.decimalPattern('es_CO').format(prefillAmount.toInt()) : '',
    );
    _descCtrl = TextEditingController(text: (preset?['description'] ?? pending?['description'] ?? e?['description'] ?? '') as String);
    if (preset != null) {
      final catId = preset['category_id']?.toString();
      _selectedCategoryId = (catId != null && catId.isNotEmpty) ? catId : null;
      final cardId = preset['card_id']?.toString();
      _selectedCardId = (cardId != null && cardId.isNotEmpty) ? cardId : null;
    } else {
      _selectedCategoryId = (e?['category'] as Map<String, dynamic>?)?['id']?.toString();
      _selectedCardId = (e?['card'] as Map<String, dynamic>?)?['id']?.toString() ?? e?['card_id']?.toString();
    }
    final dateSource = (pending?['expense_date'] as String?) ?? (e?['expense_date'] as String?) ?? '';
    _date = DateTime.tryParse(dateSource.split('T').first) ?? DateTime.now();
    final existingShares = (e?['shares'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    _sharedEnabled = existingShares.isNotEmpty;
    _shares = existingShares;
    _loadCategories();
    _loadCards();
    _loadPeople();
  }

  @override
  void dispose() {
    for (final s in _subExpenses) {
      s.dispose();
    }
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _paymentScrollCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final cats = widget.categoriesLoader != null
          ? await widget.categoriesLoader!(url, token)
          : await ApiService(url).getCategories(token);
      if (mounted) {
        setState(() {
          _categories = cats;
          if (_selectedCategoryId == null && cats.isNotEmpty) {
            _selectedCategoryId = cats.first['id'] as String?;
          }
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isEdit && !_isFromPreset && mounted && _selectedCategoryId != null) {
            _applyDefaultAmount(_selectedCategoryId);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (!_isCompletingPending && isConnectivityError(e)) {
        // Sin conexión y no estamos completando un pendiente: no hay forma
        // confiable de mostrar categorías reales, así que se pasa a modo
        // captura mínima (monto + fecha + descripción) en vez de un error.
        setState(() { _loading = false; _offlineMode = true; });
        return;
      }
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadCards() async {
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final cards = await ApiService(url).getCards(token);
      if (mounted) {
        setState(() {
          _cards = cards;
          if (cards.isEmpty && _selectedCardId != null) _selectedCardId = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPeople() async {
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final people = await ApiService(url).getPeople(token);
      if (mounted) {
        setState(() => _people = people);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(raw.isEmpty ? '0' : raw);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    if (_offlineMode) {
      setState(() { _saving = true; _error = null; });
      // Cerrar el sheet ANTES de mutar OfflineQueueService: si el pop de
      // Navigator y el notifyListeners() que inserta el banner de
      // pendientes en el Dashboard caen en el mismo frame, Flutter puede
      // lanzar 'RenderBox was not laid out' (re-entrancia de layout) y el
      // banner queda invisible para el resto de la sesión.
      final offlineQueue = context.read<OfflineQueueService>();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Guardado sin conexión — complétalo cuando tengas internet')),
      );
      await offlineQueue.addPending(
            amount: amount,
            expenseDate: DateFormat('yyyy-MM-dd').format(_date),
            description: _descCtrl.text.trim(),
          );
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Selecciona una categoría');
      return;
    }
    if (_sharedEnabled && _subExpenses.isNotEmpty) {
      setState(() => _error = 'No podés compartir un gasto dividido por categorías');
      return;
    }
    if (_sharedEnabled) {
      final amounts = _shares.map((s) => (s['amount'] as num?)?.toDouble() ?? 0.0).toList();
      final err = validateSplit(amount, amounts);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    if (!_isEdit && _subExpenses.isNotEmpty) {
      if (_subTotal > amount) {
        setState(() => _error = 'Los desgloses superan el monto total');
        return;
      }
      final seen = <String?>{};
      for (final s in _subExpenses) {
        final id = s.category['id'] as String?;
        if (id == null || id == _selectedCategoryId || seen.contains(id)) {
          setState(() => _error = 'El desglose tiene categorías repetidas o inválidas');
          return;
        }
        seen.add(id);
        if (s.amount <= 0) {
          setState(() => _error = 'Cada desglose debe tener un monto válido');
          return;
        }
      }
      await _submitSplit(amount);
      return;
    }
    if (!_isEdit) {
      final sel = _categories.cast<Map<String, dynamic>?>().firstWhere(
        (c) => c?['id'] == _selectedCategoryId,
        orElse: () => null,
      );
      final originalDefault = (sel?['default_amount'] as num?)?.toDouble() ?? 0;
      if (shouldOfferDefaultUpdate(currentDefault: originalDefault, amount: amount)) {
        final shouldUpdate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Actualizar valor por defecto?'),
            content: Text(
              '¿Deseas actualizar el valor por defecto de ${sel?['name']} a ${formatAmountInput(amount)} para futuros gastos?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Solo esta vez'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Actualizar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        await _submitExpense(amount, updateDefault: shouldUpdate == true, category: sel);
        return;
      }
    }
    await _submitExpense(amount);
  }

  Future<void> _submitExpense(double amount, {bool updateDefault = false, Map<String, dynamic>? category}) async {
    setState(() { _saving = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) throw Exception('No autenticado');
      final body = {
        'amount': amount,
        'description': _descCtrl.text.trim().isEmpty ? 'Gasto' : _descCtrl.text.trim(),
        'category_id': _selectedCategoryId,
        'card_id': _selectedCardId,
        'expense_date': DateFormat('yyyy-MM-dd').format(_date),
        'source': 'form',
        'shares': _sharedEnabled ? _shares : <Map<String, dynamic>>[],
      };
      if (_isEdit) {
        await ApiService(url).updateExpense(token, widget.existing!['id'] as String, body);
      } else {
        await ApiService(url).createExpense(token, body);
      }
      if (updateDefault && category != null) {
        _updateCategoryDefault(token, url, category, amount);
      }
      if (!mounted) return;
      if (_isCompletingPending) {
        await context.read<OfflineQueueService>().removePending(widget.pendingToComplete!['local_id'] as String);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onSaved();
      widget.refresh.value++;
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Gasto actualizado' : 'Gasto guardado')),
      );
    } catch (e) {
      if (!mounted) return;
      if (!_isEdit && !_isCompletingPending && isConnectivityError(e)) {
        await _queueOffline(amount);
        return;
      }
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  /// Encola como pendiente mínimo (monto/fecha/descripción) cuando un submit
  /// que ya tenía categoría/tarjeta seleccionadas falla por conectividad
  /// (ej. se perdió la señal entre abrir el form y guardar). Se descarta la
  /// categoría/tarjeta ya elegidas para mantener una sola forma de pendiente
  /// en toda la app — se vuelven a elegir al completar.
  Future<void> _queueOffline(double amount) async {
    // Mismo orden que en _save(): cerrar el sheet antes de mutar
    // OfflineQueueService para no pisar el layout del banner de pendientes.
    final offlineQueue = context.read<OfflineQueueService>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Guardado sin conexión — complétalo cuando tengas internet')),
    );
    await offlineQueue.addPending(
          amount: amount,
          expenseDate: DateFormat('yyyy-MM-dd').format(_date),
          description: _descCtrl.text.trim(),
        );
  }

  Future<void> _submitSplit(double total) async {
    setState(() { _saving = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) throw Exception('No autenticado');
      final groupId = const Uuid().v4();
      final bodies = buildSplitExpenseBodies(
        principal: _principalAmount,
        principalCategoryId: _selectedCategoryId,
        subs: _subExpenses.map((s) => (categoryId: s.category['id'] as String, amount: s.amount)).toList(),
        description: _descCtrl.text.trim().isEmpty ? 'Gasto' : _descCtrl.text.trim(),
        cardId: _selectedCardId,
        date: DateFormat('yyyy-MM-dd').format(_date),
        source: 'form',
        transactionGroupId: groupId,
      );
      if (bodies.isEmpty) {
        setState(() { _saving = false; _error = 'Ingresa montos válidos'; });
        return;
      }
      final api = ApiService(url);
      await Future.wait(bodies.map((b) => api.createExpense(token, b)));
      if (!mounted) return;
      if (_isCompletingPending) {
        await context.read<OfflineQueueService>().removePending(widget.pendingToComplete!['local_id'] as String);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onSaved();
      widget.refresh.value++;
      messenger.showSnackBar(
        const SnackBar(content: Text('Gasto(s) guardado(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      if (!_isCompletingPending && isConnectivityError(e)) {
        await _queueOffline(total);
        return;
      }
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  void _onSplitChanged() {
    setState(() {});
    if (_splitInvalid && !_splitOverWarned) {
      _splitOverWarned = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El desglose supera el monto total')),
      );
    } else if (!_splitInvalid) {
      _splitOverWarned = false;
    }
  }

  void _addSubExpense(Map<String, dynamic> cat) {
    final def = (cat['default_amount'] as num?)?.toDouble() ?? 0;
    if (def > 0 && _subTotal + def > _currentTotal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El desglose supera el monto total')),
      );
      return;
    }
    setState(() {
      _subExpenses.add(_SubExpense(category: cat, amount: def > 0 ? formatAmountInput(def) : ''));
    });
  }

  void _removeSubExpense(int index) {
    final removed = _subExpenses.removeAt(index);
    removed.dispose();
    _splitOverWarned = false;
    setState(() {});
  }

  Widget _buildSubRow(int index, ThemeData theme) {
    final sub = _subExpenses[index];
    final catColor = parseHexColor(sub.category['color']?.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          categoryIconWidget(sub.category['icon']?.toString(), size: 18, color: catColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(sub.category['name']?.toString() ?? '', style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: sub.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
              inputFormatters: [ThousandsFormatter()],
              onChanged: (_) => _onSplitChanged(),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 18),
            onPressed: () => _removeSubExpense(index),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCategoryDefault(String token, String url, Map<String, dynamic> category, double amount) async {
    try {
      await ApiService(url).updateCategory(token, category['id'] as String, {
        'name': category['name'],
        'icon': category['icon'],
        'color': category['color'],
        'type': category['type'],
        'requires_description': category['requires_description'],
        'default_amount': amount,
      });
    } catch (_) {}
  }

  void _applyDefaultAmount(String? catId) {
    if (catId == null) return;
    final cat = _categories.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['id'] == catId,
      orElse: () => null,
    );
    final def = (cat?['default_amount'] as num?)?.toDouble() ?? 0;
    if (def > 0) {
      _amountCtrl.text = formatAmountInput(def);
    }
  }

  Future<void> _createCategory() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BudgetTheme.borderRadiusLarge)),
      ),
      builder: (_) => CategoryFormSheet(refresh: widget.refresh, showCloseButton: false),
    );
    await _loadCategories();
    if (created != null && created['id'] != null && mounted) {
      setState(() => _selectedCategoryId = created['id'] as String?);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_offlineMode) return _buildOfflineForm(theme);
    final sel = _categories.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['id'] == _selectedCategoryId,
      orElse: () => null,
    );
    final requiresDesc = sel?['requires_description'] ?? true;

    return Padding(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(_isEdit ? 'Editar gasto' : 'Nuevo gasto', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: theme.textTheme.headlineMedium,
                decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
                inputFormatters: [ThousandsFormatter()],
                autofocus: true,
                onChanged: (_) => _onSplitChanged(),
              ),
              if (!_isEdit && _subExpenses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ..._subExpenses.map((s) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${s.category['name']}: ${formatAmountInput(s.amount)}', style: const TextStyle(fontSize: 11)),
                    )),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(30),
                      label: Text('Restante: ${formatAmountInput(_principalAmount)}', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
              if (_cards.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 70,
                  child: ListView(
                    controller: _paymentScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    children: [
                      _paymentChip(
                        label: 'Efectivo',
                        icon: Icon(LucideIcons.banknote, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        selected: _selectedCardId == null,
                        onTap: () {
                          setState(() => _selectedCardId = null);
                          _paymentScrollCtrl.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        },
                      ),
                      ..._cards.map((c) {
                        final cardId = c['id'] as String?;
                        return _paymentChip(
                          label: c['name'] as String? ?? '',
                          icon: franchiseIconWidget(c['franchise']?.toString() ?? 'other', size: 20, color: parseHexColor(c['color']?.toString())),
                          selected: _selectedCardId == cardId,
                          onTap: () {
                            setState(() => _selectedCardId = cardId);
                            _paymentScrollCtrl.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Categoría', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Variables')),
                      ButtonSegment(value: 1, label: Text('Fijas')),
                    ],
                    selected: {_categoryFilter},
                    onSelectionChanged: (v) => setState(() => _categoryFilter = v.first),
                    style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(36, 28))),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: _createCategory, icon: const Icon(LucideIcons.plus), tooltip: 'Nueva categoría'),
                ],
              ),
              SizedBox(
                height: 60,
                child: ListView(
                  controller: _categoryScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  children: _sortedCategories().map((c) {
                    final catId = c['id'] as String?;
                    final selected = _selectedCategoryId == catId;
                    final catColor = parseHexColor(c['color']?.toString());
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategoryId = catId);
                        _applyDefaultAmount(catId);
                        _categoryScrollCtrl.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: selected ? catColor.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? catColor : Theme.of(context).colorScheme.outlineVariant, width: selected ? 2 : 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            categoryIconWidget(c['icon']?.toString(), size: 24, color: catColor),
                            const SizedBox(height: 4),
                            Text(c['name'] as String? ?? '', overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (!_isEdit && !_sharedEnabled) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showSplitPicker = !_showSplitPicker),
                    icon: const Icon(LucideIcons.split, size: 16),
                    label: Text(_showSplitPicker ? 'Ocultar desglose' : '+ Añadir sub-gasto'),
                  ),
                ),
                if (_showSplitPicker) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: smartSortedSubCategories(_categories, excludeId: _selectedCategoryId).map((c) {
                        final def = (c['default_amount'] as num?)?.toDouble() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: categoryIconWidget(c['icon']?.toString(), size: 16, color: parseHexColor(c['color']?.toString())),
                            label: Text(
                              def > 0 ? '${c['name']} \$${formatAmountInput(def)}' : c['name']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _addSubExpense(c),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                if (_subExpenses.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...List.generate(_subExpenses.length, (i) => _buildSubRow(i, theme)),
                ],
              ],
              const SizedBox(height: 8),
              SharedSplitSection(
                totalAmount: _currentTotal,
                people: _people,
                initiallyEnabled: _sharedEnabled,
                initialShares: _shares,
                onSharesChanged: (shares) {
                  setState(() {
                    _shares = shares;
                    _sharedEnabled = shares.isNotEmpty;
                  });
                },
                onCreatePerson: _loadPeople,
              ),
              if (requiresDesc) ...[
                const SizedBox(height: 16),
                TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción (Opcional)')),
              ],
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendar),
                title: Text(DateFormat('dd MMM yyyy', 'es').format(_date)),
                trailing: const Icon(LucideIcons.chevron_right, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('es'),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.expense, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_saving || _splitInvalid) ? null : _save,
                child: _saving
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : Text(_isEdit ? 'Guardar cambios' : 'Guardar gasto'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<dynamic> _sortedCategories() {
    final filtered = _categories.where((c) => (c['type'] ?? 0) == _categoryFilter).toList();
    if (_selectedCategoryId == null) return filtered;
    final idx = filtered.indexWhere((c) => c['id'] == _selectedCategoryId);
    if (idx <= 0) return filtered;
    final selected = filtered.removeAt(idx);
    filtered.insert(0, selected);
    return filtered;
  }

  Widget _paymentChip({required String label, required Widget icon, required bool selected, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withAlpha(30) : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colorScheme.primary : colorScheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineForm(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Nuevo gasto (sin conexión)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'No hay conexión para cargar categorías. Guarda el monto ahora y completa la categoría y el medio de pago cuando vuelvas a tener internet.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium,
              decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
              inputFormatters: [ThousandsFormatter()],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.calendar),
              title: Text(DateFormat('dd MMM yyyy', 'es').format(_date)),
              trailing: const Icon(LucideIcons.chevron_right, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('es'),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción (Opcional)')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.expense, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                  : const Text('Guardar sin conexión'),
            ),
          ],
        ),
      ),
    );
  }

}
