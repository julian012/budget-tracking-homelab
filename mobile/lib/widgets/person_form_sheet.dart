import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';

const _presetEmojis = ['👤', '🧑', '👩', '👨', '🧒', '🐶', '🏠', '🚗', '✈️', '🏷️'];
const _personColors = ['#EF4444', '#F59E0B', '#8B5CF6', '#EC4899', '#10B981', '#3B82F6', '#06B6D4', '#84CC16', '#F97316', '#6B7280'];

class PersonFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final ValueNotifier<int> refresh;
  final bool showCloseButton;
  const PersonFormSheet({super.key, this.existing, required this.refresh, this.showCloseButton = true});

  @override
  State<PersonFormSheet> createState() => _PersonFormSheetState();
}

class _PersonFormSheetState extends State<PersonFormSheet> {
  late final TextEditingController _nameCtrl;
  late String _selectedEmoji;
  late String _selectedColor;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?['name']?.toString() ?? '');
    final currentIcon = widget.existing?['icon']?.toString() ?? '';
    _selectedEmoji = _presetEmojis.contains(currentIcon) ? currentIcon : _presetEmojis.first;
    _selectedColor = widget.existing?['color']?.toString() ?? _personColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final body = {
        'name': name,
        'icon': _selectedEmoji,
        'color': _selectedColor,
      };
      if (_isEdit) {
        await ApiService(url).updatePerson(token, widget.existing!['id'] as String, body);
        if (mounted) {
          Navigator.pop(context, true);
          widget.refresh.value++;
        }
      } else {
        final created = await ApiService(url).createPerson(token, body);
        if (mounted) {
          Navigator.pop(context, created);
          widget.refresh.value++;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Text(_isEdit ? 'Editar persona' : 'Nueva persona', style: theme.textTheme.titleLarge),
          const Spacer(),
          if (widget.showCloseButton) IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context, false)),
        ]),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
        const SizedBox(height: 16),
        const Text('Emoji', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetEmojis.map((e) {
            final selected = _selectedEmoji == e;
            return GestureDetector(
              onTap: () => setState(() => _selectedEmoji = e),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.primary.withAlpha(40) : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: selected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                ),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _personColors.map((c) {
            final selected = _selectedColor == c;
            final color = Color(int.parse(c.replaceFirst('#', 'FF'), radix: 16));
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = c),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving || _nameCtrl.text.trim().isEmpty ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEdit ? 'Guardar' : 'Crear'),
          ),
        ),
      ]),
    );
  }
}
