import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig extends ChangeNotifier {
  static const _keyServerUrl = 'server_url';
  static const _keyShowIndicator = 'show_indicator';
  // Configurable en build: flutter run --dart-define=API_BASE_URL=https://api.example.com
  static const _defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  static String get defaultUrl => _defaultUrl;

  String _serverUrl = defaultUrl;
  bool _showIndicator = true;
  bool _initialized = false;

  String get serverUrl => _serverUrl;
  bool get showIndicator => _showIndicator;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_keyServerUrl) ?? defaultUrl;
    _showIndicator = prefs.getBool(_keyShowIndicator) ?? true;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
    notifyListeners();
  }

  Future<void> setShowIndicator(bool show) async {
    _showIndicator = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowIndicator, show);
    notifyListeners();
  }
}
