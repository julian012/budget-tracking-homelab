import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Cola local de gastos capturados sin conexión (solo monto/fecha/descripción
/// — lo único que el cliente puede saber sin red). Se completan (categoría,
/// medio de pago, split) cuando vuelve la conexión, vía ExpenseFormSheet en
/// modo `pendingToComplete`. Nada se sincroniza automáticamente: siempre
/// requiere que el usuario abra "Completar" desde el banner de Inicio.
class OfflineQueueService extends ChangeNotifier {
  static const _keyPending = 'offline_pending_expenses';
  static const _keyHasLoadedData = 'offline_has_loaded_data';

  List<Map<String, dynamic>> _pending = [];
  bool _hasEverLoadedData = false;
  bool _initialized = false;

  List<Map<String, dynamic>> get pending => List.unmodifiable(_pending);
  bool get hasEverLoadedData => _hasEverLoadedData;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPending);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _pending = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    _hasEverLoadedData = prefs.getBool(_keyHasLoadedData) ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _persistPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPending, jsonEncode(_pending));
  }

  Future<void> addPending({
    required double amount,
    required String expenseDate,
    String? description,
  }) async {
    _pending = [
      ..._pending,
      {
        'local_id': const Uuid().v4(),
        'amount': amount,
        'expense_date': expenseDate,
        'description': description ?? '',
      },
    ];
    await _persistPending();
    notifyListeners();
  }

  Future<void> removePending(String localId) async {
    _pending = _pending.where((p) => p['local_id'] != localId).toList();
    await _persistPending();
    notifyListeners();
  }

  /// Marca que la app logró cargar datos del servidor al menos una vez.
  /// Se usa para habilitar las tabs de Gastos/Reportes (ver home_screen.dart).
  Future<void> markDataLoaded() async {
    if (_hasEverLoadedData) return;
    _hasEverLoadedData = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasLoadedData, true);
    notifyListeners();
  }
}
