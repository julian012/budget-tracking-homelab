import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/default_amount.dart';
import '../utils/icon_helper.dart';

const _presetEmojis = ['🍔', '🚌', '⚡', '🎬', '🏠', '🛒', '💖', '📱', '✈️', '🏷️'];
const _categoryColors = ['#EF4444', '#F59E0B', '#8B5CF6', '#EC4899', '#10B981', '#3B82F6', '#06B6D4', '#84CC16', '#F97316', '#1A1C1E'];

class CategoryFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final ValueNotifier<int> refresh;
  final bool showCloseButton;
  final int? defaultType;
  const CategoryFormSheet({super.key, this.existing, required this.refresh, this.showCloseButton = true, this.defaultType});

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _defaultAmountCtrl;
  late String _selectedEmoji;
  late String _selectedColor;
  String? _selectedType;
  bool _showCustomEmoji = false;
  late bool _requiresDescription;

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
    _defaultAmountCtrl = TextEditingController(text: formatAmountInput((_existing?['default_amount'] as num?)?.toDouble() ?? 0));
    _selectedColor = _existing?['color'] ?? '#6B7280';
    _selectedType = _existing != null ? ((_existing!['type'] == 1) ? 'fixed' : 'variable')
        : (widget.defaultType == 1 ? 'fixed' : (widget.defaultType == 0 ? 'variable' : null));
    _requiresDescription = _existing?['requires_description'] ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _defaultAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
        'color': _selectedColor,
        'type': _selectedType == 'fixed' ? 1 : 0,
        'requires_description': _requiresDescription,
        'default_amount': parseDefaultAmount(_defaultAmountCtrl.text) ?? 0,
      };
      if (_isEdit) {
        await ApiService(url).updateCategory(token, _existing!['id'] as String, body);
        if (mounted) {
          Navigator.pop(context, true);
          widget.refresh.value++;
        }
      } else {
        final created = await ApiService(url).createCategory(token, body);
        if (mounted) {
          Navigator.pop(context, created);
          widget.refresh.value++;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: BudgetTheme.spacing24,
        right: BudgetTheme.spacing24,
        top: BudgetTheme.spacing24,
        bottom: MediaQuery.of(context).viewInsets.bottom + BudgetTheme.spacing24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [Text(_isEdit ? 'Editar categoría' : 'Nueva categoría', style: theme.textTheme.titleLarge), const Spacer(), if (widget.showCloseButton) IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context, false))]),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
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
                  color: selected ? theme.colorScheme.primary.withAlpha(40) : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: selected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
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
                color: _showCustomEmoji ? theme.colorScheme.primary.withAlpha(40) : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: _showCustomEmoji ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
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
            onChanged: (v) { if (v.isNotEmpty) _selectedEmoji = v; },
          ),
        ],
        const SizedBox(height: 16),
        const Text('Tipo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'variable', label: Text('Variable')), ButtonSegment(value: 'fixed', label: Text('Fijo'))],
          selected: _selectedType != null ? {_selectedType!} : {},
          onSelectionChanged: (v) => setState(() => _selectedType = v.first),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _requiresDescription,
          onChanged: (v) => setState(() => _requiresDescription = v ?? true),
          title: const Text('Incluir descripción en gastos', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _defaultAmountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor por defecto (Opcional)',
            hintText: 'Ej. 8500',
            prefixIcon: Icon(LucideIcons.coins, size: 18),
          ),
          inputFormatters: [ThousandsFormatter()],
        ),
        const SizedBox(height: 16),
        const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _categoryColors.map((c) {
          final selected = _selectedColor == c;
          final color = Color(int.parse(c.replaceFirst('#', 'FF'), radix: 16));
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = c),
            child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selected ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null)),
          );
        }).toList()),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedType == null || _nameCtrl.text.trim().isEmpty ? null : _save,
            child: Text(_isEdit ? 'Guardar' : 'Crear'),
          ),
        ),
      ]),
    );
  }
}
