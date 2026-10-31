import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme/budget_theme.dart';

const _presetAvatars = ['👤', '🧑', '👩', '👨', '😎', '🤓', '🦁', '🐼', '🦊', '🐸'];

class ProfileEditSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final ValueNotifier<int> refresh;
  const ProfileEditSheet({super.key, required this.profile, required this.refresh});

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final TextEditingController _nameCtrl;
  late String _selectedAvatar;
  bool _showCustomAvatar = false;
  final _customAvatarCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final avatar = widget.profile['avatar']?.toString() ?? '';
    _selectedAvatar = avatar.isNotEmpty ? avatar : _presetAvatars.first;
    _nameCtrl = TextEditingController(text: widget.profile['display_name']?.toString() ?? '');
    _showCustomAvatar = avatar.isNotEmpty && !_presetAvatars.contains(avatar);
    if (_showCustomAvatar) _customAvatarCtrl.text = avatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customAvatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final config = context.read<ServerConfig>();
      final token = await auth.getToken();
      final url = config.serverUrl;
      if (token == null) return;
      final avatar = _showCustomAvatar && _customAvatarCtrl.text.isNotEmpty ? _customAvatarCtrl.text : _selectedAvatar;
      await ApiService(url).updateProfile(token, {
        'display_name': _nameCtrl.text.trim(),
        'avatar': avatar,
      });
      if (mounted) {
        Navigator.pop(context, true);
        widget.refresh.value++;
      }
    } catch (_) {
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
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [Text('Editar perfil', style: theme.textTheme.titleLarge), const Spacer(), IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context, false))]),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
        const SizedBox(height: 16),
        const Text('Avatar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ..._presetAvatars.map((e) {
            final selected = !_showCustomAvatar && _selectedAvatar == e;
            return GestureDetector(
              onTap: () => setState(() { _selectedAvatar = e; _showCustomAvatar = false; }),
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
            onTap: () => setState(() => _showCustomAvatar = true),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _showCustomAvatar ? theme.colorScheme.primary.withAlpha(40) : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: _showCustomAvatar ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
              ),
              child: const Icon(LucideIcons.plus, size: 20),
            ),
          ),
        ]),
        if (_showCustomAvatar) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customAvatarCtrl,
            maxLength: 1,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Emoji personalizado', hintText: 'Ingresa un emoji', counterText: ''),
            onChanged: (v) { if (v.isNotEmpty) _selectedAvatar = v; },
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                : const Text('Guardar'),
          ),
        ),
      ]),
    );
  }
}
