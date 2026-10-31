import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/color_utils.dart';
import '../utils/currency_formatter.dart';
import '../utils/default_amount.dart';
import '../utils/icon_helper.dart';

const _presetEmojis = ['🚌', '🍔', '⚡', '🎬', '🏠', '🛒', '💊', '📱', '✈️', '🏷️'];

class PresetFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> categories;
  final List<dynamic> cards;
  final ValueNotifier<int> refresh;
  final bool showCloseButton;
  const PresetFormSheet({
    super.key,
    this.existing,
    required this.categories,
    required this.cards,
    required this.refresh,
    this.showCloseButton = true,
  });

  @override
  State<PresetFormSheet> createState() => _PresetFormSheetState();
}

class _PresetFormSheetState extends State<PresetFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedEmoji;
  bool _showCustomEmoji = false;
  String? _selectedCategoryId;
  String? _selectedCardId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  Map<String, dynamic>? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _existing?['name'] ?? '');
    final currentIcon = _existing?['icon']?.toString() ?? '';
    final isEmoji = isEmojiIcon(currentIcon);
    _selectedEmoji = isEmoji ? currentIcon : _presetEmojis.first;
    _emojiCtrl = TextEditingController(text: isEmoji && !_presetEmojis.contains(currentIcon) ? currentIcon : '');
    _showCustomEmoji = isEmoji && !_presetEmojis.contains(currentIcon);
    _amountCtrl = TextEditingController(text: formatAmountInput((_existing?['amount'] as num?)?.toDouble() ?? 0));
    _descCtrl = TextEditingController(text: _existing?['description']?.toString() ?? '');
    final catId = _existing?['category_id']?.toString();
    _selectedCategoryId = (catId != null && catId.isNotEmpty)
        ? catId
        : (widget.categories.isNotEmpty ? widget.categories.first['id']?.toString() : null);
    final cardId = _existing?['card_id']?.toString();
    _selectedCardId = (cardId != null && cardId.isNotEmpty) ? cardId : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseDefaultAmount(_amountCtrl.text) ?? 0;
    if (_nameCtrl.text.trim().isEmpty || amount <= 0 || _selectedCategoryId == null) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final icon = _showCustomEmoji && _emojiCtrl.text.isNotEmpty ? _emojiCtrl.text : _selectedEmoji;
      final body = {
        'name': _nameCtrl.text.trim(),
        'icon': icon,
        'amount': amount,
        'category_id': _selectedCategoryId,
        'card_id': _selectedCardId,
        'description': _descCtrl.text.trim(),
      };
      final api = ApiService(url);
      if (_isEdit) {
        await api.updatePreset(token, _existing!['id'] as String, body);
      } else {
        await api.createPreset(token, body);
      }
      if (mounted) {
        Navigator.pop(context, true);
        widget.refresh.value++;
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canSave =>
      !_saving && _nameCtrl.text.trim().isNotEmpty && (parseDefaultAmount(_amountCtrl.text) ?? 0) > 0 && _selectedCategoryId != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Text(_isEdit ? 'Editar plantilla' : 'Nueva plantilla', style: theme.textTheme.titleLarge),
          const Spacer(),
          if (widget.showCloseButton) IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context, false)),
        ]),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Flota Tunja-Bogotá'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Text('Emoji', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ..._presetEmojis.map((e) {
            final selected = !_showCustomEmoji && _selectedEmoji == e;
            return GestureDetector(
              onTap: () => setState(() { _selectedEmoji = e; _showCustomEmoji = false; }),
              child: Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary.withAlpha(40) : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: selected ? Border.all(color: colorScheme.primary, width: 2) : null,
                ),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            );
          }),
          GestureDetector(
            onTap: () => setState(() => _showCustomEmoji = true),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _showCustomEmoji ? colorScheme.primary.withAlpha(40) : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: _showCustomEmoji ? Border.all(color: colorScheme.primary, width: 2) : null,
              ),
              child: const Icon(LucideIcons.plus, size: 20),
            ),
          ),
        ]),
        if (_showCustomEmoji) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _emojiCtrl,
            maxLength: 1,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Emoji personalizado', hintText: 'Ingresa un emoji', counterText: ''),
            onChanged: (v) { if (v.isNotEmpty) setState(() => _selectedEmoji = v); },
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto',
            hintText: 'Ej. 25000',
            prefixIcon: Icon(LucideIcons.coins, size: 18),
          ),
          inputFormatters: [ThousandsFormatter()],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Categoría', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (widget.categories.isEmpty)
          Text('Crea una categoría primero', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant))
        else
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.categories.map((c) {
                final catId = c['id']?.toString();
                final selected = _selectedCategoryId == catId;
                final catColor = parseHexColor(c['color']?.toString());
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = catId),
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected ? catColor.withValues(alpha: 0.15) : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? catColor : colorScheme.outlineVariant, width: selected ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        categoryIconWidget(c['icon']?.toString(), size: 24, color: catColor),
                        const SizedBox(height: 4),
                        Text(c['name']?.toString() ?? '', overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),
        Text('Método de pago (Opcional)', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _paymentChip(
                label: 'Efectivo',
                icon: Icon(LucideIcons.banknote, size: 20, color: colorScheme.onSurfaceVariant),
                selected: _selectedCardId == null,
                onTap: () => setState(() => _selectedCardId = null),
              ),
              ...widget.cards.map((c) {
                final cardId = c['id']?.toString();
                return _paymentChip(
                  label: c['name']?.toString() ?? '',
                  icon: franchiseIconWidget(c['franchise']?.toString() ?? 'other', size: 20, color: parseHexColor(c['color']?.toString())),
                  selected: _selectedCardId == cardId,
                  onTap: () => setState(() => _selectedCardId = cardId),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descripción (Opcional)', hintText: 'Ej. pasajes ida y vuelta'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary))
                : Text(_isEdit ? 'Guardar' : 'Crear'),
          ),
        ),
      ]),
    );
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
}
