import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracking/services/server_config.dart';

void main() {
  group('ServerConfig', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to http://localhost:4000 and showIndicator true', () async {
      final config = ServerConfig();
      await config.init();

      expect(config.serverUrl, 'http://localhost:4000');
      expect(config.showIndicator, true);
    });

    test('setServerUrl updates value and notifies', () async {
      final config = ServerConfig();
      await config.init();

      bool notified = false;
      config.addListener(() => notified = true);

      await config.setServerUrl('http://192.168.1.50:4000');

      expect(config.serverUrl, 'http://192.168.1.50:4000');
      expect(notified, true);
    });

    test('setShowIndicator updates value and notifies', () async {
      final config = ServerConfig();
      await config.init();

      bool notified = false;
      config.addListener(() => notified = true);

      await config.setShowIndicator(false);

      expect(config.showIndicator, false);
      expect(notified, true);
    });

    test('persists values across instances', () async {
      final config1 = ServerConfig();
      await config1.init();
      await config1.setServerUrl('http://example.com:4000');
      await config1.setShowIndicator(false);

      final config2 = ServerConfig();
      await config2.init();

      expect(config2.serverUrl, 'http://example.com:4000');
      expect(config2.showIndicator, false);
    });
  });
}
