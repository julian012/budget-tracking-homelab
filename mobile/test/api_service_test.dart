import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/services/api_service.dart';

void main() {
  group('HealthResult', () {
    test('ok true with statusCode', () {
      const result = HealthResult(ok: true, statusCode: 200);
      expect(result.ok, true);
      expect(result.statusCode, 200);
      expect(result.error, null);
    });

    test('ok false with error', () {
      const result = HealthResult(ok: false, error: 'Connection refused');
      expect(result.ok, false);
      expect(result.statusCode, null);
      expect(result.error, 'Connection refused');
    });
  });

  group('ApiService', () {
    test('constructs with baseUrl', () {
      final api = ApiService('http://localhost:4000');
      expect(api.baseUrl, 'http://localhost:4000');
    });

    test('healthCheck returns error on invalid URL', () async {
      final api = ApiService('http://invalid');
      final result = await api.healthCheck();
      expect(result.ok, false);
      expect(result.error, isNotNull);
    });
  });
}
